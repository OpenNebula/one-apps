package config

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/coredhcp/coredhcp/logger"
	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

var log = logger.GetLogger("oneconfig")

type ServerConfig struct {
	Plugins []map[string]string `yaml:"plugins"`
	Listen  []string            `yaml:"listen"`
}

type InterfaceConfig struct {
	Server4 ServerConfig `yaml:"server4"`
	//TODO Server6 for Ipv6 dhcp service not supported yet
}

func LoadConfig(path string) (map[string]InterfaceConfig, error) {
	viper.SetConfigType("yaml")
	if path != "" {
		viper.SetConfigFile(path)
	} else {
		viper.SetConfigName("onelease-config")
		viper.AddConfigPath(".")
		viper.AddConfigPath("$XDG_CONFIG_HOME/coredhcp/")
		viper.AddConfigPath("$HOME/.coredhcp/")
		viper.AddConfigPath("/etc/coredhcp/")
	}

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("error reading config file, %s", err)
	}

	var config map[string]InterfaceConfig
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("unable to decode into struct, %v", err)
	}

	return config, nil
}

// create a temporary dir and write there the per-interfafce configuration files
// return the temporary directory path and a map with all the config files paths
func CreateTempConfigFiles(config map[string]InterfaceConfig) (string, map[string]string, error) {
	tempDir := filepath.Join(os.TempDir(), "one-coredhcp-config")
	if err := os.MkdirAll(tempDir, 0755); err != nil {
		return "", nil, fmt.Errorf("unable to create temporary directory, %v", err)
	}

	configFiles := make(map[string]string)
	for interfaceName, interfaceConfig := range config {
		filePath, err := writePerInterfaceConfig(tempDir, interfaceName, interfaceConfig)
		if err != nil {
			return "", nil, err
		}
		configFiles[interfaceName] = filePath
	}
	return tempDir, configFiles, nil
}

func writePerInterfaceConfig(path string, interfaceName string,
	config InterfaceConfig) (string, error) {
	data, err := yaml.Marshal(&config)
	if err != nil {
		return "", fmt.Errorf("unable to marshal config for interface '%s', %v", interfaceName, err)
	}

	file := filepath.Join(path, interfaceName+"-config.yaml")
	if err := os.WriteFile(file, data, 0644); err != nil {
		return "", fmt.Errorf("unable to write config for interface '%s' to file, %v", interfaceName, err)
	}

	return file, nil
}

func CleanupTempConfigFiles(tempDir string) {
	if err := os.RemoveAll(tempDir); err != nil {
		log.Printf("Failed to clean up temporary files in %s: %v", tempDir, err)
	} else {
		log.Printf("Successfully cleaned up temporary files")
	}
}
