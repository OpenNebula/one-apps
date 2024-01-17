# frozen_string_literal: true

require 'json'
require 'rspec'
require_relative 'vrouter.rb'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

RSpec.describe 'detect_addrs' do
    it 'should parse IP variables' do
        clear_env

        ENV['ETH0_IP']   = '1.2.3.4'
        ENV['ETH0_MASK'] = '255.255.0.0'
        ENV['ETH1_IP']   = '2.3.4.5'
        ENV['ETH1_MASK'] = '255.255.255.0'

        expect(detect_addrs).to eq ({
            'eth0' => { 'ETH0_IP0' => '1.2.3.4/16' },
            'eth1' => { 'ETH1_IP0' => '2.3.4.5/24' }
        })
    end
end

RSpec.describe 'detect_vips' do
    it 'should parse VIP variables' do
        clear_env

        ENV['ETH0_MASK']                = '255.255.0.0'
        ENV['ETH0_VROUTER_IP']          = '1.2.3.4'
        ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '2.3.4.5/24'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '3.4.5.6'

        expect(detect_vips).to eq ({
            'eth0' => { 'ETH0_VIP0' => '1.2.3.4/16',
                        'ETH0_VIP1' => '2.3.4.5/24' },
            'eth1' => { 'ETH1_VIP0' => '3.4.5.6/32' }
        })
    end
end

RSpec.describe 'detect_endpoints' do
    it 'should merge IP and VIP variables correctly' do
        clear_env

        ENV['ETH0_IP']   = '1.2.3.4'
        ENV['ETH0_MASK'] = '255.255.0.0'
        ENV['ETH1_IP']   = '2.3.4.5'
        ENV['ETH1_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '3.4.5.6'

        expect(detect_endpoints).to eq ({
            'eth0' => { 'ETH0_EP0' => '1.2.3.4/16' },
            'eth1' => { 'ETH1_EP0' => '3.4.5.6/24' }
        })
    end
end

RSpec.describe 'parse_interfaces' do
    it 'should return empty interfaces with nil input' do
        expect(parse_interfaces(nil)).to be_empty
    end

    it 'should parse interfaces from a string' do
        allow(self).to receive(:detect_nics).and_return([
            'eth0',
            'eth1',
            'eth2',
            'eth3'
        ])
        allow(self).to receive(:addrs_to_nics).and_return({
            '10.0.0.1' => ['eth0', 'eth2'],
            '10.0.1.1' => ['eth1'],
            '10.0.1.2' => ['eth1']
        })
        tests = [
            [ '10.0.0.1', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: nil } ],
                            'eth2' => [ { name: 'eth2', addr: '10.0.0.1', port: nil } ] } ],

            [ '10.0.0.1@53', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: '53' } ],
                               'eth2' => [ { name: 'eth2', addr: '10.0.0.1', port: '53' } ] } ],

            [ 'eth0/10.0.0.1', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: nil } ] } ],

            [ 'eth0/10.0.0.1@53', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: '53' } ] } ],

            [ '10.0.1.1@53 10.0.1.2@53', { 'eth1' => [ { name: 'eth1', addr: '10.0.1.1', port: '53' },
                                                       { name: 'eth1', addr: '10.0.1.2', port: '53' } ] } ],

            [ 'eth7/10.0.0.7 10.0.1.1@53', { 'eth1' => [ { name: 'eth1', addr: '10.0.1.1', port: '53' } ],
                                             'eth7' => [ { name: 'eth7', addr: '10.0.0.7', port: nil  } ] } ],

            [ 'eth0/10.0.0.1@53 eth1/10.0.1.1@53', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: '53' } ],
                                                     'eth1' => [ { name: 'eth1', addr: '10.0.1.1', port: '53' } ] } ],

            [ 'eth0/10.0.0.1 eth1/10.0.1.1', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: nil } ],
                                               'eth1' => [ { name: 'eth1', addr: '10.0.1.1', port: nil } ] } ],

            [ 'eth0 eth1,eth2;eth3', { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ],
                                       'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                                       'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                                       'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ],

            [ 'eth0/10.0.0.1@', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: nil } ] } ],

            [ 'eth0/10.0.0.1', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: nil } ] } ],

            [ 'eth0/', { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ] } ],

            [ 'eth0', { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ] } ],

            [ '', { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ],
                    'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                    'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                    'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ]
        ]
        tests.each do |input, output|
            expect(parse_interfaces(input)).to eq output
        end
    end

    it 'should parse interfaces from a string (negation)' do
        allow(self).to receive(:detect_nics).and_return([
            'eth0',
            'eth1',
            'eth2',
            'eth3'
        ])
        allow(self).to receive(:addrs_to_nics).and_return({
            '10.0.0.1' => ['eth0', 'eth2'],
            '10.0.1.1' => ['eth1']
        })
        tests = [
            [ 'eth0/10.0.0.1@53 eth1 eth2 !10.0.1.1', { 'eth0' => [ { name: 'eth0', addr: '10.0.0.1', port: '53' } ],
                                                        'eth2' => [ { name: 'eth2', addr:        nil, port:  nil } ] } ],

            [ '!eth1 10.0.1.1@53 eth3', { 'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ],

            [ '10.0.1.1@53 eth3', { 'eth1' => [ { name: 'eth1', addr: '10.0.1.1', port: '53' } ],
                                    'eth3' => [ { name: 'eth3', addr:        nil, port:  nil } ] } ],

            [ '!10.0.1.1', { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ],
                             'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                             'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ],

            [ '!eth0 !eth2', { 'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                               'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ],

            [ '!eth0', { 'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                         'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                         'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] } ]
        ]
        tests.each do |input, output|
            expect(parse_interfaces(input)).to eq output
        end
    end
end

RSpec.describe 'render_interface' do
    it 'should render interfaces from parts' do
        tests = [
            [ { name: 'eth0', addr: nil  , port: nil   },
              { name: true  , addr: false, port: false }, 'eth0' ],

            [ { name: 'eth0', addr: nil  , port: nil   },
              { name: false , addr: false, port: false }, 'eth0' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: nil   },
              { name: true  , addr: false     , port: false }, 'eth0' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: nil   },
              { name: true  , addr: true      , port: false }, 'eth0/10.0.0.1' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: nil   },
              { name: false , addr: true      , port: false }, '10.0.0.1' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: '53' },
              { name:  true , addr: true      , port: true }, 'eth0/10.0.0.1@53' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: '53'  },
              { name:  true , addr: true      , port: false }, 'eth0/10.0.0.1' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: '53' },
              { name:  true , addr: false     , port: true }, 'eth0@53' ],

            [ { name: 'eth0', addr: '10.0.0.1', port: '53' },
              { name: false , addr: true      , port: true }, '10.0.0.1@53' ]
        ]
        tests.each do |input, options, output|
            expect(render_interface(input, **options)).to eq output
        end
    end
end

RSpec.describe 'nics_to_addrs' do
    it 'should map nics to addrs' do
        clear_env

        ENV['ETH0_IP'] = '10.0.1.1'
        ENV['ETH1_IP'] = '172.16.1.1'
        ENV['ETH2_IP'] = '172.18.1.1'
        ENV['ETH3_IP'] = '172.18.1.1'

        tests = [
            [ %w[eth0], { 'eth0' => %w[10.0.1.1] } ],

            [ %w[eth1 eth2 eth3], { 'eth1' => %w[172.16.1.1],
                                    'eth2' => %w[172.18.1.1],
                                    'eth3' => %w[172.18.1.1] } ]
        ]
        tests.each do |input, output|
            expect(nics_to_addrs(input)).to eq output
        end
    end
end

RSpec.describe 'addrs_to_nics' do
    it 'should map addrs to nics' do
        clear_env

        ENV['ETH0_IP'] = '10.0.1.1'
        ENV['ETH1_IP'] = '172.16.1.1'
        ENV['ETH2_IP'] = '172.18.1.1'
        ENV['ETH3_IP'] = '172.18.1.1'

        tests = [
            [ %w[eth0], { '10.0.1.1' => %w[eth0] } ],

            [ %w[eth1 eth2 eth3], { '172.16.1.1' => %w[eth1],
                                    '172.18.1.1' => %w[eth2 eth3] } ]
        ]
        tests.each do |input, output|
            expect(addrs_to_nics(input)).to eq output
        end
    end

    it 'should map addrs to nics (:noip)' do
        clear_env

        ENV['ETH0_IP'] = ''
        ENV['ETH1_IP'] = '172.16.1.1'
        ENV['ETH2_IP'] = ''
        ENV['ETH3_IP'] = '172.24.1.1'

        tests = [
            [ %w[eth0 eth1], { '172.16.1.1' => %w[eth1] } ],

            [ %w[eth0 eth1 eth2 eth3], { '172.16.1.1' => %w[eth1],
                                         '172.24.1.1' => %w[eth3] } ]
        ]
        tests.each do |input, output|
            expect(addrs_to_nics(input)).to eq output
        end
    end
end

RSpec.describe 'addrs_to_subnets' do
    it 'should extract subnets' do
        clear_env

        ENV['ETH0_IP'] = '10.0.1.1'
        ENV['ETH0_MASK'] = '255.255.255.255'
        ENV['ETH1_IP'] = '172.16.1.1'
        ENV['ETH1_MASK'] = '255.255.0.0'
        ENV['ETH2_IP'] = '172.18.1.1'
        ENV['ETH2_MASK'] = '255.255.255.0'

        tests = [
            [ %w[eth0], { '10.0.1.1/32' => '10.0.1.1/32' } ],

            [ %w[eth1 eth2], { '172.16.1.1/16' => '172.16.0.0/16',
                               '172.18.1.1/24' => '172.18.1.0/24' } ]
        ]
        tests.each do |input, output|
            expect(addrs_to_subnets(input)).to eq output
        end
    end
end

RSpec.describe 'vips_to_subnets' do
    it 'should extract subnets' do
        clear_env

        ENV['ETH0_MASK'] = '255.255.255.0'

        tests = [
            [ [ 'eth0', 'eth1' ],

              { 'eth0' => { 'ONEAPP_VROUTER_ETH0_VIP0'=> '1.2.3.4',
                            'ONEAPP_VROUTER_ETH0_VIP1'=> '2.3.4.5/16' },
                'eth1' => { 'ONEAPP_VROUTER_ETH1_VIP0'=> '6.7.8.9' } },

              { '1.2.3.4/24' => '1.2.3.0/24',
                '2.3.4.5/16' => '2.3.0.0/16',
                '6.7.8.9/32' => '6.7.8.9/32' } ]
        ]
        tests.each do |nics, vips, output|
            expect(vips_to_subnets(nics, vips)).to eq output
        end
    end
end

RSpec.describe 'subnets_to_ranges' do
    it 'should convert subnets to ranges' do
        tests = [
            [ [ '172.16.0.0/16', '172.18.1.0/24' ],
              { '172.16.0.0/16' => '172.16.0.2-172.16.255.254',
                '172.18.1.0/24' => '172.18.1.2-172.18.1.254' } ],

            [ [ '2001:db8:1:0::/64', '2001:db8:1:1::/64' ],
              { '2001:db8:1:0::/64' => '2001:db8:1::2-2001:db8:1:0:ffff:ffff:ffff:fffe',
                '2001:db8:1:1::/64' => '2001:db8:1:1::2-2001:db8:1:1:ffff:ffff:ffff:fffe' } ]
        ]
        tests.each do |input, output|
            expect(subnets_to_ranges(input)).to eq output
        end
    end
end

RSpec.describe 'get_service_vms' do
    it 'should list all available vms (oneflow)' do
        allow(self).to receive(:onegate_service_show).and_return(JSON.parse(<<~'SERVICE_SHOW'))
            {
              "SERVICE": {
                "name": "asd",
                "id": "23",
                "state": 1,
                "roles": [
                  {
                    "name": "server",
                    "cardinality": 2,
                    "state": 1,
                    "nodes": [
                      {
                        "deploy_id": 435,
                        "running": null,
                        "vm_info": {
                          "VM": {
                            "ID": "435",
                            "UID": "0",
                            "GID": "0",
                            "UNAME": "oneadmin",
                            "GNAME": "oneadmin",
                            "NAME": "server_0_(service_23)"
                          }
                        }
                      },
                      {
                        "deploy_id": 436,
                        "running": null,
                        "vm_info": {
                          "VM": {
                            "ID": "436",
                            "UID": "0",
                            "GID": "0",
                            "UNAME": "oneadmin",
                            "GNAME": "oneadmin",
                            "NAME": "server_1_(service_23)"
                          }
                        }
                      }
                    ]
                  }
                ]
              }
            }
        SERVICE_SHOW
        (vms ||= []) << JSON.parse(<<~'VM0_SHOW')
            {
              "VM": {
                "NAME": "server_0_(service_23)",
                "ID": "435",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "HOT_RESIZE": {
                    "CPU_HOT_ADD_ENABLED": "NO",
                    "MEMORY_HOT_ADD_ENABLED": "NO"
                  },
                  "LOGO": "images/logos/linux.png",
                  "LXD_SECURITY_PRIVILEGED": "true",
                  "MEMORY_UNIT_COST": "MB",
                  "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB0_PORT": "5432",
                  "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.202",
                  "ONEGATE_HAPROXY_LB0_SERVER_PORT": "2345",
                  "ROLE_NAME": "server",
                  "SERVICE_ID": "23"
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "10.2.11.202",
                      "MAC": "02:00:0a:02:0b:ca",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    },
                    {
                      "IP": "172.20.0.122",
                      "MAC": "02:00:ac:14:00:7a",
                      "NAME": "_NIC1",
                      "NETWORK": "private"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            }
        VM0_SHOW
        (vms ||= []) << JSON.parse(<<~'VM1_SHOW')
            {
              "VM": {
                "NAME": "server_1_(service_23)",
                "ID": "436",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "HOT_RESIZE": {
                    "CPU_HOT_ADD_ENABLED": "NO",
                    "MEMORY_HOT_ADD_ENABLED": "NO"
                  },
                  "LOGO": "images/logos/linux.png",
                  "LXD_SECURITY_PRIVILEGED": "true",
                  "MEMORY_UNIT_COST": "MB",
                  "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB0_PORT": "5432",
                  "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.203",
                  "ONEGATE_HAPROXY_LB0_SERVER_PORT": "2345",
                  "ROLE_NAME": "server",
                  "SERVICE_ID": "23"
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "10.2.11.203",
                      "MAC": "02:00:0a:02:0b:cb",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    },
                    {
                      "IP": "172.20.0.123",
                      "MAC": "02:00:ac:14:00:7b",
                      "NAME": "_NIC1",
                      "NETWORK": "private"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            }
        VM1_SHOW

        allow(self).to receive(:onegate_vm_show).and_return(*vms)

        expect(get_service_vms).to eq vms
    end
end

RSpec.describe 'get_vrouter_vnets' do
    it 'should recursively resolve all viable vnets' do
        allow(self).to receive(:onegate_vrouter_show).and_return(JSON.parse(<<~'VROUTER_SHOW'))
            {
              "VROUTER": {
                "NAME": "vrouter",
                "ID": "12",
                "VMS": {
                  "ID": [ "115" ]
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "NETWORK": "service",
                      "NETWORK_ID": "0",
                      "NIC_ID": "0"
                    },
                    {
                      "NETWORK": "private",
                      "NETWORK_ID": "1",
                      "NIC_ID": "1"
                    }
                  ],
                  "TEMPLATE_ID": "74"
                }
              }
            }
        VROUTER_SHOW

        (vnets ||= []) << JSON.parse(<<~'SERVICE_VNET_SHOW')
            {
              "VNET": {
                "ID": "0",
                "NAME": "service",
                "USED_LEASES": "4",
                "VROUTERS": {
                  "ID": [ "12" ]
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
                      "USED_LEASES": "4",
                      "LEASES": {
                        "LEASE": [
                          { "IP": "10.2.11.200", "MAC": "02:00:0a:02:0b:c8", "VM": "110", "NIC_NAME": "NIC0" },
                          { "IP": "10.2.11.201", "MAC": "02:00:0a:02:0b:c9", "VM": "111", "NIC_NAME": "NIC0" },
                          {
                            "IP": "10.2.11.202",
                            "MAC": "02:00:0a:02:0b:ca",
                            "VM": "113",
                            "PARENT": "NIC0",
                            "PARENT_NETWORK_ID": "40",
                            "EXTERNAL": true,
                            "NIC_NAME": "NIC0_ALIAS1"
                          },
                          { "IP": "10.2.11.204", "MAC": "02:00:0a:02:0b:cc", "VM": "115", "NIC_NAME": "NIC0" }
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
        SERVICE_VNET_SHOW
        (vnets ||= []) << JSON.parse(<<~'PRIVATE_VNET_SHOW')
            {
              "VNET": {
                "ID": "1",
                "NAME": "private",
                "USED_LEASES": "21",
                "VROUTERS": {
                  "ID": [ "12" ]
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
                      "USED_LEASES": "21",
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
                          { "IP": "172.20.0.121", "MAC": "02:00:ac:14:00:79", "VM": "115", "NIC_NAME": "NIC1" }
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
        PRIVATE_VNET_SHOW
        (vnets ||= []) << JSON.parse(<<~'RESERVATION_VNET_SHOW')
            {
              "VNET": {
                "ID": "40",
                "NAME": "reservation",
                "USED_LEASES": "2",
                "VROUTERS": {
                  "ID": []
                },
                "PARENT_NETWORK_ID": "1",
                "AR_POOL": {
                  "AR": [
                    {
                      "AR_ID": "0",
                      "IP": "172.20.0.100",
                      "MAC": "02:00:ac:14:00:64",
                      "PARENT_NETWORK_AR_ID": "0",
                      "SIZE": "20",
                      "TYPE": "IP4",
                      "MAC_END": "02:00:ac:14:00:77",
                      "IP_END": "172.20.0.119",
                      "USED_LEASES": "2",
                      "LEASES": {
                        "LEASE": [
                          { "IP": "172.20.0.100", "MAC": "02:00:ac:14:00:64", "VM": "112", "NIC_NAME": "NIC0" },
                          { "IP": "172.20.0.101", "MAC": "02:00:ac:14:00:65", "VM": "113", "NIC_NAME": "NIC0" }
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
        RESERVATION_VNET_SHOW

        allow(self).to receive(:onegate_vnet_show).and_return(*vnets)

        expect(get_vrouter_vnets).to eq vnets
    end
end

RSpec.describe 'backends.from_env' do
    it 'should correctly extract backends from env vars' do
        clear_env

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB0_PORT'] = '6969'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = 'asd0'
        ENV['ONEAPP_VNF_LB0_SERVER0_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_SERVER0_WEIGHT'] = '1'

        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = 'asd1'
        ENV['ONEAPP_VNF_LB0_SERVER1_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_SERVER1_WEIGHT'] = '2'

        ENV['ONEAPP_VNF_LB0_SERVER2_HOST'] = 'asd2'
        ENV['ONEAPP_VNF_LB0_SERVER2_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_SERVER2_WEIGHT'] = '3'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB1_PORT'] = '8686'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'

        ENV['ONEAPP_VNF_LB1_SERVER0_HOST'] = 'asd0'
        ENV['ONEAPP_VNF_LB1_SERVER0_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_SERVER0_WEIGHT'] = '1'

        ENV['ONEAPP_VNF_LB1_SERVER1_HOST'] = 'asd1'
        ENV['ONEAPP_VNF_LB1_SERVER1_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_SERVER1_WEIGHT'] = '2'

        expect(backends.from_env).to eq ({
            by_endpoint: {
                [ 0, '10.2.11.86', '6969' ] =>
                    { [ 'asd0', '1234' ] => { host: 'asd0', port: '1234', weight: '1' },
                      [ 'asd1', '1234' ] => { host: 'asd1', port: '1234', weight: '2' },
                      [ 'asd2', '1234' ] => { host: 'asd2', port: '1234', weight: '3' } },

                [ 1, '10.2.11.86', '8686' ] =>
                    { [ 'asd0', '4321' ] => { host: 'asd0', port: '4321', weight: '1' },
                      [ 'asd1', '4321' ] => { host: 'asd1', port: '4321', weight: '2' } } },

            options: { 0 => { ip: '10.2.11.86', port: '6969', protocol: 'TCP' },
                       1 => { ip: '10.2.11.86', port: '8686', protocol: 'TCP' } }
        })
    end
end

RSpec.describe 'backends.from_vnets' do
    it 'should correctly extract backends from vnets' do
        (vnets ||= []) << JSON.parse(<<~'VNET0')
            {
              "VNET": {
                "ID": "0",
                "AR_POOL": {
                  "AR": [
                    {
                      "AR_ID": "0",
                      "LEASES": {
                        "LEASE": [
                          {
                            "IP": "10.2.11.202",
                            "MAC": "02:00:0a:02:0b:ca",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_LB0_IP": "10.2.11.86",
                            "ONEGATE_LB0_PORT": "6969",
                            "ONEGATE_LB0_SERVER_HOST": "asd2",
                            "ONEGATE_LB0_SERVER_PORT": "1234",
                            "ONEGATE_LB0_SERVER_WEIGHT": "3"
                          },
                          {
                            "IP": "10.2.11.201",
                            "MAC": "02:00:0a:02:0b:c9",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_LB0_IP": "10.2.11.86",
                            "ONEGATE_LB0_PORT": "6969",
                            "ONEGATE_LB0_SERVER_HOST": "asd1",
                            "ONEGATE_LB0_SERVER_PORT": "1234",
                            "ONEGATE_LB0_SERVER_WEIGHT": "2",

                            "ONEGATE_LB1_IP": "10.2.11.86",
                            "ONEGATE_LB1_PORT": "8686",
                            "ONEGATE_LB1_SERVER_HOST": "asd1",
                            "ONEGATE_LB1_SERVER_PORT": "4321",
                            "ONEGATE_LB1_SERVER_WEIGHT": "2"
                          },
                          {
                            "IP": "10.2.11.200",
                            "MAC": "02:00:0a:02:0b:c8",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_LB0_IP": "10.2.11.86",
                            "ONEGATE_LB0_PORT": "6969",
                            "ONEGATE_LB0_SERVER_HOST": "asd0",
                            "ONEGATE_LB0_SERVER_PORT": "1234",
                            "ONEGATE_LB0_SERVER_WEIGHT": "1",

                            "ONEGATE_LB1_IP": "10.2.11.86",
                            "ONEGATE_LB1_PORT": "8686",
                            "ONEGATE_LB1_SERVER_HOST": "asd0",
                            "ONEGATE_LB1_SERVER_PORT": "4321",
                            "ONEGATE_LB1_SERVER_WEIGHT": "1"
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            }
        VNET0
        expect(backends.from_vnets(vnets)).to eq ({
            by_endpoint: {
                [ 0, '10.2.11.86', '6969' ] =>
                    { [ 'asd0', '1234' ] => { host: 'asd0', port: '1234', weight: '1' },
                      [ 'asd1', '1234' ] => { host: 'asd1', port: '1234', weight: '2' },
                      [ 'asd2', '1234' ] => { host: 'asd2', port: '1234', weight: '3' } },

                [ 1, '10.2.11.86', '8686' ] =>
                    { [ 'asd0', '4321' ] => { host: 'asd0', port: '4321', weight: '1' },
                      [ 'asd1', '4321' ] => { host: 'asd1', port: '4321', weight: '2' } } },

            options: { 0 => { ip: '10.2.11.86', port: '6969' },
                       1 => { ip: '10.2.11.86', port: '8686' } }
        })
    end
end

RSpec.describe 'backends.from_vms' do
    it 'should correctly extract backends from vms (oneflow)' do
        (vms ||= []) << JSON.parse(<<~'VM0')
            {
              "VM": {
                "NAME": "server_0_(service_23)",
                "ID": "435",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "HOT_RESIZE": {
                    "CPU_HOT_ADD_ENABLED": "NO",
                    "MEMORY_HOT_ADD_ENABLED": "NO"
                  },
                  "LOGO": "images/logos/linux.png",
                  "LXD_SECURITY_PRIVILEGED": "true",
                  "MEMORY_UNIT_COST": "MB",
                  "ONEGATE_LB0_IP": "10.2.11.86",
                  "ONEGATE_LB0_PORT": "5432",
                  "ONEGATE_LB0_SERVER_HOST": "10.2.11.202",
                  "ONEGATE_LB0_SERVER_PORT": "2345",
                  "ROLE_NAME": "server",
                  "SERVICE_ID": "23"
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "10.2.11.202",
                      "MAC": "02:00:0a:02:0b:ca",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    },
                    {
                      "IP": "172.20.0.122",
                      "MAC": "02:00:ac:14:00:7a",
                      "NAME": "_NIC1",
                      "NETWORK": "private"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            }
        VM0
        (vms ||= []) << JSON.parse(<<~'VM1')
            {
              "VM": {
                "NAME": "server_1_(service_23)",
                "ID": "436",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "HOT_RESIZE": {
                    "CPU_HOT_ADD_ENABLED": "NO",
                    "MEMORY_HOT_ADD_ENABLED": "NO"
                  },
                  "LOGO": "images/logos/linux.png",
                  "LXD_SECURITY_PRIVILEGED": "true",
                  "MEMORY_UNIT_COST": "MB",
                  "ONEGATE_LB0_IP": "10.2.11.86",
                  "ONEGATE_LB0_PORT": "5432",
                  "ONEGATE_LB0_SERVER_HOST": "10.2.11.203",
                  "ONEGATE_LB0_SERVER_PORT": "2345",
                  "ROLE_NAME": "server",
                  "SERVICE_ID": "23"
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "10.2.11.203",
                      "MAC": "02:00:0a:02:0b:cb",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    },
                    {
                      "IP": "172.20.0.123",
                      "MAC": "02:00:ac:14:00:7b",
                      "NAME": "_NIC1",
                      "NETWORK": "private"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            }
        VM1

        expect(backends.from_vms(vms)).to eq ({
            by_endpoint: {
                [ 0, '10.2.11.86', '5432'] =>
                    { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' },
                      [ '10.2.11.203', '2345' ] => { host: '10.2.11.203', port: '2345' } } },

            options: { 0 => { ip: '10.2.11.86', port: '5432' } }
        })
    end
end

RSpec.describe 'backends.combine' do
    it 'should filter + merge dynamic endpoints' do
        tests = [
            [ # Add dynamic backend.
                { by_endpoint: {},
                  options:     { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } }
            ],
            [ # No change (LB0 IP / PORT mismatch).
                { by_endpoint: {},
                  options:     { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '1111'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '1111' } } },

                { by_endpoint: {},
                  options:     { 0 => { ip: '10.2.11.86', port: '5432' } } }
            ],
            [ # No change (dynamic is a subset of static).
                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } },
                    [ 1, '10.2.11.86', '1111'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' },
                             1 => { ip: '10.2.11.86', port: '1111' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } },
                    [ 1, '10.2.11.86', '1111'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' },
                             1 => { ip: '10.2.11.86', port: '1111' } } },
            ],
            [ # No change (LB1 is undefined).
                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } },
                    [ 1, '10.2.11.86', '1111'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' },
                             1 => { ip: '10.2.11.86', port: '1111' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } }
            ],
            [ # Add second backend.
                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '1111' ] => { host: '10.2.11.202', port: '1111' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } },

                { by_endpoint: {
                    [ 0, '10.2.11.86', '5432'] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' },
                          [ '10.2.11.202', '1111' ] => { host: '10.2.11.202', port: '1111' } } },
                  options: { 0 => { ip: '10.2.11.86', port: '5432' } } }
            ]
        ]
        tests.each do |static, dynamic, output|
            expect(backends.combine(static, dynamic)).to eq output
        end
    end
end

RSpec.describe 'backends.resolve' do
    it 'should replace (v)ip placeholders with existing (v)ip addresses' do
        tests = [
            [
                # "addrs"
                { 'eth0' => { 'ETH0_IP0' => '1.2.3.4/24' },
                  'eth1' => { 'ETH1_IP0' => '2.3.4.5/24' } },

                # "vips"
                { 'eth0' => { 'ETH0_VIP0' => '1.2.3.254/24',
                              'ETH0_VIP1' => '2.3.4.254/24' } },

                # "endpoints"
                { 'eth0' => { 'ETH0_EP0' => '1.2.3.254/24',
                              'ETH0_EP1' => '2.3.4.254/24' },
                  'eth1' => { 'ETH1_EP0' => '2.3.4.5/24' } },

                { by_endpoint: {
                    [ 0, '<ETH0_VIP0>', '5432' ] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } },

                    [ 1, '<ETH1_EP0>', '1111' ] =>
                        { [ '10.2.11.203', '2222' ] => { host: '10.2.11.203', port: '2222' } },

                    [ 2, '5.6.7.8', '3333' ] =>
                        { [ '10.2.11.204', '4444' ] => { host: '10.2.11.204', port: '4444' } } },

                  options: { 0 => { ip: '<ETH0_VIP0>', port: '5432' },
                             1 => { ip: '<ETH1_EP0>', port: '1111' },
                             2 => { ip: '5.6.7.8', port: '3333' } } },

                { by_endpoint: {
                    [ 0, '1.2.3.254', '5432' ] =>
                        { [ '10.2.11.202', '2345' ] => { host: '10.2.11.202', port: '2345' } },

                    [ 1, '2.3.4.5', '1111' ] =>
                        { [ '10.2.11.203', '2222' ] => { host: '10.2.11.203', port: '2222' } },

                    [ 2, '5.6.7.8', '3333' ] =>
                        { [ '10.2.11.204', '4444' ] => { host: '10.2.11.204', port: '4444' } } },

                  options: { 0 => { ip: '1.2.3.254', port: '5432' },
                             1 => { ip: '2.3.4.5', port: '1111' },
                             2 => { ip: '5.6.7.8', port: '3333' } } }
            ]
        ]
        tests.each do |a, v, e, b, output|
            expect(backends.resolve(b, a, v, e)).to eq output
        end
    end
end
