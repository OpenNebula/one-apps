package onelease

import (
	"errors"
	"fmt"
	"net"
	"strconv"
	"strings"

	"github.com/coredhcp/coredhcp/handler"
	"github.com/coredhcp/coredhcp/logger"
	"github.com/coredhcp/coredhcp/plugins"
	"github.com/insomniacslk/dhcp/dhcpv4"
)

// Plugin wraps the information necessary to register a plugin.
// In the main package, you need to export a `plugins.Plugin` object called
// `Plugin`, so it can be registered into the plugin registry.
// Just import your plugin, and fill the structure with plugin name and setup
// functions:
//
// import (
//
//	"github.com/coredhcp/coredhcp/plugins"
//	"github.com/coredhcp/coredhcp/plugins/example"
//
// )
//
//	var Plugin = plugins.Plugin{
//	    Name: "example",
//	    Setup6: setup6,
//	    Setup4: setup4,
//	}
//
// Name is simply the name used to register the plugin. It must be unique to
// other registered plugins, or the operation will fail. In other words, don't
// declare plugins with colliding names.
//
// Setup6 and Setup4 are the setup functions for DHCPv6 and DHCPv4 traffic
// handlers. They conform to the `plugins.SetupFunc6` and `plugins.SetupFunc4`
// interfaces, so they must return a `plugins.Handler6` and a `plugins.Handler4`
// respectively.
// A `nil` setup function means that that protocol won't be handled by this
// plugin.
//
// Note that importing the plugin is not enough to use it: you have to
// explicitly specify the intention to use it in the `config.yml` file, in the
// plugins section. For example:
//
// server6:
//
//	listen: '[::]547'
//	- example:
//	- server_id: LL aa:bb:cc:dd:ee:ff
//	- file: "leases.txt"
var Plugin = plugins.Plugin{
	Name: "onelease",
	//Setup6: setup6,
	Setup4: setup4,
}

var (
	log           = logger.GetLogger("plugins/onelease")
	macPrefix     = [2]byte{0x02, 0x00}
	excludedIpSet = make(map[string]struct{})
)

// setup6 is the setup function to initialize the handler for DHCPv6
// traffic. This function implements the `plugin.SetupFunc6` interface.
// This function returns a `handler.Handler6` function, and an error if any.
// In this example we do very little in the setup function, and just return the
// `exampleHandler6` function. Such function will be called for every DHCPv6
// packet that the server receives. Remember that a handler may not be called
// for each packet, if the handler chain is interrupted before reaching it.
/*func setup6(args ...string) (handler.Handler6, error) {
	log.Printf("loaded plugin for DHCPv6.")
	return exampleHandler6, nil
}*/

// setup4 behaves like setupExample6, but for DHCPv4 packets. It
// implements the `plugin.SetupFunc4` interface.
func setup4(args ...string) (handler.Handler4, error) {
	log.Printf("loaded plugin for DHCPv4.")
	if len(args) > 1 {
		log.Errorf("Expected one MAC prefix, but received %d", len(args))
		return nil, errors.New("one_lease failed to initialize (at most one MAC prefix expected)")
	}

	if len(args) == 0 {
		log.Printf("No MAC prefix provided. Using default: %02x:%02x", macPrefix[0], macPrefix[1])
		return ipMACHandler4, nil
	}

	bytes := strings.Split(args[0], ":")
	if len(bytes) != 2 {
		log.Error("Invalid MAC prefix provided")
		return nil, errors.New("one_lease failed to initialize (invalid MAC prefix format)")
	}

	tempMacPrefix := make([]byte, 2)
	for index, macByte := range bytes {
		value, err := strconv.ParseUint(macByte, 16, 8)
		if err != nil {
			log.Errorf("Invalid hexadecimal value '%s': %v", macByte, err)
			return nil, errors.New("one_lease failed to initialize (invalid hexadecimal value)")
		}
		tempMacPrefix[index] = byte(value)
	}
	copy(macPrefix[:], tempMacPrefix)
	return ipMACHandler4, nil
}

// exampleHandler6 handles DHCPv6 packets for the example plugin. It implements
// the `handler.Handler6` interface. The input arguments are the request packet
// that the server received from a client, and the response packet that has been
// computed so far. This function returns the response packet to be sent back to
// the client, and a boolean.
// The response can be either the same response packet received as input, a
// modified response packet, or nil. If nil, the server will not reply to the
// client, basically dropping the request.
// The returned boolean indicates to the server whether the chain of plugins
// should continue or not. If `true`, the server will stop at this plugin, and
// respond to the client (or drop the response, if nil). If `false`, the server
// will call the next plugin in the chan, using the returned response packet as
// input for the next plugin.
/*func exampleHandler6(req, resp dhcpv6.DHCPv6) (dhcpv6.DHCPv6, bool) {
	log.Printf("received DHCPv6 packet: %s", req.Summary())
	// return the unmodified response, and false. This means that the next
	// plugin in the chain will be called, and the unmodified response packet
	// will be used as its input.
	return resp, false
}*/

// exampleHandler4 behaves like exampleHandler6, but for DHCPv4 packets. It
// implements the `handler.Handler4` interface.
func ipMACHandler4(req, resp *dhcpv4.DHCPv4) (*dhcpv4.DHCPv4, bool) {
	log.Debugf("received DHCPv4 request: %s", req.Summary())

	// Get the IP address from the MAC address
	ip, err := getIPFromMAC(req)
	if err != nil {
		log.Errorf("leasing IP address from MAC address: %v", err)
		return resp, false
	}

	log.Printf("leasing IP address %s for MAC %s", ip, req.ClientHWAddr.String())

	resp.YourIPAddr = ip

	log.Debugf("sending DHCPv4 response: %s", resp.Summary())

	// return the unmodified response, and false. This means that the next
	// plugin in the chain will be called, and the unmodified response packet
	// will be used as its input.
	return resp, false
}

func getIPFromMAC(req *dhcpv4.DHCPv4) (net.IP, error) {
	mac := req.ClientHWAddr

	// verify that the MAC address is valid
	if _, err := net.ParseMAC(mac.String()); err != nil {
		return nil, fmt.Errorf("invalid MAC address: %v", mac)
	}

	// verify that the two first bytes equal to macPrefix
	if mac[0] != macPrefix[0] || mac[1] != macPrefix[1] {
		return nil, fmt.Errorf("MAC address %s is not from OpenNebula", mac)
	}

	// retrieve the IP address from the MAC address
	// the IP address is the last 4 bytes of the MAC address
	ip := net.IPv4(mac[2], mac[3], mac[4], mac[5])

	if _, exists := excludedIpSet[ip.String()]; exists {
		// TODO: IP excluded
		return nil, nil
	} else {
		return ip, nil
	}
}
