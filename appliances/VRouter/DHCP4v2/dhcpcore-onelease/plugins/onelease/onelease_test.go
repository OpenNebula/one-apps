package onelease

import (
	"net"
	"testing"

	"github.com/insomniacslk/dhcp/dhcpv4"
	"github.com/stretchr/testify/assert"
)

func TestGetIPFromMAC(t *testing.T) {
	// Test cases
	testCases := []struct {
		name           string
		macAddress     net.HardwareAddr
		expectedIP     net.IP
		shouldFail     bool
		expectedErrMsg string
	}{
		{
			name:       "Valid OpenNebula MAC",
			macAddress: net.HardwareAddr{0x02, 0x00, 0x0A, 0x0B, 0x0C, 0x0D},
			expectedIP: net.IPv4(0x0A, 0x0B, 0x0C, 0x0D),
			shouldFail: false,
		},
		{
			name:           "Invalid MAC Prefix",
			macAddress:     net.HardwareAddr{0x00, 0x01, 0x0A, 0x0B, 0x0C, 0x0D},
			shouldFail:     true,
			expectedErrMsg: "MAC address 00:01:0a:0b:0c:0d is not from OpenNebula",
		},
		{
			name:           "Invalid MAC Length",
			macAddress:     net.HardwareAddr{0x02, 0x00, 0x0A},
			shouldFail:     true,
			expectedErrMsg: "invalid MAC address",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Prepare a mock DHCP request
			req := &dhcpv4.DHCPv4{
				ClientHWAddr: tc.macAddress,
			}

			// Reset macPrefix
			macPrefix = [2]byte{0x02, 0x00}

			ip, err := getIPFromMAC(req)

			if tc.shouldFail {
				assert.Error(t, err)
				if tc.expectedErrMsg != "" {
					assert.Contains(t, err.Error(), tc.expectedErrMsg)
				}
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tc.expectedIP, ip)
			}
		})
	}
}

func TestSetup4(t *testing.T) {
	testCases := []struct {
		name           string
		args           []string
		shouldFail     bool
		expectedPrefix [2]byte
	}{
		{
			name:           "No Arguments (Default)",
			args:           []string{},
			expectedPrefix: [2]byte{0x02, 0x00},
		},
		{
			name:           "Nil as argument (Default)",
			args:           []string{},
			expectedPrefix: [2]byte{0x02, 0x00},
		},
		{
			name:           "Custom MAC Prefix",
			args:           []string{"AA:BB"},
			expectedPrefix: [2]byte{0xAA, 0xBB},
		},
		{
			name:       "Invalid MAC Prefix Format",
			args:       []string{"AAA:BBB"},
			shouldFail: true,
		},
		{
			name:       "Too Many Arguments",
			args:       []string{"AA:BB", "CC:DD"},
			shouldFail: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Restore default prefix before each test
			macPrefix = [2]byte{0x02, 0x00}

			handler, err := setup4(tc.args...)

			if tc.shouldFail {
				assert.Error(t, err)
				assert.Nil(t, handler)
			} else {
				assert.NoError(t, err)
				assert.NotNil(t, handler)

				// Explicitly check the MAC prefix was set correctly
				assert.Equal(t, tc.expectedPrefix[0], macPrefix[0],
					"First byte of MAC prefix should match")
				assert.Equal(t, tc.expectedPrefix[1], macPrefix[1],
					"Second byte of MAC prefix should match")
			}
		})
	}
}
