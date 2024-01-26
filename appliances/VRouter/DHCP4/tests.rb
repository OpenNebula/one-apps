# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide and parse all env vars' do
        clear_env

        ENV['ONEAPP_VNF_DHCP4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_AUTHORITATIVE'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_MAC2IP_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX'] = '02:00'

        ENV['ONEAPP_VNF_DHCP4_LEASE_TIME'] = '3600'

        ENV['ONEAPP_VNF_DHCP4_GATEWAY'] = '1.2.3.4'
        ENV['ONEAPP_VNF_DHCP4_DNS'] = '1.1.1.1'

        ENV['ONEAPP_VNF_DHCP4_INTERFACES'] = 'eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_ETH2'] = '30.0.0.0/8:30.40.50.64-30.40.50.68'
        ENV['ONEAPP_VNF_DHCP4_ETH2_GATEWAY'] = '30.40.50.1'
        ENV['ONEAPP_VNF_DHCP4_ETH2_DNS'] = '8.8.8.8'

        ENV['ONEAPP_VNF_DHCP4_ETH3_GATEWAY'] = '40.50.60.1'
        ENV['ONEAPP_VNF_DHCP4_ETH3_DNS'] = '8.8.4.4'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        ENV['ETH1_ALIAS0_IP'] = '5.6.7.8' # ignored (unsupported)
        ENV['ETH1_ALIAS0_MASK'] = '255.255.255.0' # ignored (unsupported)

        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        ENV['ETH3_IP'] = '40.50.60.70'
        ENV['ETH3_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '1.2.3.4' # ignored (not in the subnet)

        load './main.rb'; include Service::DHCP4

        allow(Service::DHCP4).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 },
            { 'mtu' => 3333 }
        )

        clear_vars Service::DHCP4

        expect(Service::DHCP4.parse_env).to eq ({
            'eth1' => [ { address: '20.30.40.50',
                          dns:     '1.1.1.1',
                          gateway: '1.2.3.4',
                          mtu:     1111,
                          range:   '20.30.0.2-20.30.255.254',
                          subnet:  '20.30.0.0/16',
                          vips:    %w[20.30.40.55] } ],

            'eth2' => [ { address: '30.40.50.60',
                          dns:     '8.8.8.8',
                          gateway: '30.40.50.1',
                          mtu:     2222,
                          range:   '30.40.50.64-30.40.50.68',
                          subnet:  '30.0.0.0/8',
                          vips:    %w[] } ],

            'eth3' => [ { address: '40.50.60.70',
                          dns:     '8.8.4.4',
                          gateway: '40.50.60.1',
                          mtu:     3333,
                          range:   '40.50.60.2-40.50.60.254',
                          subnet:  '40.50.60.0/24',
                          vips:    %w[] } ]
        })

        output = <<~'KEA_DHCP4_CONF'
            {
              "Dhcp4": {
                "interfaces-config": {
                  "interfaces": [
                    "eth1",
                    "eth2",
                    "eth3"
                  ]
                },
                "authoritative": true,
                "option-data": [

                ],
                "subnet4": [
                  {
                    "subnet": "20.30.0.0/16",
                    "pools": [
                      {
                        "pool": "20.30.0.2-20.30.255.254"
                      }
                    ],
                    "option-data": [
                      {
                        "name": "routers",
                        "data": "1.2.3.4"
                      },
                      {
                        "name": "domain-name-servers",
                        "data": "1.1.1.1"
                      },
                      {
                        "name": "interface-mtu",
                        "data": "3333"
                      }
                    ],
                    "reservations": [
                      {
                        "flex-id": "'DO-NOT-LEASE-20.30.40.50'",
                        "ip-address": "20.30.40.50"
                      },
                      {
                        "flex-id": "'DO-NOT-LEASE-20.30.40.55'",
                        "ip-address": "20.30.40.55"
                      }
                    ],
                    "reservation-mode": "all"
                  },
                  {
                    "subnet": "30.0.0.0/8",
                    "pools": [
                      {
                        "pool": "30.40.50.64-30.40.50.68"
                      }
                    ],
                    "option-data": [
                      {
                        "name": "routers",
                        "data": "30.40.50.1"
                      },
                      {
                        "name": "domain-name-servers",
                        "data": "8.8.8.8"
                      },
                      {
                        "name": "interface-mtu",
                        "data": "3333"
                      }
                    ],
                    "reservations": [
                      {
                        "flex-id": "'DO-NOT-LEASE-30.40.50.60'",
                        "ip-address": "30.40.50.60"
                      }
                    ],
                    "reservation-mode": "all"
                  },
                  {
                    "subnet": "40.50.60.0/24",
                    "pools": [
                      {
                        "pool": "40.50.60.2-40.50.60.254"
                      }
                    ],
                    "option-data": [
                      {
                        "name": "routers",
                        "data": "40.50.60.1"
                      },
                      {
                        "name": "domain-name-servers",
                        "data": "8.8.4.4"
                      },
                      {
                        "name": "interface-mtu",
                        "data": "3333"
                      }
                    ],
                    "reservations": [
                      {
                        "flex-id": "'DO-NOT-LEASE-40.50.60.70'",
                        "ip-address": "40.50.60.70"
                      }
                    ],
                    "reservation-mode": "all"
                  }
                ],
                "lease-database": {
                  "type": "memfile",
                  "persist": true,
                  "lfc-interval": 7200
                },
                "sanity-checks": {
                  "lease-checks": "fix-del"
                },
                "valid-lifetime": 3600,
                "calculate-tee-times": true,
                "loggers": [
                  {
                    "name": "kea-dhcp4",
                    "output_options": [
                      {
                        "output": "/var/log/kea/kea-dhcp4.log"
                      }
                    ],
                    "severity": "INFO",
                    "debuglevel": 0
                  }
                ],
                "hooks-libraries": [
                  {
                    "library": "/usr/lib/kea/hooks/libkea-onelease-dhcp4.so",
                    "parameters": {
                      "enabled": true,
                      "byte-prefix": "02:00",
                      "logger-name": "onelease-dhcp4",
                      "debug": false,
                      "debug-logfile": "/var/log/kea/onelease-dhcp4-debug.log"
                    }
                  }
                ]
              }
            }
        KEA_DHCP4_CONF
        Dir.mktmpdir do |dir|
            Service::DHCP4.configure basedir: dir, owner: nil, group: nil
            result = File.read "#{dir}/kea-dhcp4.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should interpolate GW and DNS values' do
        clear_env

        ENV['ONEAPP_VNF_DHCP4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_INTERFACES'] = 'eth0 eth1'

        ENV['ONEAPP_VNF_DHCP4_ETH0_GATEWAY'] = '<ETH0_EP0>'
        ENV['ONEAPP_VNF_DHCP4_ETH0_DNS'] = '<ETH0_EP0>'

        ENV['ONEAPP_VNF_DHCP4_ETH1_GATEWAY'] = '<ETH1_VIP0>'
        ENV['ONEAPP_VNF_DHCP4_ETH1_DNS'] = '<ETH1_VIP1>'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '10.20.30.45'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '20.30.40.110'

        load './main.rb'; include Service::DHCP4

        allow(Service::DHCP4).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 }
        )

        clear_vars Service::DHCP4

        expect(Service::DHCP4.parse_env).to eq ({
            'eth0' => [ { address: '10.20.30.40',
                          dns:     '10.20.30.45',
                          gateway: '10.20.30.45',
                          mtu:     1111,
                          range:   '10.20.30.2-10.20.30.254',
                          subnet:  '10.20.30.0/24',
                          vips:    %w[10.20.30.45] } ],

            'eth1' => [ { address: '20.30.40.50',
                          dns:     '20.30.40.110',
                          gateway: '20.30.40.55',
                          mtu:     2222,
                          range:   '20.30.40.2-20.30.40.254',
                          subnet:  '20.30.40.0/24',
                          vips:    %w[20.30.40.55 20.30.40.110] } ]
        })
    end
end
