# dhcpcore-onelease VRouter plugin for OpenNebula

This go module contains a runnable [dhcpcore](https://github.com/coredhcp/coredhcp) server including our custom `onelease` plugin, which implements the OpenNebula IP Address lease based on the client's MAC address last four bytes (the MAC address should start with the `02:00` prefix).

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
* ./config.yml
* /coredhcp/config.yml
* /root/.coredhcp/config.yml
* /etc/coredhcp/config.yml
```

The config file content should contain the list of plugins and their arguments for each protocol version (DHCPv6 and DHCPv4), e.g.

```
server4:
    # listen is an optional section to specify how the server binds to an
    # interface or address.
    # If unset, the server will listen on the broadcast address on all
    # interfaces, equivalent to:
    ## listen:
        ## - "0.0.0.0"
    plugins:
        - lease_time: 3600s
        - server_id: 10.10.10.1
        - dns: 8.8.8.8 8.8.4.4
        - router: 192.168.1.1
        - netmask: 255.255.255.0
        - range: leases.txt 10.10.10.100 10.10.10.200 60s
        - onelease:
```

[There](https://github.com/coredhcp/coredhcp/blob/master/cmds/coredhcp/config.yml.example) you have an example file in case you want to take it as reference.

# Testing

You can test the server features using the [client](./client/README.md) included in this module.

# Maintenance

TODO: Explain how to generate this main.go file with all the necessary plugins from the [coredhcp-generator](https://github.com/coredhcp/coredhcp/tree/master/cmds/coredhcp-generator).

# Licensing

TODO

