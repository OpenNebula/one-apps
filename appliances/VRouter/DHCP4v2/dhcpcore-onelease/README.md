# dhcpcore-onelease VRouter plugin for OpenNebula

This go module contains a wrapper for [dhcpcore](https://github.com/coredhcp/coredhcp), that instantiate a dhcpcore server for each interface indicated in the configuation file, allowing specifying configurations for requests coming from different interfaces. Those services could include our custom `onelease` plugin, which implements the OpenNebula IP Address lease based on the client's MAC address last four bytes (the MAC address should start with the `02:00` prefix).

# Execution

In order to run the server, you should execute the following commands:
```
go build .
sudo ./dhcpcore-onerelease
```

The dhcpcore server will look for a configuration YAML file, for instance located in this same directory (config.yml). See the section below in order to see how to configure it.

# Configuration

In order to load the plugin on the server, you should have a `config.yml` configuration file in one of the following places:
```
* ./onelease-config.yml
* /coredhcp/onelease-config.yml
* /root/.coredhcp/onelease-config.yml
* /etc/coredhcp/onelease-config.yml
```

or you can pass the file explicitly when running the server with the `-c` option:

```
sudo ./dhcpcore-onerelease -c myconfig.yml
```


The config file content should contain the list of plugins and their arguments for each protocol version (DHCPv6 and DHCPv4), e.g.

```
eth0:
  server4:
    listen:
      - "%eth0"
    plugins:
      - lease_time: 3600s
      - server_id: 192.168.100.1
      - dns: 8.8.8.8 8.8.4.4
      - router: 192.168.100.1
      - netmask: 255.255.255.0
      - range: leases0.txt 192.168.100.20 192.168.100.30 60s
      - onelease:
eth1:
  server4:
    listen:
      - "%eth1"
    plugins:
      - lease_time: 3600s
      - server_id: 172.100.10.1
      - dns: 8.8.8.8 8.8.4.4
      - router: 172.100.10.1
      - netmask: 255.255.255.0
      - range: leases1.txt 172.100.10.2 172.100.10.100 60s
      - onelease:
```

[There](https://github.com/coredhcp/coredhcp/blob/master/cmds/coredhcp/config.yml.example) you have an example of each interface configuration in case you want to take it as reference, but as we are using a wrapper,
remember to nest the configuration on each interface tag.

# Testing

You can test the server features using the [client](./client/README.md) included in this module.

# Maintenance

TODO: Explain how to generate this main.go file with all the necessary plugins from the [coredhcp-generator](https://github.com/coredhcp/coredhcp/tree/master/cmds/coredhcp-generator).

# Licensing

TODO

