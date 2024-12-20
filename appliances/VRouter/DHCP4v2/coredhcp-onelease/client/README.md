# DHCPv4 debug client

This is a simple dhcpv4 client for use as a debugging tool with coredhcp

***This is not a general-purpose DHCP client. This is only a testing/debugging tool for developing CoreDHCP***

# Execution

The client allows to specify a mac address as argument in order to include it in its requests, e.g.

```
go build -o coredhcp_client
sudo ./coredhcp_client "02:00:aa:bb:cc:dd"
```
