# frozen_string_literal: true

require 'ipaddr'
require 'rspec'
require 'tmpdir'

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should extract sdnat4 info from vnets' do
        load './main.rb'; include Service::SDNAT4

        allow(Service::SDNAT4).to receive(:ip_addr_show).and_return({
            'ifname' => 'lo',
            'addr_info' => [
                { 'family'    => 'inet',
                  'local'     => '127.0.0.1',
                  'prefixlen' => 8,
                  'label'     => 'lo' },

                { 'family'    => 'inet',
                  'local'     => '10.2.11.202',
                  'prefixlen' => 32,
                  'label'     => 'SDNAT4' },

               # { 'family'    => 'inet',
               #   'local'     => '10.2.11.203',
               #   'prefixlen' => 32,
               #   'label'     => 'SDNAT4' }
            ]
        })

        (vnets ||= []) << JSON.parse(<<~'VNET0')
            {
              "VNET": {
                "ID": "0",
                "NAME": "service",
                "USED_LEASES": "6",
                "VROUTERS": {
                  "ID": [ "35" ]
                },
                "PARENT_NETWORK_ID": {},
                "AR_POOL": {
                  "AR": [
                    {
                      "AR_ID": "0",
                      "IP": "10.2.11.200",
                      "MAC": "02:00:0a:02:0b:c8",
                      "SIZE": "48",
                      "TYPE": "IP4",
                      "MAC_END": "02:00:0a:02:0b:f7",
                      "IP_END": "10.2.11.247",
                      "USED_LEASES": "6",
                      "LEASES": {
                        "LEASE": [
                          { "IP": "10.2.11.200", "MAC": "02:00:0a:02:0b:c8", "VM": "265", "NIC_NAME": "NIC0" },
                          { "IP": "10.2.11.201", "MAC": "02:00:0a:02:0b:c9", "VM": "266", "NIC_NAME": "NIC0" },
                          {
                            "IP": "10.2.11.202",
                            "MAC": "02:00:0a:02:0b:ca",
                            "VM": "267",
                            "PARENT": "NIC0",
                            "PARENT_NETWORK_ID": "1",
                            "EXTERNAL": true,
                            "NIC_NAME": "NIC0_ALIAS1"
                          },
                          {
                            "IP": "10.2.11.203",
                            "MAC": "02:00:0a:02:0b:cb",
                            "VM": "268",
                            "PARENT": "NIC0",
                            "PARENT_NETWORK_ID": "1",
                            "EXTERNAL": true,
                            "NIC_NAME": "NIC0_ALIAS1"
                          },
                          { "IP": "10.2.11.204", "MAC": "02:00:0a:02:0b:cc", "VM": "269", "NIC_NAME": "NIC0" },
                          { "IP": "10.2.11.205", "MAC": "02:00:0a:02:0b:cd", "VM": "270", "NIC_NAME": "NIC0" }
                        ]
                      }
                    }
                  ]
                },
                "TEMPLATE": {
                  "NETWORK_ADDRESS": "10.2.11.0",
                  "NETWORK_MASK": "255.255.255.0",
                  "GATEWAY": "10.2.11.1",
                  "DNS": "10.2.11.40"
                }
              }
            }
        VNET0
        (vnets ||= []) << JSON.parse(<<~'VNET1')
            {
              "VNET": {
                "ID": "1",
                "NAME": "private",
                "USED_LEASES": "24",
                "VROUTERS": {
                  "ID": [ "35" ]
                },
                "PARENT_NETWORK_ID": {},
                "AR_POOL": {
                  "AR": [
                    {
                      "AR_ID": "0",
                      "IP": "172.20.0.100",
                      "MAC": "02:00:ac:14:00:64",
                      "SIZE": "100",
                      "TYPE": "IP4",
                      "MAC_END": "02:00:ac:14:00:c7",
                      "IP_END": "172.20.0.199",
                      "USED_LEASES": "24",
                      "LEASES": {
                        "LEASE": [
                          { "IP": "172.20.0.100", "MAC": "02:00:ac:14:00:64", "VNET": "40" },
                          { "IP": "172.20.0.101", "MAC": "02:00:ac:14:00:65", "VNET": "40" },
                          { "IP": "172.20.0.102", "MAC": "02:00:ac:14:00:66", "VNET": "40" },
                          { "IP": "172.20.0.103", "MAC": "02:00:ac:14:00:67", "VNET": "40" },
                          { "IP": "172.20.0.104", "MAC": "02:00:ac:14:00:68", "VNET": "40" },
                          { "IP": "172.20.0.105", "MAC": "02:00:ac:14:00:69", "VNET": "40" },
                          { "IP": "172.20.0.106", "MAC": "02:00:ac:14:00:6a", "VNET": "40" },
                          { "IP": "172.20.0.107", "MAC": "02:00:ac:14:00:6b", "VNET": "40" },
                          { "IP": "172.20.0.108", "MAC": "02:00:ac:14:00:6c", "VNET": "40" },
                          { "IP": "172.20.0.109", "MAC": "02:00:ac:14:00:6d", "VNET": "40" },
                          { "IP": "172.20.0.110", "MAC": "02:00:ac:14:00:6e", "VNET": "40" },
                          { "IP": "172.20.0.111", "MAC": "02:00:ac:14:00:6f", "VNET": "40" },
                          { "IP": "172.20.0.112", "MAC": "02:00:ac:14:00:70", "VNET": "40" },
                          { "IP": "172.20.0.113", "MAC": "02:00:ac:14:00:71", "VNET": "40" },
                          { "IP": "172.20.0.114", "MAC": "02:00:ac:14:00:72", "VNET": "40" },
                          { "IP": "172.20.0.115", "MAC": "02:00:ac:14:00:73", "VNET": "40" },
                          { "IP": "172.20.0.116", "MAC": "02:00:ac:14:00:74", "VNET": "40" },
                          { "IP": "172.20.0.117", "MAC": "02:00:ac:14:00:75", "VNET": "40" },
                          { "IP": "172.20.0.118", "MAC": "02:00:ac:14:00:76", "VNET": "40" },
                          { "IP": "172.20.0.119", "MAC": "02:00:ac:14:00:77", "VNET": "40" },
                          { "IP": "172.20.0.120", "MAC": "02:00:ac:14:00:78", "VM": "267", "NIC_NAME": "NIC0" },
                          { "IP": "172.20.0.121", "MAC": "02:00:ac:14:00:79", "VM": "268", "NIC_NAME": "NIC0" },
                          { "IP": "172.20.0.122", "MAC": "02:00:ac:14:00:7a", "VM": "269", "NIC_NAME": "NIC1" },
                          { "IP": "172.20.0.123", "MAC": "02:00:ac:14:00:7b", "VM": "270", "NIC_NAME": "NIC1" }
                        ]
                      }
                    }
                  ]
                },
                "TEMPLATE": {
                  "NETWORK_ADDRESS": "172.20.0.0",
                  "NETWORK_MASK": "255.255.255.0",
                  "GATEWAY": "172.20.0.86"
                }
              }
            }
        VNET1

        clear_vars Service::SDNAT4

        Service::SDNAT4.instance_variable_set(:@subnets, [
            IPAddr.new('10.2.11.0/24'),
            IPAddr.new('172.20.0.0/16')
        ])

        expect(Service::SDNAT4.extract_external(vnets)).to eq ({
            external: [
                { 'EXTERNAL'          => true,
                  'IP'                => '10.2.11.202',
                  'MAC'               => '02:00:0a:02:0b:ca',
                  'NIC_NAME'          => 'NIC0_ALIAS1',
                  'PARENT'            => 'NIC0',
                  'PARENT_NETWORK_ID' => '1',
                  'VM'                => '267' },

                { 'EXTERNAL'          => true,
                  'IP'                => '10.2.11.203',
                  'MAC'               => '02:00:0a:02:0b:cb',
                  'NIC_NAME'          => 'NIC0_ALIAS1',
                  'PARENT'            => 'NIC0',
                  'PARENT_NETWORK_ID' => '1',
                  'VM'                => '268' }
            ],
            ip_map: { '10.2.11.202' => '172.20.0.120',
                      '10.2.11.203' => '172.20.0.121' },
            to_del: [],
            to_add: [ '10.2.11.203' ]
        })
    end
end
