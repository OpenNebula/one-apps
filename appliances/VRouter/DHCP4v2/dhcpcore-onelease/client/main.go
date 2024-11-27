package main

/*
 * Sample DHCPv4 client to test on the local interface
 */

import (
	"flag"
	"net"
	"time"

	"github.com/coredhcp/coredhcp/logger"
	"github.com/insomniacslk/dhcp/dhcpv4"
	"github.com/insomniacslk/dhcp/dhcpv4/client4"
)

var log = logger.GetLogger("main")

func main() {
	flag.Parse()

	var macString string
	if len(flag.Args()) > 0 {
		macString = flag.Arg(0)
	} else {
		macString = "00:11:22:33:44:55"
	}

	c := client4.NewClient()
	c.LocalAddr = &net.UDPAddr{
		IP:   net.ParseIP("127.0.0.1"),
		Port: 68,
	}
	c.RemoteAddr = &net.UDPAddr{
		IP:   net.ParseIP("127.0.0.1"),
		Port: 67,
	}
	c.ReadTimeout = 10 * time.Second
	log.Printf("%+v", c)

	mac, err := net.ParseMAC(macString)
	if err != nil {
		log.Fatal(err)
	}

	conv, err := c.Exchange("lo",
		dhcpv4.WithHwAddr(mac))
	for _, p := range conv {
		log.Print(p.Summary())
	}
	if err != nil {
		log.Fatal(err)
	}
}
