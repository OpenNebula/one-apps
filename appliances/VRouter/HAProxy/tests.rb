# frozen_string_literal: true

require 'json'
require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide and parse all env vars (static)' do
        clear_env

        ENV['ONEAPP_VNF_HAPROXY_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_HAPROXY_REFRESH_RATE'] = ''

        ENV['ONEAPP_VNF_HAPROXY_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_HAPROXY_LB0_PORT'] = '1234'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_PORT'] = '12345'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_HOST'] = '10.2.100.20'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_PORT'] = '12345'

        ENV['ONEAPP_VNF_HAPROXY_LB1_IP'] = '10.2.20.69'
        ENV['ONEAPP_VNF_HAPROXY_LB1_PORT'] = '4321'

        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER0_HOST'] = '10.2.200.10'
        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER0_PORT'] = '54321'

        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER1_HOST'] = '10.2.200.20'
        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER1_PORT'] = '54321'

        load './main.rb'; include Service::HAProxy

        expect(Service::HAProxy::ONEAPP_VNF_HAPROXY_ENABLED).to be true
        expect(Service::HAProxy::ONEAPP_VNF_HAPROXY_REFRESH_RATE).to eq '30'

        Service::HAProxy.const_set :VROUTER_ID, '86'

        allow(Service::HAProxy).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])

        expect(Service::HAProxy.extract_backends).to eq({
            by_endpoint: {
                [ 0, '10.2.10.69', '1234' ] =>
                    { [ '10.2.100.10', '12345' ] => { host: '10.2.100.10', port: '12345' },
                      [ '10.2.100.20', '12345' ] => { host: '10.2.100.20', port: '12345' } },

                [ 1, '10.2.20.69', '4321' ] =>
                    { [ '10.2.200.10', '54321' ] => { host: '10.2.200.10', port: '54321' },
                      [ '10.2.200.20', '54321' ] => { host: '10.2.200.20', port: '54321' } } },

            options: { 0 => { ip: '10.2.10.69', port: '1234' },
                       1 => { ip: '10.2.20.69', port: '4321' } }
        })
    end

    it 'should render servers.cfg (static)' do
        clear_env

        ENV['ONEAPP_VNF_HAPROXY_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_HAPROXY_REFRESH_RATE'] = ''

        ENV['ONEAPP_VNF_HAPROXY_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_HAPROXY_LB0_PORT'] = '1234'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_PORT'] = '12345'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_HOST'] = '10.2.100.20'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_PORT'] = '12345'

        ENV['ONEAPP_VNF_HAPROXY_LB1_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_HAPROXY_LB1_PORT'] = '4321'

        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER0_HOST'] = '10.2.200.10'
        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER0_PORT'] = '54321'

        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER1_HOST'] = '10.2.200.20'
        ENV['ONEAPP_VNF_HAPROXY_LB1_SERVER1_PORT'] = '54321'

        load './main.rb'; include Service::HAProxy

        Service::HAProxy.const_set :VROUTER_ID, '86'

        allow(Service::HAProxy).to receive(:toggle).and_return(nil)
        allow(Service::HAProxy).to receive(:sleep).and_return(nil)
        allow(Service::HAProxy).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::HAProxy).to receive(:addrs_to_nics).and_return({
            '10.2.10.69' => ['eth0']
        })

        clear_vars Service::HAProxy

        output = <<~STATIC
            frontend lb0_1234
                mode tcp
                bind 10.2.10.69:1234
                default_backend lb0_1234

            backend lb0_1234
                mode tcp
                balance roundrobin
                option tcp-check
                server lb0_10.2.100.10_12345 10.2.100.10:12345 check observe layer4 error-limit 50 on-error mark-down
                server lb0_10.2.100.20_12345 10.2.100.20:12345 check observe layer4 error-limit 50 on-error mark-down

            frontend lb1_4321
                mode tcp
                bind 10.2.10.69:4321
                default_backend lb1_4321

            backend lb1_4321
                mode tcp
                balance roundrobin
                option tcp-check
                server lb1_10.2.200.10_54321 10.2.200.10:54321 check observe layer4 error-limit 50 on-error mark-down
                server lb1_10.2.200.20_54321 10.2.200.20:54321 check observe layer4 error-limit 50 on-error mark-down
        STATIC

        Dir.mktmpdir do |dir|
            Service::HAProxy.execute basedir: dir
            result = File.read "#{dir}/servers.cfg"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render servers.cfg (dynamic)' do
        clear_env

        ENV['ONEAPP_VNF_HAPROXY_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_HAPROXY_REFRESH_RATE'] = ''

        ENV['ONEAPP_VNF_HAPROXY_LB0_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_HAPROXY_LB0_PORT'] = '6969'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_HOST'] = '10.2.11.200'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER0_PORT'] = '1234'

        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_HOST'] = '10.2.11.201'
        ENV['ONEAPP_VNF_HAPROXY_LB0_SERVER1_PORT'] = '1234'

        ENV['ONEAPP_VNF_HAPROXY_LB1_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_HAPROXY_LB1_PORT'] = '8686'

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

                            "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                            "ONEGATE_HAPROXY_LB0_PORT": "6969",
                            "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.202",
                            "ONEGATE_HAPROXY_LB0_SERVER_PORT": "1234",
                            "ONEGATE_HAPROXY_LB0_SERVER_WEIGHT": "1"
                          },
                          {
                            "IP": "10.2.11.201",
                            "MAC": "02:00:0a:02:0b:c9",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                            "ONEGATE_HAPROXY_LB0_PORT": "6969",
                            "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.201",
                            "ONEGATE_HAPROXY_LB0_SERVER_PORT": "1234",
                            "ONEGATE_HAPROXY_LB0_SERVER_WEIGHT": "1",

                            "ONEGATE_HAPROXY_LB1_ID": "NOT-86",
                            "ONEGATE_HAPROXY_LB1_IP": "10.2.11.86",
                            "ONEGATE_HAPROXY_LB1_PORT": "8686",
                            "ONEGATE_HAPROXY_LB1_SERVER_HOST": "10.2.11.201",
                            "ONEGATE_HAPROXY_LB1_SERVER_PORT": "4321",
                            "ONEGATE_HAPROXY_LB1_SERVER_WEIGHT": "1"
                          },
                          {
                            "IP": "10.2.11.200",
                            "MAC": "02:00:0a:02:0b:c8",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                            "ONEGATE_HAPROXY_LB0_PORT": "6969",
                            "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.200",
                            "ONEGATE_HAPROXY_LB0_SERVER_PORT": "1234",
                            "ONEGATE_HAPROXY_LB0_SERVER_WEIGHT": "1",

                            "ONEGATE_HAPROXY_LB1_ID": "86",
                            "ONEGATE_HAPROXY_LB1_IP": "10.2.11.86",
                            "ONEGATE_HAPROXY_LB1_PORT": "8686",
                            "ONEGATE_HAPROXY_LB1_SERVER_HOST": "10.2.11.200",
                            "ONEGATE_HAPROXY_LB1_SERVER_PORT": "4321",
                            "ONEGATE_HAPROXY_LB1_SERVER_WEIGHT": "1"
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            }
        VNET0

        load './main.rb'; include Service::HAProxy

        Service::HAProxy.const_set :VROUTER_ID, '86'

        allow(Service::HAProxy).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::HAProxy).to receive(:addrs_to_nics).and_return({
            '10.2.11.86' => ['eth0']
        })

        clear_vars Service::HAProxy

        output = <<~'DYNAMIC'
            frontend lb0_6969
                mode tcp
                bind 10.2.11.86:6969
                default_backend lb0_6969

            backend lb0_6969
                mode tcp
                balance roundrobin
                option tcp-check
                server lb0_10.2.11.200_1234 10.2.11.200:1234 check observe layer4 error-limit 50 on-error mark-down
                server lb0_10.2.11.201_1234 10.2.11.201:1234 check observe layer4 error-limit 50 on-error mark-down
                server lb0_10.2.11.202_1234 10.2.11.202:1234 check observe layer4 error-limit 50 on-error mark-down

            frontend lb1_8686
                mode tcp
                bind 10.2.11.86:8686
                default_backend lb1_8686

            backend lb1_8686
                mode tcp
                balance roundrobin
                option tcp-check
                server lb1_10.2.11.200_4321 10.2.11.200:4321 check observe layer4 error-limit 50 on-error mark-down
        DYNAMIC

        Dir.mktmpdir do |dir|
            haproxy_vars = Service::HAProxy.extract_backends vnets
            Service::HAProxy.render_servers_cfg haproxy_vars, basedir: dir
            result = File.read "#{dir}/servers.cfg"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render servers.cfg (dynamic/OneFlow)' do
        clear_env

        ENV['ONEAPP_VNF_HAPROXY_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_HAPROXY_REFRESH_RATE'] = ''

        ENV['ONEAPP_VNF_HAPROXY_LB0_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_HAPROXY_LB0_PORT'] = '5432'

        ENV['ONEAPP_VNF_HAPROXY_LB1_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_HAPROXY_LB1_PORT'] = '4321'

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

                  "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB0_PORT": "5432",
                  "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.202",
                  "ONEGATE_HAPROXY_LB0_SERVER_PORT": "2345",

                  "ONEGATE_HAPROXY_LB1_ID": "86",
                  "ONEGATE_HAPROXY_LB1_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB1_PORT": "4321",
                  "ONEGATE_HAPROXY_LB1_SERVER_HOST": "10.2.11.202",
                  "ONEGATE_HAPROXY_LB1_SERVER_PORT": "1234",

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

                  "ONEGATE_HAPROXY_LB0_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB0_PORT": "5432",
                  "ONEGATE_HAPROXY_LB0_SERVER_HOST": "10.2.11.203",
                  "ONEGATE_HAPROXY_LB0_SERVER_PORT": "2345",

                  "ONEGATE_HAPROXY_LB1_ID": "123",
                  "ONEGATE_HAPROXY_LB1_IP": "10.2.11.86",
                  "ONEGATE_HAPROXY_LB1_PORT": "4321",
                  "ONEGATE_HAPROXY_LB1_SERVER_HOST": "10.2.11.203",
                  "ONEGATE_HAPROXY_LB1_SERVER_PORT": "1234",

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

        load './main.rb'; include Service::HAProxy

        Service::HAProxy.const_set :VROUTER_ID, nil
        Service::HAProxy.const_set :SERVICE_ID, '123'

        allow(Service::HAProxy).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::HAProxy).to receive(:addrs_to_nics).and_return({
            '10.2.11.86' => ['eth0']
        })

        clear_vars Service::HAProxy

        output = <<~'DYNAMIC'
            frontend lb0_5432
                mode tcp
                bind 10.2.11.86:5432
                default_backend lb0_5432

            backend lb0_5432
                mode tcp
                balance roundrobin
                option tcp-check
                server lb0_10.2.11.202_2345 10.2.11.202:2345 check observe layer4 error-limit 50 on-error mark-down
                server lb0_10.2.11.203_2345 10.2.11.203:2345 check observe layer4 error-limit 50 on-error mark-down

            frontend lb1_4321
                mode tcp
                bind 10.2.11.86:4321
                default_backend lb1_4321

            backend lb1_4321
                mode tcp
                balance roundrobin
                option tcp-check
                server lb1_10.2.11.203_1234 10.2.11.203:1234 check observe layer4 error-limit 50 on-error mark-down
        DYNAMIC

        Dir.mktmpdir do |dir|
            haproxy_vars = Service::HAProxy.extract_backends vms
            Service::HAProxy.render_servers_cfg haproxy_vars, basedir: dir
            result = File.read "#{dir}/servers.cfg"
            expect(result.strip).to eq output.strip
        end
    end
end
