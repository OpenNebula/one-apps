package main

import (
	"fmt"
	"io"
	"os"
	"os/signal"
	"sync"

	oneleaseconfig "github.com/OpenNebula/one-apps/appliances/VRouterd/DHCP4v2/dhcpcore-onelease/pkg/config"

	"github.com/coredhcp/coredhcp/logger"
	"github.com/coredhcp/coredhcp/server"

	dhcpcoreconfig "github.com/coredhcp/coredhcp/config"

	pl_onelease "github.com/OpenNebula/one-apps/appliances/VRouterd/DHCP4v2/dhcpcore-onelease/plugins/onelease"

	"github.com/coredhcp/coredhcp/plugins"
	pl_autoconfigure "github.com/coredhcp/coredhcp/plugins/autoconfigure"
	pl_dns "github.com/coredhcp/coredhcp/plugins/dns"
	pl_file "github.com/coredhcp/coredhcp/plugins/file"
	pl_ipv6only "github.com/coredhcp/coredhcp/plugins/ipv6only"
	pl_leasetime "github.com/coredhcp/coredhcp/plugins/leasetime"
	pl_mtu "github.com/coredhcp/coredhcp/plugins/mtu"
	pl_nbp "github.com/coredhcp/coredhcp/plugins/nbp"
	pl_netmask "github.com/coredhcp/coredhcp/plugins/netmask"
	pl_prefix "github.com/coredhcp/coredhcp/plugins/prefix"
	pl_router "github.com/coredhcp/coredhcp/plugins/router"
	pl_searchdomains "github.com/coredhcp/coredhcp/plugins/searchdomains"
	pl_serverid "github.com/coredhcp/coredhcp/plugins/serverid"
	pl_sleep "github.com/coredhcp/coredhcp/plugins/sleep"
	pl_staticroute "github.com/coredhcp/coredhcp/plugins/staticroute"

	"github.com/sirupsen/logrus"
	flag "github.com/spf13/pflag"
)

var (
	flagLogFile     = flag.StringP("logfile", "l", "", "Name of the log file to append to. Default: stdout/stderr only")
	flagLogNoStdout = flag.BoolP("nostdout", "N", false, "Disable logging to stdout/stderr")
	flagLogLevel    = flag.StringP("loglevel", "L", "info", fmt.Sprintf("Log level. One of %v", getLogLevels()))
	flagConfig      = flag.StringP("conf", "c", "", "Use this configuration file instead of the default location")
	flagPlugins     = flag.BoolP("plugins", "P", false, "list plugins")
)

var logLevels = map[string]func(*logrus.Logger){
	"none":    func(l *logrus.Logger) { l.SetOutput(io.Discard) },
	"debug":   func(l *logrus.Logger) { l.SetLevel(logrus.DebugLevel) },
	"info":    func(l *logrus.Logger) { l.SetLevel(logrus.InfoLevel) },
	"warning": func(l *logrus.Logger) { l.SetLevel(logrus.WarnLevel) },
	"error":   func(l *logrus.Logger) { l.SetLevel(logrus.ErrorLevel) },
	"fatal":   func(l *logrus.Logger) { l.SetLevel(logrus.FatalLevel) },
}

func getLogLevels() []string {
	var levels []string
	for k := range logLevels {
		levels = append(levels, k)
	}
	return levels
}

var desiredPlugins = []*plugins.Plugin{
	&pl_autoconfigure.Plugin,
	&pl_dns.Plugin,
	&pl_file.Plugin,
	&pl_ipv6only.Plugin,
	&pl_leasetime.Plugin,
	&pl_mtu.Plugin,
	&pl_nbp.Plugin,
	&pl_netmask.Plugin,
	&pl_onelease.Plugin,
	&pl_prefix.Plugin,
	//&pl_range.Plugin,
	&pl_router.Plugin,
	&pl_searchdomains.Plugin,
	&pl_serverid.Plugin,
	&pl_sleep.Plugin,
	&pl_staticroute.Plugin,
}

var log = logger.GetLogger("main")

func main() {
	flag.Parse()

	if *flagPlugins {
		for _, p := range desiredPlugins {
			fmt.Println(p.Name)
		}
		os.Exit(0)
	}

	fn, ok := logLevels[*flagLogLevel]
	if !ok {
		log.Fatalf("Invalid log level '%s'. Valid log levels are %v", *flagLogLevel, getLogLevels())
	}
	fn(log.Logger)
	log.Infof("Setting log level to '%s'", *flagLogLevel)
	if *flagLogFile != "" {
		log.Infof("Logging to file %s", *flagLogFile)
		logger.WithFile(log, *flagLogFile)
	}
	if *flagLogNoStdout {
		log.Infof("Disabling logging to stdout/stderr")
		logger.WithNoStdOutErr(log)
	}
	// register plugins
	for _, plugin := range desiredPlugins {
		if err := plugins.RegisterPlugin(plugin); err != nil {
			log.Fatalf("Failed to register plugin '%s': %v", plugin.Name, err)
		}
	}

	// create a configuration file per interface
	tempDir, configFilesMap, err := createInterfaceConfigFiles(*flagConfig)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}
	defer cleanup(tempDir)

	// channel to listen for termination signals
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt)

	// channel to collect errors
	errChan := make(chan error, len(configFilesMap))

	// references to each interface listener server, for closing them later
	serverMap := make(map[string]*server.Servers)

	// start a server per interface declared in the config
	var wg sync.WaitGroup
	for iface, configFile := range configFilesMap {
		wg.Add(1)
		go func(iface string, configFile string) {
			defer wg.Done()
			cfg, err := dhcpcoreconfig.Load(configFile)
			if err != nil {
				errChan <- fmt.Errorf("failed to load configuration for interface %s: %v", iface, err)
				return
			}
			log.Infof("Starting listener for interface %s...", iface)
			//no problem with concurrency because each goroutine access its own index
			serverMap[iface], err = server.Start(cfg)
			if err != nil {
				errChan <- fmt.Errorf("failed to start listener for interface %s: %v", iface, err)
				return
			}
			if err := serverMap[iface].Wait(); err != nil {
				errChan <- fmt.Errorf("listener for interface %s failed: %v", iface, err)
				return
			}
		}(iface, configFile)
	}

	select {
	case <-stop:
		log.Info("Received SIGINT, shutting down...")
	case err = <-errChan:
		log.Errorf("Received error: %v, shutting down all listeners...", err)
	}

	for iface, srv := range serverMap {
		log.Infof("Shutting down listener for interface %s...", iface)
		if srv != nil {
			srv.Close()
		}
	}

	wg.Wait()
	close(errChan)
	close(stop)

	log.Infof("All listeners shut down, exiting")
	if err != nil {
		os.Exit(1)
	}
}

func createInterfaceConfigFiles(path string) (string, map[string]string, error) {
	log.Infof("Loading configuration from %s", path)

	ifaceConfigs, err := oneleaseconfig.LoadConfig(path)
	if err != nil {
		return "", nil, err
	}

	return oneleaseconfig.CreateTempConfigFiles(ifaceConfigs)
}

func cleanup(tempDir string) {
	oneleaseconfig.CleanupTempConfigFiles(tempDir)
}
