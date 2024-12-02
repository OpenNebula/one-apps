// Copyright 2018-present the CoreDHCP Authors. All rights reserved
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

// Original code: https://github.com/coredhcp/coredhcp/tree/576af8676ffaff9c85800fae235f614cb65410bd/plugins/range
// Adapted by OpenNebula Systems for the VRouter appliance
// Copyright 2024-present OpenNebula Systems

package onelease

import (
	"database/sql"
	"encoding/binary"
	"errors"
	"fmt"
	"net"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/coredhcp/coredhcp/handler"
	"github.com/coredhcp/coredhcp/logger"
	"github.com/coredhcp/coredhcp/plugins"
	"github.com/coredhcp/coredhcp/plugins/allocators"
	"github.com/coredhcp/coredhcp/plugins/allocators/bitmap"
	"github.com/insomniacslk/dhcp/dhcpv4"
	"github.com/spf13/pflag"
)

var log = logger.GetLogger("plugins/onelease")

// Plugin wraps plugin registration information
var Plugin = plugins.Plugin{
	Name:   "onelease",
	Setup4: setupRange,
}

// Record holds an IP lease record
type Record struct {
	IP       net.IP
	expires  int
	hostname string
}

// PluginState is the data held by an instance of the range plugin
type PluginState struct {
	// Rough lock for the whole plugin, we'll get better performance once we use leasestorage
	sync.Mutex
	// Recordsv4 holds a MAC -> IP address and lease time mapping
	Recordsv4    map[string]*Record
	LeaseTime    time.Duration
	ExcludedIPs  []net.IP
	leasedb      *sql.DB
	allocator    allocators.Allocator
	enableMAC2IP bool
	MACPrefix    [2]byte
	rangeStartIP net.IP
	rangeEndIP   net.IP
}

// Handler4 handles DHCPv4 packets for the range plugin
func (p *PluginState) Handler4(req, resp *dhcpv4.DHCPv4) (*dhcpv4.DHCPv4, bool) {
	p.Lock()
	defer p.Unlock()
	record, ok := p.Recordsv4[req.ClientHWAddr.String()]
	hostname := req.HostName()
	if !ok {
		// Allocating new address since there isn't one allocated
		log.Printf("MAC address %s is new, leasing new IPv4 address", req.ClientHWAddr.String())
		// Check if the MAC address should be mapped to a specific IP address
		ipToAllocate := net.IPNet{}
		macPrefixMatches := false
		if p.enableMAC2IP {
			macAddress := req.ClientHWAddr
			ipFromMAC, ok, err := p.checkMACPrefix(macAddress)
			if err != nil {
				log.Errorf("MAC2IP lease failed for mac %v: %v", macAddress.String(), err)
				return resp, true
			}
			if ok {
				macPrefixMatches = true
				//propose the least 4 bytes of the mac address for allocating an IP address
				ipToAllocate = net.IPNet{IP: ipFromMAC}
				log.Infof("MAC %s matches the prefix %02x:%02x, trying to allocate IP %s...", macAddress.String(), p.MACPrefix[0], p.MACPrefix[1], ipToAllocate.IP.String())
			} else {
				log.Infof("MAC %s does not match the prefix %x, providing conventional lease...", macAddress.String(), p.MACPrefix)
			}
		}
		// The allocator will try to allocate the given IP address, but if it is already allocated, it will return a different one (an available one)
		ip, err := p.allocator.Allocate(ipToAllocate)
		if err != nil {
			log.Errorf("Could not allocate IP for MAC %s: %v", req.ClientHWAddr.String(), err)
			return resp, true
		}

		// if the MAC address is mapped to an IP address, check if the allocated IP address matches the requested one, if not, revert the allocation and return
		if p.enableMAC2IP && macPrefixMatches && !ip.IP.Equal(ipToAllocate.IP) {
			p.allocator.Free(ip)
			log.Errorf("MAC2IP: Could not allocate IP %s for MAC \"%s\": IP already allocated", ipToAllocate.IP.String(), req.ClientHWAddr.String())
			return resp, true
		}

		rec := Record{
			IP:       ip.IP.To4(),
			expires:  int(time.Now().Add(p.LeaseTime).Unix()),
			hostname: hostname,
		}
		err = p.saveIPAddress(req.ClientHWAddr, &rec)
		if err != nil {
			log.Errorf("SaveIPAddress for MAC %s failed: %v", req.ClientHWAddr.String(), err)
		}
		p.Recordsv4[req.ClientHWAddr.String()] = &rec
		record = &rec
	} else {
		// Ensure we extend the existing lease at least past when the one we're giving expires
		expiry := time.Unix(int64(record.expires), 0)
		if expiry.Before(time.Now().Add(p.LeaseTime)) {
			record.expires = int(time.Now().Add(p.LeaseTime).Round(time.Second).Unix())
			record.hostname = hostname
			err := p.saveIPAddress(req.ClientHWAddr, record)
			if err != nil {
				log.Errorf("Could not persist lease for MAC %s: %v", req.ClientHWAddr.String(), err)
			}
		}
	}
	resp.YourIPAddr = record.IP
	resp.Options.Update(dhcpv4.OptIPAddressLeaseTime(p.LeaseTime.Round(time.Second)))
	log.Printf("Found IP address %s for MAC %s", record.IP, req.ClientHWAddr.String())
	return resp, true
}

func (p *PluginState) checkIPInRange(ip net.IP) bool {
	return binary.BigEndian.Uint32(ip.To4()) >= binary.BigEndian.Uint32(p.rangeStartIP.To4()) &&
		binary.BigEndian.Uint32(ip.To4()) <= binary.BigEndian.Uint32(p.rangeEndIP.To4())
}

func (p *PluginState) checkMACPrefix(mac net.HardwareAddr) (net.IP, bool, error) {
	// verify that the MAC address is valid
	if _, err := net.ParseMAC(mac.String()); err != nil {
		return nil, false, fmt.Errorf("invalid MAC address: %v", mac)
	}

	// verify that the two first bytes equal to macPrefix, if not, return
	if mac[0] != p.MACPrefix[0] || mac[1] != p.MACPrefix[1] {
		return nil, false, nil
	}

	// retrieve the IP address from the MAC address
	// the IP address is the last 4 bytes of the MAC address
	ip := net.IPv4(mac[2], mac[3], mac[4], mac[5])

	// check if the ip is in the excluded list
	for _, excluded := range p.ExcludedIPs {
		if ip.Equal(excluded) {
			return nil, false, fmt.Errorf("excluded IP %v", ip)
		}
	}

	// check if the ip is in the lease range
	if !p.checkIPInRange(ip) {
		return nil, false, fmt.Errorf("IP %v is not in the range", ip)
	}

	return ip, true, nil
}

func setupRange(args ...string) (handler.Handler4, error) {
	var (
		err error
		p   PluginState
	)

	if len(args) < 4 {
		return nil, fmt.Errorf("invalid number of arguments, want at least: 4 (file name, start IP, end IP, lease time), got: %d", len(args))
	}
	filename := args[0]
	if filename == "" {
		return nil, errors.New("file name cannot be empty")
	}

	p.rangeStartIP, p.rangeEndIP, err = parseIPRange(args[1], args[2])
	if err != nil {
		return nil, fmt.Errorf("invalid IP range: %v", err)
	}

	p.allocator, err = bitmap.NewIPv4Allocator(p.rangeStartIP, p.rangeEndIP)
	if err != nil {
		return nil, fmt.Errorf("could not create an allocator: %w", err)
	}

	p.LeaseTime, err = time.ParseDuration(args[3])
	if err != nil {
		return nil, fmt.Errorf("invalid lease duration: %v", args[3])
	}

	optionalArgs := args[4:]

	var excludedIPs string
	var macPrefix string

	pluginFlags := pflag.NewFlagSet("onelease", pflag.ExitOnError)

	pluginFlags.StringVar(&excludedIPs, "excluded-ips", "", "Comma-separated list of excluded IP addresses")
	pluginFlags.BoolVar(&p.enableMAC2IP, "mac2ip", false, "Enables MAC to IP address mapping")
	pluginFlags.StringVar(&macPrefix, "mac2ip-prefix", "02:00", "2-byte MAC prefix for MAC to IP address mapping")

	pluginFlags.Parse(optionalArgs)

	if p.enableMAC2IP && macPrefix != "" {
		p.MACPrefix, err = parseMACPrefix(macPrefix)
		if err != nil {
			return nil, fmt.Errorf("invalid MAC prefix: %v", macPrefix)
		}
	}

	if excludedIPs != "" {
		p.ExcludedIPs, err = parseExcludedIPs(excludedIPs)
		if err != nil {
			return nil, fmt.Errorf("invalid excluded IPs: %v", excludedIPs)
		}
		//check if excluded IPs are in the range and pre-allocate them
		for _, excluded := range p.ExcludedIPs {
			if !p.checkIPInRange(excluded) {
				log.Warnf("excluded IP %v is not in the range, not preallocation needed.", excluded)
				continue
			}
			if _, err := p.allocator.Allocate(net.IPNet{IP: excluded}); err != nil {
				return nil, fmt.Errorf("could not pre-allocate excluded IP %v: %w", excluded, err)
			}
		}
	}

	if err := p.registerBackingDB(filename); err != nil {
		return nil, fmt.Errorf("could not setup lease storage: %w", err)
	}
	p.Recordsv4, err = loadRecords(p.leasedb)
	if err != nil {
		return nil, fmt.Errorf("could not load records from file: %v", err)
	}

	log.Printf("Loaded %d DHCPv4 leases from %s", len(p.Recordsv4), filename)

	for _, v := range p.Recordsv4 {
		ip, err := p.allocator.Allocate(net.IPNet{IP: v.IP})
		if err != nil {
			return nil, fmt.Errorf("failed to re-allocate leased ip %v: %v", v.IP.String(), err)
		}
		if ip.IP.String() != v.IP.String() {
			return nil, fmt.Errorf("allocator did not re-allocate requested leased ip %v: %v", v.IP.String(), ip.String())
		}
	}

	return p.Handler4, nil
}

func parseIPRange(startIP, endIP string) (net.IP, net.IP, error) {
	ipRangeStart := net.ParseIP(startIP)
	if ipRangeStart.To4() == nil {
		return nil, nil, fmt.Errorf("invalid IPv4 address: %v", startIP)
	}
	ipRangeEnd := net.ParseIP(endIP)
	if ipRangeEnd.To4() == nil {
		return nil, nil, fmt.Errorf("invalid IPv4 address: %v", endIP)
	}
	if binary.BigEndian.Uint32(ipRangeStart.To4()) >= binary.BigEndian.Uint32(ipRangeEnd.To4()) {
		return nil, nil, errors.New("start of IP range has to be lower than the end of an IP range")
	}
	return ipRangeStart, ipRangeEnd, nil
}

func parseExcludedIPs(ipList string) ([]net.IP, error) {
	excludedIPs := []net.IP{}
	for _, ip := range strings.Split(ipList, ",") {
		excluded := net.ParseIP(strings.TrimSpace(ip))
		if excluded.To4() == nil {
			return nil, fmt.Errorf("invalid excluded IP address: %v", ip)
		}
		excludedIPs = append(excludedIPs, excluded)
	}
	return excludedIPs, nil
}

func parseMACPrefix(prefix string) ([2]byte, error) {
	regex := `^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$`
	matched, err := regexp.MatchString(regex, prefix)
	if err != nil {
		return [2]byte{}, fmt.Errorf("error matching regex: %v", err)
	}
	if !matched {
		return [2]byte{}, fmt.Errorf("invalid MAC prefix format: %s", prefix)
	}
	parts := strings.Split(prefix, ":")
	macByte0, err := strconv.ParseUint(parts[0], 16, 8)
	if err != nil {
		return [2]byte{}, fmt.Errorf("invalid MAC prefix byte [0]: %v", err)
	}
	macByte1, err := strconv.ParseUint(parts[1], 16, 8)
	if err != nil {
		return [2]byte{}, fmt.Errorf("invalid MAC prefix byte [1]: %v", err)
	}
	return [2]byte{byte(macByte0), byte(macByte1)}, nil
}
