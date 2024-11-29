// Copyright 2018-present the CoreDHCP Authors. All rights reserved
// This source code is licensed under the MIT license found in the
// LICENSE file in the root directory of this source tree.

// Original code: https://github.com/coredhcp/coredhcp/tree/576af8676ffaff9c85800fae235f614cb65410bd/plugins/range
// Adapted by OpenNebula Systems for the VRouter appliance
// Copyright 2024-present OpenNebula Systems

package onelease

import (
	"encoding/binary"
	"net"
	"os"
	"testing"
	"time"

	"github.com/insomniacslk/dhcp/dhcpv4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestPluginState() *PluginState {
	startIP := net.ParseIP("192.168.1.1")
	endIP := net.ParseIP("192.168.1.254")

	p := &PluginState{
		Recordsv4:    make(map[string]*Record),
		LeaseTime:    1 * time.Hour,
		rangeStartIP: startIP,
		rangeEndIP:   endIP,
		allocator:    nil,
	}
	return p
}
func TestParseIPRange(t *testing.T) {
	testCases := []struct {
		name        string
		startIP     string
		endIP       string
		expectError bool
	}{
		{
			name:        "Valid IP Range",
			startIP:     "192.168.1.1",
			endIP:       "192.168.1.254",
			expectError: false,
		},
		{
			name:        "Invalid Start IP",
			startIP:     "invalid",
			endIP:       "192.168.1.254",
			expectError: true,
		},
		{
			name:        "Invalid End IP",
			startIP:     "192.168.1.1",
			endIP:       "invalid",
			expectError: true,
		},
		{
			name:        "Start IP Greater Than End IP",
			startIP:     "192.168.1.255",
			endIP:       "192.168.1.1",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			startIP, endIP, err := parseIPRange(tc.startIP, tc.endIP)

			if tc.expectError {
				assert.Error(t, err)
				assert.Nil(t, startIP)
				assert.Nil(t, endIP)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, startIP)
				assert.NotNil(t, endIP)
			}
		})
	}
}
func TestParseExcludedIPs(t *testing.T) {
	testCases := []struct {
		name        string
		ipList      string
		expectError bool
		expectedLen int
	}{
		{
			name:        "Valid Single IP",
			ipList:      "192.168.1.1",
			expectError: false,
			expectedLen: 1,
		},
		{
			name:        "Valid Multiple IPs",
			ipList:      "192.168.1.1, 192.168.1.2, 192.168.1.3",
			expectError: false,
			expectedLen: 3,
		},
		{
			name:        "Invalid IP",
			ipList:      "192.168.1.1, invalid, 192.168.1.3",
			expectError: true,
			expectedLen: 0,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			excludedIPs, err := parseExcludedIPs(tc.ipList)

			if tc.expectError {
				assert.Error(t, err)
				assert.Nil(t, excludedIPs)
			} else {
				assert.NoError(t, err)
				assert.Len(t, excludedIPs, tc.expectedLen)
			}
		})
	}
}
func TestParseMACPrefix(t *testing.T) {
	testCases := []struct {
		name          string
		prefix        string
		expectError   bool
		expectedBytes [2]byte
	}{
		{
			name:          "Valid MAC Prefix",
			prefix:        "02:00",
			expectError:   false,
			expectedBytes: [2]byte{0x02, 0x00},
		},
		{
			name:        "Invalid Format",
			prefix:      "02-00",
			expectError: true,
		},
		{
			name:        "Invalid First Hex Character",
			prefix:      "GG:00",
			expectError: true,
		},
		{
			name:        "Invalid Second Hex Character",
			prefix:      "02:LL",
			expectError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			prefix, err := parseMACPrefix(tc.prefix)

			if tc.expectError {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
				assert.Len(t, prefix, 2)
				assert.Equal(t, tc.expectedBytes[0], prefix[0])
				assert.Equal(t, tc.expectedBytes[1], prefix[1])
			}
		})
	}
}

func TestCheckMACPrefix(t *testing.T) {
	p := setupTestPluginState()
	p.enableMAC2IP = true
	p.MACPrefix = [2]byte{0x02, 0x00}
	p.ExcludedIPs = []net.IP{net.ParseIP("192.168.1.2")}

	testCases := []struct {
		name        string
		mac         net.HardwareAddr
		expectValid bool
		expectedIP  net.IP
	}{
		{
			name:        "Valid MAC with Matching Prefix",
			mac:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x19},
			expectValid: true,
			expectedIP:  net.IPv4(0xc0, 0xa8, 0x01, 0x19),
		},
		{
			name:        "MAC with Non-Matching Prefix",
			mac:         net.HardwareAddr{0x01, 0x01, 0xc0, 0xa8, 0x01, 0x19},
			expectValid: false,
		},
		{
			name:        "Excluded IP",
			mac:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x02},
			expectValid: false,
		},
		{
			name:        "Invalid MAC",
			mac:         nil,
			expectValid: false,
			expectedIP:  nil,
		},
		{
			name:        "MAC is not in the range",
			mac:         net.HardwareAddr{0x02, 0x00, 0x01, 0x01, 0x01, 0x01},
			expectValid: false,
			expectedIP:  nil,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			ip, valid, err := p.checkMACPrefix(tc.mac)

			if tc.expectValid {
				assert.NoError(t, err)
				assert.True(t, valid)
				assert.Equal(t, tc.expectedIP, ip)
			} else {
				assert.False(t, valid)
			}
		})
	}
}
func TestCheckIPInRange(t *testing.T) {
	p := setupTestPluginState()

	testCases := []struct {
		name    string
		ip      net.IP
		inRange bool
	}{
		{
			name:    "IP in range",
			ip:      net.ParseIP("192.168.1.100"),
			inRange: true,
		},
		{
			name:    "IP below range",
			ip:      net.ParseIP("192.168.1.0"),
			inRange: false,
		},
		{
			name:    "IP above range",
			ip:      net.ParseIP("192.168.1.255"),
			inRange: false,
		},
		{
			name:    "IP in different range",
			ip:      net.ParseIP("192.168.2.20"),
			inRange: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := p.checkIPInRange(tc.ip)
			assert.Equal(t, tc.inRange, result)
		})
	}
}
func TestSetupRange(t *testing.T) {
	deleteDB("test_leases.db")
	testCases := []struct {
		name               string
		args               []string
		expectedLeaseTime  time.Duration
		reqMACAddr         net.HardwareAddr
		expectedIP         net.IP
		expectSetUpError   bool
		expectHandlerError bool
	}{
		{
			name: "Get IP (none allocated and no MAC2IP)",
			args: []string{
				"test_leases.db", // filename
				"192.168.1.1",    // start IP
				"192.168.1.7",    // end IP
				"1h",             // lease time
			},
			expectedLeaseTime:  1 * time.Hour,
			reqMACAddr:         net.HardwareAddr{0xff, 0x00, 0xc0, 0xa8, 0x01, 0x37},
			expectedIP:         net.ParseIP("192.168.1.1"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Get second IP (one allocated and no MAC2IP)",
			args: []string{
				"test_leases.db", // filename
				"192.168.1.1",    // start IP
				"192.168.1.7",    // end IP
				"1h",             // lease time
			},
			expectedLeaseTime:  1 * time.Hour,
			reqMACAddr:         net.HardwareAddr{0xff, 0x01, 0xc0, 0xa8, 0x01, 0x38},
			expectedIP:         net.ParseIP("192.168.1.2"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Get non consecutive IP (192.168.1.7) with MAC2IP",
			args: []string{
				"test_leases.db",           // filename
				"192.168.1.1",              // start IP
				"192.168.1.7",              // end IP
				"0s",                       // lease time
				"--mac2ip",                 // enable MAC2IP
				"--mac2ip-prefix", "02:00", // MAC prefix
			},
			expectedLeaseTime:  0 * time.Second,
			reqMACAddr:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x07},
			expectedIP:         net.ParseIP("192.168.1.7"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Get fifth IP (Two allocated, third and fourth excluded, and no MAC2IP)",
			args: []string{
				"test_leases.db",                            // filename
				"192.168.1.1",                               // start IP
				"192.168.1.7",                               // end IP
				"0s",                                        // lease time
				"--excluded-ips", "192.168.1.3,192.168.1.4", // excluded IPs
			},
			expectedLeaseTime:  0 * time.Second,
			reqMACAddr:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x27},
			expectedIP:         net.ParseIP("192.168.1.5"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Try to get already allocated IP (192.168.1.5) with MAC2IP",
			args: []string{
				"test_leases.db",                            // filename
				"192.168.1.1",                               // start IP
				"192.168.1.7",                               // end IP
				"1h",                                        // lease time
				"--excluded-ips", "192.168.1.3,192.168.1.4", // excluded IPs
				"--mac2ip", // enable MAC2IP
			},
			expectedLeaseTime:  1 * time.Hour,
			reqMACAddr:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x05},
			expectSetUpError:   false,
			expectHandlerError: true,
		},
		{
			name: "Get IP (192.168.1.6) with MAC2IP and invalid MAC prefix",
			args: []string{
				"test_leases.db",                            // filename
				"192.168.1.1",                               // start IP
				"192.168.1.7",                               // end IP
				"1h",                                        // lease time
				"--excluded-ips", "192.168.1.3,192.168.1.4", // excluded IPs
				"--mac2ip", // enable MAC2IP
			},
			expectedLeaseTime:  1 * time.Hour,
			reqMACAddr:         net.HardwareAddr{0xef, 0x12, 0xc0, 0xa8, 0x01, 0xff},
			expectedIP:         net.ParseIP("192.168.1.6"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Try to out of range IP (192.168.1.255) with MAC2IP",
			args: []string{
				"test_leases.db", // filename
				"192.168.1.1",    // start IP
				"192.168.1.7",    // end IP
				"1h",             // lease time
				"--mac2ip",       // enable MAC2IP
			},
			expectedLeaseTime:  1 * time.Hour,
			reqMACAddr:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0xff},
			expectSetUpError:   false,
			expectHandlerError: true,
		},
		{
			name: "Extend expired IP lease with no MAC2IP (192.168.1.5)",
			args: []string{
				"test_leases.db",                  // filename
				"192.168.1.1",                     // start IP
				"192.168.1.7",                     // end IP
				"60s",                             // lease time
				"--excluded-ips", "192.168.1.255", // try to exclude out of range IP
			},
			expectedLeaseTime:  60 * time.Second,
			reqMACAddr:         net.HardwareAddr{0x02, 0x00, 0xc0, 0xa8, 0x01, 0x27},
			expectedIP:         net.ParseIP("192.168.1.5"),
			expectSetUpError:   false,
			expectHandlerError: false,
		},
		{
			name: "Invalid Number of Arguments",
			args: []string{
				"test_leases.db", // filename
				"192.168.1.1",    // start IP
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
		{
			name: "Empty Filename",
			args: []string{
				"",            // empty filename
				"192.168.1.1", // start IP
				"192.168.1.7", // end IP
				"1h",          // lease time
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
		{
			name: "Invalid IP Range",
			args: []string{
				"test_leases.db", // filename
				"invalid",        // invalid start IP
				"192.168.1.7",    // end IP
				"1h",             // lease time
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
		{
			name: "Invalid Lease Time",
			args: []string{
				"test_leases.db", // filename
				"192.168.1.1",    // start IP
				"192.168.1.7",    // end IP
				"invalid",        // invalid lease time
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
		{
			name: "Invalid MAC Prefix",
			args: []string{
				"test_leases.db",             // filename
				"192.168.1.1",                // start IP
				"192.168.1.7",                // end IP
				"1h",                         // lease time
				"--mac2ip",                   // enable MAC2IP
				"--mac2ip-prefix", "invalid", // invalid MAC prefix
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
		{
			name: "Invalid Excluded IPs",
			args: []string{
				"test_leases.db",            // filename
				"192.168.1.1",               // start IP
				"192.168.1.7",               // end IP
				"1h",                        // lease time
				"--excluded-ips", "invalid", // invalid excluded IPs
			},
			expectSetUpError:   true,
			expectHandlerError: false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			handler, err := setupRange(tc.args...)
			if tc.expectSetUpError {
				assert.Error(t, err, "Expected an error for test case: %s", tc.name)
				assert.Nil(t, handler, "Handler should be nil when there's an error")
				return
			}
			require.NoError(t, err, "Unexpected error for test case: %s", tc.name)
			assert.NotNil(t, handler, "Handler should not be nil")

			req := &dhcpv4.DHCPv4{
				ClientHWAddr: tc.reqMACAddr,
			}
			resp := &dhcpv4.DHCPv4{
				Options: make(dhcpv4.Options),
			}
			handler(req, resp)
			if tc.expectHandlerError {
				assert.Nil(t, resp.YourIPAddr)
			} else {
				assert.Equal(t, tc.expectedIP.To4(), resp.YourIPAddr.To4())
				assert.Equal(t, tc.expectedLeaseTime.Seconds(),
					float64(binary.BigEndian.Uint32(resp.Options.Get(dhcpv4.OptionIPAddressLeaseTime))))
			}
		})
	}
	deleteDB("test_leases.db")
}

func deleteDB(filePath string) {
	err := os.Remove(filePath)
	if err != nil {
		log.Println("Error deleting the file:", err)
	}
}
