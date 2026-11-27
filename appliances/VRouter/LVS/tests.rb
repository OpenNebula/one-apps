# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_LB') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide defaults (static)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_REFRESH_RATE'] = ''
        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = ''

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_LB0_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_LB0_SERVER0_PORT'] = '12345'

        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = '10.2.100.20'
        ENV['ONEAPP_VNF_LB0_SERVER1_PORT'] = '12345'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.20.69'
        ENV['ONEAPP_VNF_LB1_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'

        ENV['ONEAPP_VNF_LB1_SERVER0_HOST'] = '10.2.200.10'
        ENV['ONEAPP_VNF_LB1_SERVER0_PORT'] = '54321'

        ENV['ONEAPP_VNF_LB1_SERVER1_HOST'] = '10.2.200.20'
        ENV['ONEAPP_VNF_LB1_SERVER1_PORT'] = '54321'

        ENV['ONEAPP_VNF_LB_ONEGATE_API'] = ''

        load './main.rb'; include Service::LVS

        expect(Service::LVS::ONEAPP_VNF_LB_ENABLED).to be true
        expect(Service::LVS::ONEAPP_VNF_LB_REFRESH_RATE).to eq '30'
        expect(Service::LVS::ONEAPP_VNF_LB_FWMARK_OFFSET).to eq '10000'
        expect(Service::LVS::ONEAPP_VNF_LB_ONEGATE_API).to eq 'auto'

        Service::LVS.const_set :VROUTER_ID, '86'

        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])

        expect(Service::LVS.extract_backends).to eq({
            by_endpoint: {
                [ 0, '10.2.10.69', '1234' ] =>
                    { [ '10.2.100.10', '12345' ] => { host: '10.2.100.10', port: '12345' },
                      [ '10.2.100.20', '12345' ] => { host: '10.2.100.20', port: '12345' } },

                [ 1, '10.2.20.69', '4321' ] =>
                    { [ '10.2.200.10', '54321' ] => { host: '10.2.200.10', port: '54321' },
                      [ '10.2.200.20', '54321' ] => { host: '10.2.200.20', port: '54321' } } },

            options: { 0 => { ip: '10.2.10.69', port: '1234', protocol: 'TCP' },
                       1 => { ip: '10.2.20.69', port: '4321', protocol: 'TCP' } }
        })
    end

    it 'should provide and parse all env vars (static)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_REFRESH_RATE'] = '45'
        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = '12345'

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_LB0_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB0_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB0_TIMEOUT'] = '10'
        ENV['ONEAPP_VNF_LB0_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_LB0_SERVER0_PORT'] = '12345'
        ENV['ONEAPP_VNF_LB0_SERVER0_WEIGHT'] = '1'
        ENV['ONEAPP_VNF_LB0_SERVER0_ULIMIT'] = '100'
        ENV['ONEAPP_VNF_LB0_SERVER0_LLIMIT'] = '0'

        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = '10.2.100.20'
        ENV['ONEAPP_VNF_LB0_SERVER1_PORT'] = '12345'
        ENV['ONEAPP_VNF_LB0_SERVER1_WEIGHT'] = '1'
        ENV['ONEAPP_VNF_LB0_SERVER1_ULIMIT'] = '100'
        ENV['ONEAPP_VNF_LB0_SERVER1_LLIMIT'] = '0'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.20.69'
        ENV['ONEAPP_VNF_LB1_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB1_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB1_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB1_SERVER0_HOST'] = '10.2.200.10'
        ENV['ONEAPP_VNF_LB1_SERVER0_PORT'] = '54321'
        ENV['ONEAPP_VNF_LB1_SERVER0_WEIGHT'] = '1'
        ENV['ONEAPP_VNF_LB1_SERVER0_ULIMIT'] = '100'
        ENV['ONEAPP_VNF_LB1_SERVER0_LLIMIT'] = '0'

        ENV['ONEAPP_VNF_LB1_SERVER1_HOST'] = '10.2.200.20'
        ENV['ONEAPP_VNF_LB1_SERVER1_PORT'] = '54321'
        ENV['ONEAPP_VNF_LB1_SERVER1_WEIGHT'] = '1'
        ENV['ONEAPP_VNF_LB1_SERVER1_ULIMIT'] = '100'
        ENV['ONEAPP_VNF_LB1_SERVER1_LLIMIT'] = '0'

        ENV['ONEAPP_VNF_LB_ONEGATE_API'] = 'vrouter'

        load './main.rb'; include Service::LVS

        expect(Service::LVS::ONEAPP_VNF_LB_ENABLED).to be true
        expect(Service::LVS::ONEAPP_VNF_LB_REFRESH_RATE).to eq '45'
        expect(Service::LVS::ONEAPP_VNF_LB_FWMARK_OFFSET).to eq '12345'
        expect(Service::LVS::ONEAPP_VNF_LB_ONEGATE_API).to eq 'vrouter'

        Service::LVS.const_set :VROUTER_ID, '86'

        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])

        expect(Service::LVS.extract_backends).to eq({
            by_endpoint: {
                [ 0, '10.2.10.69', '1234' ] =>
                    { [ '10.2.100.10', '12345' ] => { host: '10.2.100.10', port: '12345', llimit: '0', ulimit: '100', weight: '1' },
                      [ '10.2.100.20', '12345' ] => { host: '10.2.100.20', port: '12345', llimit: '0', ulimit: '100', weight: '1' } },

                [ 1, '10.2.20.69', '4321' ] =>
                    { [ '10.2.200.10', '54321' ] => { host: '10.2.200.10', port: '54321', llimit: '0', ulimit: '100', weight: '1' },
                      [ '10.2.200.20', '54321' ] => { host: '10.2.200.20', port: '54321', llimit: '0', ulimit: '100', weight: '1' } } },

            options: { 0 => { ip: '10.2.10.69', port: '1234', method: 'DR', protocol: 'TCP', scheduler: 'rr' },
                       1 => { ip: '10.2.20.69', port: '4321', method: 'DR', protocol: 'TCP', scheduler: 'rr' } }

        })
    end

    it 'should render lvs.cfg (static)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_REFRESH_RATE'] = ''
        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = ''

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_LB0_PORT'] = '1234'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB0_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB0_TIMEOUT'] = '10'
        ENV['ONEAPP_VNF_LB0_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_LB0_SERVER0_PORT'] = '12345'

        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = '10.2.100.20'
        ENV['ONEAPP_VNF_LB0_SERVER1_PORT'] = '12345'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.20.69'
        ENV['ONEAPP_VNF_LB1_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB1_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB1_TIMEOUT'] = '10'
        ENV['ONEAPP_VNF_LB1_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB1_SERVER0_HOST'] = '10.2.200.10'
        ENV['ONEAPP_VNF_LB1_SERVER0_PORT'] = '54321'

        ENV['ONEAPP_VNF_LB1_SERVER1_HOST'] = '10.2.200.20'
        ENV['ONEAPP_VNF_LB1_SERVER1_PORT'] = '54321'

        load './main.rb'; include Service::LVS

        Service::LVS.const_set :VROUTER_ID, '86'

        allow(Service::LVS).to receive(:toggle).and_return(nil)
        allow(Service::LVS).to receive(:sleep).and_return(nil)
        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::LVS).to receive(:addrs_to_nics).and_return({
            '10.2.10.69' => ['eth0'],
            '10.2.20.69' => ['eth0']
        })

        clear_vars Service::LVS

        output = <<~STATIC
            virtual_server 10.2.10.69 1234 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.100.10 12345 {
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 12345
                    }
                }
                real_server 10.2.100.20 12345 {
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 12345
                    }
                }
            }
            virtual_server 10.2.20.69 4321 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.200.10 54321 {
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 54321
                    }
                }
                real_server 10.2.200.20 54321 {
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 54321
                    }
                }
            }
        STATIC

        Dir.mktmpdir do |dir|
            Service::LVS.execute basedir: dir
            result = File.read "#{dir}/conf.d/lvs.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render lvs.cfg (static) (allow_nil_ports)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_REFRESH_RATE'] = ''
        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = ''

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.10.69'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB0_METHOD'] = 'NAT'
        ENV['ONEAPP_VNF_LB0_TIMEOUT'] = '10'
        ENV['ONEAPP_VNF_LB0_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = '10.2.100.10'
        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = '10.2.100.20'

        load './main.rb'; include Service::LVS

        Service::LVS.const_set :VROUTER_ID, '86'

        allow(Service::LVS).to receive(:toggle).and_return(nil)
        allow(Service::LVS).to receive(:sleep).and_return(nil)
        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::LVS).to receive(:addrs_to_nics).and_return({
            '10.2.10.69' => ['eth0']
        })

        clear_vars Service::LVS

        output = <<~STATIC
            virtual_server 10.2.10.69  {
                delay_loop 6
                lb_algo rr
                lb_kind NAT
                protocol TCP

                real_server 10.2.100.10  {
                    PING_CHECK {
                        retry 4
                    }
                }
                real_server 10.2.100.20  {
                    PING_CHECK {
                        retry 4
                    }
                }
            }
        STATIC

        Dir.mktmpdir do |dir|
            Service::LVS.execute basedir: dir
            result = File.read "#{dir}/conf.d/lvs.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render lvs.cfg (dynamic)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_ONEGATE_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = ''

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB0_PORT'] = '6969'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB0_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB0_TIMEOUT'] = '5'
        ENV['ONEAPP_VNF_LB0_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB0_SERVER0_HOST'] = '10.2.11.200'
        ENV['ONEAPP_VNF_LB0_SERVER0_PORT'] = '6969'

        ENV['ONEAPP_VNF_LB0_SERVER1_HOST'] = '10.2.11.201'
        ENV['ONEAPP_VNF_LB0_SERVER1_PORT'] = '6969'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB1_PORT'] = '8686'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB1_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB1_TIMEOUT'] = '5'
        ENV['ONEAPP_VNF_LB1_SCHEDULER'] = 'rr'

        # Internally forced to 'VROUTER' since not in OneFlow
        ENV['ONEAPP_VNF_LB_ONEGATE_API'] = 'service'

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
                            "ONEGATE_LB0_PROTOCOL": "TCP",

                            "ONEGATE_LB0_SERVER_HOST": "10.2.11.202",
                            "ONEGATE_LB0_SERVER_PORT": "6969",
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
                            "ONEGATE_LB0_PROTOCOL": "TCP",

                            "ONEGATE_LB0_SERVER_HOST": "10.2.11.201",
                            "ONEGATE_LB0_SERVER_PORT": "6969",
                            "ONEGATE_LB0_SERVER_WEIGHT": "2",

                            "ONEGATE_LB1_ID": "NOT-86",
                            "ONEGATE_LB1_IP": "10.2.11.86",
                            "ONEGATE_LB1_PORT": "8686",

                            "ONEGATE_LB1_SERVER_HOST": "10.2.11.201",
                            "ONEGATE_LB1_SERVER_PORT": "8686",
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

                            "ONEGATE_LB0_SERVER_HOST": "10.2.11.200",
                            "ONEGATE_LB0_SERVER_PORT": "6969",
                            "ONEGATE_LB0_SERVER_WEIGHT": "1",

                            "ONEGATE_LB1_ID": "86",
                            "ONEGATE_LB1_IP": "10.2.11.86",
                            "ONEGATE_LB1_PORT": "8686",

                            "ONEGATE_LB1_SERVER_HOST": "10.2.11.200",
                            "ONEGATE_LB1_SERVER_PORT": "8686",
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

        load './main.rb'; include Service::LVS

        Service::LVS.const_set :VROUTER_ID, '86'

        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::LVS).to receive(:addrs_to_nics).and_return({
            '10.2.11.86' => ['eth0']
        })

        clear_vars Service::LVS

        output = <<~'DYNAMIC'
            virtual_server 10.2.11.86 6969 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.11.200 6969 {
                    weight 1
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 6969
                    }
                }
                real_server 10.2.11.201 6969 {
                    weight 2
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 6969
                    }
                }
                real_server 10.2.11.202 6969 {
                    weight 3
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 6969
                    }
                }
            }
            virtual_server 10.2.11.86 8686 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.11.200 8686 {
                    weight 1
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 8686
                    }
                }
            }
        DYNAMIC

        Dir.mktmpdir do |dir|
            lvs_vars = Service::LVS.extract_backends vnets
            Service::LVS.render_lvs_conf lvs_vars, basedir: dir
            result = File.read "#{dir}/conf.d/lvs.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render lvs.cfg (dynamic/OneFlow)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_ONEGATE_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_LB_REFRESH_RATE'] = ''

        ENV['ONEAPP_VNF_LB0_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB0_PORT'] = '5432'
        ENV['ONEAPP_VNF_LB0_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB0_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB0_TIMEOUT'] = '5'
        ENV['ONEAPP_VNF_LB0_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB1_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB1_PORT'] = '4321'
        ENV['ONEAPP_VNF_LB1_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB1_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB1_TIMEOUT'] = '5'
        ENV['ONEAPP_VNF_LB1_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB_ONEGATE_API'] = 'auto'
        ENV['SERVICE_ID'] = '123'

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
                  "ONEGATE_LB0_SERVER_WEIGHT": "1",

                  "ONEGATE_LB1_ID": "86",
                  "ONEGATE_LB1_IP": "10.2.11.86",
                  "ONEGATE_LB1_PORT": "4321",
                  "ONEGATE_LB1_SERVER_HOST": "10.2.11.202",
                  "ONEGATE_LB1_SERVER_PORT": "1234",
                  "ONEGATE_LB1_SERVER_WEIGHT": "1",

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
                  "ONEGATE_LB0_SERVER_WEIGHT": "2",

                  "ONEGATE_LB1_ID": "123",
                  "ONEGATE_LB1_IP": "10.2.11.86",
                  "ONEGATE_LB1_PORT": "4321",
                  "ONEGATE_LB1_SERVER_HOST": "10.2.11.203",
                  "ONEGATE_LB1_SERVER_PORT": "1234",
                  "ONEGATE_LB1_SERVER_WEIGHT": "2",

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

        load './main.rb'; include Service::LVS

        Service::LVS.const_set :VROUTER_ID, '86'
        Service::LVS.const_set :SERVICE_ID, '123'

        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::LVS).to receive(:addrs_to_nics).and_return({
            '10.2.11.86' => ['eth0']
        })

        clear_vars Service::LVS

        output = <<~'DYNAMIC'
            virtual_server 10.2.11.86 5432 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.11.202 2345 {
                    weight 1
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 2345
                    }
                }
                real_server 10.2.11.203 2345 {
                    weight 2
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 2345
                    }
                }
            }
            virtual_server 10.2.11.86 4321 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.11.203 1234 {
                    weight 2
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 1234
                    }
                }
            }
        DYNAMIC

        Dir.mktmpdir do |dir|
            lvs_vars = Service::LVS.extract_backends vms
            Service::LVS.render_lvs_conf lvs_vars, basedir: dir
            result = File.read "#{dir}/conf.d/lvs.conf"
            expect(result.strip).to eq output.strip
        end
    end

  it 'should render lvs.cfg using VR API (dynamic/OneFlow)' do
        clear_env

        ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_LB_ONEGATE_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_LB_FWMARK_OFFSET'] = ''

        ENV['ONEAPP_VNF_LB3_IP'] = '10.2.11.86'
        ENV['ONEAPP_VNF_LB3_PORT'] = '7969'
        ENV['ONEAPP_VNF_LB3_PROTOCOL'] = 'TCP'
        ENV['ONEAPP_VNF_LB3_METHOD'] = 'DR'
        ENV['ONEAPP_VNF_LB3_TIMEOUT'] = '5'
        ENV['ONEAPP_VNF_LB3_SCHEDULER'] = 'rr'

        ENV['ONEAPP_VNF_LB3_SERVER0_HOST'] = '10.2.11.300'
        ENV['ONEAPP_VNF_LB3_SERVER0_PORT'] = '7969'

        ENV['ONEAPP_VNF_LB_ONEGATE_API'] = 'vrouter'

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
                            "IP": "10.2.11.300",
                            "MAC": "02:00:0a:02:0b:c8",
                            "VM": "167",
                            "NIC_NAME": "NIC0",
                            "BACKEND": "YES",

                            "ONEGATE_LB3_IP": "10.2.11.86",
                            "ONEGATE_LB3_PORT": "7969",

                            "ONEGATE_LB3_SERVER_HOST": "10.2.11.300",
                            "ONEGATE_LB3_SERVER_PORT": "7969",
                            "ONEGATE_LB3_SERVER_WEIGHT": "1"
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            }
        VNET0

        load './main.rb'; include Service::LVS

        Service::LVS.const_set :VROUTER_ID, '87'
        Service::LVS.const_set :SERVICE_ID, '124'

        allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::LVS).to receive(:addrs_to_nics).and_return({
            '10.2.11.86' => ['eth0']
        })

        clear_vars Service::LVS

        output = <<~'DYNAMIC'
            virtual_server 10.2.11.86 7969 {
                delay_loop 6
                lb_algo rr
                lb_kind DR
                protocol TCP

                real_server 10.2.11.300 7969 {
                    weight 1
                    TCP_CHECK {
                        connect_timeout 3
                        connect_port 7969
                    }
                }
            }
        DYNAMIC

        Dir.mktmpdir do |dir|
            lvs_vars = Service::LVS.extract_backends vnets
            Service::LVS.render_lvs_conf lvs_vars, basedir: dir
            result = File.read "#{dir}/conf.d/lvs.conf"
            expect(result.strip).to eq output.strip
        end
  end

    # NOTE: ONEAPP_VNF_NAT4_SNAT_ADDRESS is not configured on the router. Keepalived owns it as a /32 on the
    #       MASTER only (see Keepalived::snat_address), and LVS accepts it as a virtual IP in the same cases.
    describe 'NAT4 SNAT address' do
        let(:addr) { '203.0.113.10' }

        def lvs_conf(lbs, address: nil, enabled: 'YES', out: 'eth1', &block)
            clear_env
            ENV.delete_if { |name| name.start_with?('ONEAPP_VNF_NAT4_') || name.start_with?('ONEAPP_VNF_KEEPALIVED_') }
            ENV.delete_if { |name| name.start_with?('ONEAPP_VROUTER_') }

            ENV['ONEAPP_VNF_LB_ENABLED'] = 'YES'
            ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '10.2.20.69'

            lbs.each_with_index do |ip, i|
                ENV["ONEAPP_VNF_LB#{i}_IP"] = ip
                ENV["ONEAPP_VNF_LB#{i}_PORT"] = '80'
                ENV["ONEAPP_VNF_LB#{i}_PROTOCOL"] = 'TCP'
                ENV["ONEAPP_VNF_LB#{i}_SERVER0_HOST"] = '10.2.100.10'
                ENV["ONEAPP_VNF_LB#{i}_SERVER0_PORT"] = '80'
            end

            ENV['ONEAPP_VNF_NAT4_ENABLED'] = enabled
            ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = out unless out.nil?
            ENV['ONEAPP_VNF_NAT4_SNAT_ADDRESS'] = address unless address.nil?

            block&.call

            load './main.rb'; include Service::LVS

            allow(Service::LVS).to receive(:toggle).and_return(nil)
            allow(Service::LVS).to receive(:sleep).and_return(nil)
            allow(Service::LVS).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
            allow(Service::LVS).to receive(:addrs_to_nics).and_return({
                '10.2.10.69' => ['eth0'],
                '10.2.20.2'  => ['eth1']
            })

            clear_vars Service::LVS

            Dir.mktmpdir do |dir|
                Service::LVS.execute basedir: dir
                return File.read("#{dir}/conf.d/lvs.conf")
            end
        end

        def servers(conf)
            conf.scan(/^virtual_server (\S+) /).flatten
        end

        it 'should render a load balancer on the SNAT address' do
            expect(servers(lvs_conf([addr], address: addr))).to eq [addr]
        end

        it 'should ignore a prefix length on the attribute' do
            expect(servers(lvs_conf([addr], address: "#{addr}/24"))).to eq [addr]
        end

        it 'should keep the NIC and VIP load balancers' do
            conf = lvs_conf(['10.2.10.69', '10.2.20.69', addr], address: addr)

            expect(servers(conf)).to eq ['10.2.10.69', '10.2.20.69', addr]
        end

        it 'should render NIC and VIP load balancers as before when the attribute is unset' do
            expect(servers(lvs_conf(['10.2.10.69', '10.2.20.69', addr]))).to eq ['10.2.10.69', '10.2.20.69']
        end

        it 'should skip the SNAT address when NAT4 is disabled' do
            expect(servers(lvs_conf([addr], address: addr, enabled: 'NO'))).to eq []
        end

        it 'should skip the SNAT address when NAT4 has no outgoing NIC' do
            expect(servers(lvs_conf([addr], address: addr, out: nil))).to eq []
        end

        it 'should skip the SNAT address when the outgoing NIC has no VRRP instance' do
            expect(servers(lvs_conf([addr], address: addr, out: 'eth5'))).to eq []
        end

        it 'should skip the SNAT address when the outgoing NIC is not in the Keepalived interfaces' do
            conf = lvs_conf([addr], address: addr) { ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0' }

            expect(servers(conf)).to eq []
        end

        ['1.2.3.4; reboot', '999.1.1.1', '2001:db8::1', 'eth0', '0.0.0.0', '127.0.0.1', '224.0.0.1',
         '240.0.0.1', '255.255.255.255'].each do |bad|
            it "should skip a load balancer on the invalid SNAT address #{bad.inspect}" do
                expect(servers(lvs_conf([bad, '10.2.10.69'], address: bad))).to eq ['10.2.10.69']
            end
        end

        it 'should still skip an address that is neither a NIC, a VIP nor the SNAT address' do
            expect(servers(lvs_conf(['198.51.100.7', addr], address: addr))).to eq [addr]
        end

        it 'should skip the SNAT address when the outgoing NIC is skipped in Keepalived' do
            conf = lvs_conf([addr], address: addr) { ENV['ONEAPP_VNF_KEEPALIVED_ETH1_SKIP'] = 'YES' }

            expect(servers(conf)).to eq []
        end

        it 'should use a later eligible NIC when the first outgoing NIC is skipped in Keepalived' do
            conf = lvs_conf([addr], address: addr, out: 'eth0,eth1') { ENV['ONEAPP_VNF_KEEPALIVED_ETH0_SKIP'] = 'YES' }

            expect(servers(conf)).to eq [addr]
        end

        it 'should skip an address inside a NIC subnet' do
            conf = lvs_conf(['10.2.20.77'], address: '10.2.20.77') { ENV['ETH1_IP'] = '10.2.20.2' }

            expect(servers(conf)).to eq []
        end
    end
end
