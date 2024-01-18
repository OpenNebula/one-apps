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

        ENV['ONEAPP_VNF_KEEPALIVED_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_PRIORITY'] = '100'

        ENV['VROUTER_KEEPALIVED_ID'] = '11'
        ENV['ONEAPP_VNF_KEEPALIVED_VRID'] = '11'

        ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0 eth1'
        ENV['ETH8_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_PRIORITY'] = '100'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_VRID'] = '11'

        ENV['ETH0_VROUTER_IP'] = '10.2.11.69'
        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '10.2.11.69'
        ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '10.2.11.86'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_PRIORITY'] = '100'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_VRID'] = '11'

        ENV['ETH1_VROUTER_IP'] = '10.2.12.69'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '10.2.12.69'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '10.2.12.86'

        ENV['ETH0_IP'] = ''
        ENV['ETH1_IP'] = '172.16.1.1'

        load './main.rb'; include Service::Keepalived

        expect(Service::Keepalived::ONEAPP_VNF_KEEPALIVED_INTERVAL).to eq '1'
        expect(Service::Keepalived::ONEAPP_VNF_KEEPALIVED_PRIORITY).to eq '100'
        expect(Service::Keepalived::VROUTER_KEEPALIVED_ID).to eq '11'
        expect(Service::Keepalived::ONEAPP_VNF_KEEPALIVED_VRID).to eq '11'

        allow(Service::Keepalived).to receive(:ip_link_set_up).and_return(nil)
        allow(Service::Keepalived).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2])

        clear_vars Service::Keepalived

        keepalived_vars = Service::Keepalived.parse_env

        expect(Service::Keepalived.instance_variable_get(:@interfaces).keys).to eq %w[eth0 eth1]
        expect(Service::Keepalived.instance_variable_get(:@mgmt)).to eq %w[eth8]

        expect(keepalived_vars[:by_nic]['eth0'][:interval]).to eq '1'
        expect(keepalived_vars[:by_nic]['eth0'][:priority]).to eq '100'
        expect(keepalived_vars[:by_nic]['eth0'][:vrid]).to eq '11'
        expect(keepalived_vars[:by_nic]['eth0'][:vips][0]).to eq '10.2.11.69/32'
        expect(keepalived_vars[:by_nic]['eth0'][:vips][1]).to eq '10.2.11.86/32'
        expect(keepalived_vars[:by_nic]['eth0'][:noip]).to be true

        expect(keepalived_vars[:by_nic]['eth1'][:interval]).to eq '1'
        expect(keepalived_vars[:by_nic]['eth1'][:priority]).to eq '100'
        expect(keepalived_vars[:by_nic]['eth1'][:vrid]).to eq '11'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][0]).to eq '10.2.12.69/32'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][1]).to eq '10.2.12.86/32'
        expect(keepalived_vars[:by_nic]['eth1'][:noip]).to be false

        expect(keepalived_vars[:by_vrid]['11'].keys).to eq %w[eth0 eth1]
    end

    it 'should get default values from legacy env vars' do
        clear_env

        ENV['ONEAPP_VNF_KEEPALIVED_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_PRIORITY'] = '100'

        ENV['VROUTER_KEEPALIVED_ID'] = '21'
        ENV['ONEAPP_VNF_KEEPALIVED_VRID'] = ''

        ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0 eth1'

        ENV['ETH0_VROUTER_IP'] = '10.2.21.69'
        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = ''

        ENV['ETH1_VROUTER_IP'] = '10.2.22.69'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = ''

        ENV['ETH0_IP'] = ''
        ENV['ETH1_IP'] = '172.16.1.1'

        load './main.rb'; include Service::Keepalived

        expect(Service::Keepalived::VROUTER_KEEPALIVED_ID).to eq '21'
        expect(Service::Keepalived::ONEAPP_VNF_KEEPALIVED_VRID).to eq '21'

        allow(Service::Keepalived).to receive(:ip_link_set_up).and_return(nil)
        allow(Service::Keepalived).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2])

        clear_vars Service::Keepalived

        keepalived_vars = Service::Keepalived.parse_env

        expect(Service::Keepalived.instance_variable_get(:@interfaces).keys).to eq %w[eth0 eth1]

        expect(keepalived_vars[:by_nic]['eth0'][:vrid]).to eq '21'
        expect(keepalived_vars[:by_nic]['eth0'][:vips][0]).to eq '10.2.21.69/32'
        expect(keepalived_vars[:by_nic]['eth0'][:noip]).to be true

        expect(keepalived_vars[:by_nic]['eth1'][:vrid]).to eq '21'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][0]).to eq '10.2.22.69/32'
        expect(keepalived_vars[:by_nic]['eth1'][:noip]).to be false

        expect(keepalived_vars[:by_vrid]['21'].keys).to eq %w[eth0 eth1]
    end

    it 'should render vrrp.conf' do
        clear_env

        ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0 eth1 eth2 eth3'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_PRIORITY'] = '100'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_VRID'] = '30'

        ENV['ETH0_GATEWAY'] = '10.2.30.1'

        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '10.2.30.69'
        ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '10.2.30.86'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_PRIORITY'] = '100'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_VRID'] = '30'

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '10.2.31.69'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '10.2.31.86'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH2_INTERVAL'] = '1'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH2_PRIORITY'] = '100'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH2_VRID'] = '31'

        # NOTE: These are ignored because no NIC can handle VRID 31.
        ENV['ONEAPP_VROUTER_ETH2_VIP0'] = '10.2.32.69/24'
        ENV['ONEAPP_VROUTER_ETH2_VIP1'] = '10.2.32.86/24'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH3_VRID'] = '32'

        ENV['ONEAPP_VROUTER_ETH3_VIP0'] = '10.2.33.69'

        ENV['ETH0_IP'] = ''
        ENV['ETH1_IP'] = '10.2.31.2'
        ENV['ETH2_IP'] = ''
        ENV['ETH3_IP'] = '10.2.33.2'

        load './main.rb'; include Service::Keepalived

        allow(Service::Keepalived).to receive(:onegate_service_show).and_return(nil)
        allow(Service::Keepalived).to receive(:ip_link_set_up).and_return(nil)
        allow(Service::Keepalived).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::Keepalived).to receive(:toggle).and_return(nil)

        clear_vars Service::Keepalived

        output = <<~'VRRP'
            vrrp_sync_group VRouter {
                group {
                    ETH1
                    ETH3
                }
            }
            vrrp_instance ETH1 {
                state             BACKUP
                interface         eth1
                virtual_router_id 30
                priority          100
                advert_int        1
                virtual_ipaddress {
                    10.2.30.69/32 dev eth0
                    10.2.30.86/32 dev eth0
                    10.2.31.69/32 dev eth1
                    10.2.31.86/32 dev eth1
                }
                virtual_routes {
                    0.0.0.0/0 via 10.2.30.1
                }
            }
            vrrp_instance ETH3 {
                state             BACKUP
                interface         eth3
                virtual_router_id 32
                priority          100
                advert_int        1
                virtual_ipaddress {
                    10.2.33.69/32 dev eth3
                }
                virtual_routes {
                }
            }
        VRRP
        Dir.mktmpdir do |dir|
            Service::Keepalived.configure basedir: dir
            result = File.read "#{dir}/conf.d/vrrp.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should render vrrp.conf (passwords)' do
        clear_env

        ENV['VROUTER_KEEPALIVED_PASSWORD'] = 'asd123'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH3_PASSWORD'] = 'asd456'

        ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0 eth1 eth2 eth3'

        ENV['ONEAPP_VNF_KEEPALIVED_ETH0_VRID'] = '30'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH1_VRID'] = '30'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH2_VRID'] = '31'
        ENV['ONEAPP_VNF_KEEPALIVED_ETH3_VRID'] = '32'

        ENV['ETH0_IP'] = ''
        ENV['ETH1_IP'] = '10.2.31.2'
        ENV['ETH2_IP'] = '10.2.32.2'
        ENV['ETH3_IP'] = '10.2.33.2'

        load './main.rb'; include Service::Keepalived

        allow(Service::Keepalived).to receive(:onegate_service_show).and_return(nil)
        allow(Service::Keepalived).to receive(:ip_link_set_up).and_return(nil)
        allow(Service::Keepalived).to receive(:detect_nics).and_return(%w[eth0 eth1 eth2 eth3])
        allow(Service::Keepalived).to receive(:toggle).and_return(nil)

        clear_vars Service::Keepalived

        output = <<~'VRRP'
            vrrp_sync_group VRouter {
                group {
                    ETH1
                    ETH2
                    ETH3
                }
            }
            vrrp_instance ETH1 {
                state             BACKUP
                interface         eth1
                virtual_router_id 30
                priority          100
                advert_int        1
                virtual_ipaddress {
                }
                virtual_routes {
                }
                authentication {
                    auth_type PASS
                    auth_pass asd123
                }
            }
            vrrp_instance ETH2 {
                state             BACKUP
                interface         eth2
                virtual_router_id 31
                priority          100
                advert_int        1
                virtual_ipaddress {
                }
                virtual_routes {
                }
                authentication {
                    auth_type PASS
                    auth_pass asd123
                }
            }
            vrrp_instance ETH3 {
                state             BACKUP
                interface         eth3
                virtual_router_id 32
                priority          100
                advert_int        1
                virtual_ipaddress {
                }
                virtual_routes {
                }
                authentication {
                    auth_type PASS
                    auth_pass asd456
                }
            }
        VRRP
        Dir.mktmpdir do |dir|
            Service::Keepalived.configure basedir: dir
            result = File.read "#{dir}/conf.d/vrrp.conf"
            expect(result.strip).to eq output.strip
        end
    end
end
