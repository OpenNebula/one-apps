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
        expect(keepalived_vars[:by_nic]['eth0'][:vips][0]).to eq '10.2.11.69/8'
        expect(keepalived_vars[:by_nic]['eth0'][:vips][1]).to eq '10.2.11.86/8'
        expect(keepalived_vars[:by_nic]['eth0'][:noip]).to be true

        expect(keepalived_vars[:by_nic]['eth1'][:interval]).to eq '1'
        expect(keepalived_vars[:by_nic]['eth1'][:priority]).to eq '100'
        expect(keepalived_vars[:by_nic]['eth1'][:vrid]).to eq '11'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][0]).to eq '10.2.12.69/8'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][1]).to eq '10.2.12.86/8'
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
        expect(keepalived_vars[:by_nic]['eth0'][:vips][0]).to eq '10.2.21.69/8'
        expect(keepalived_vars[:by_nic]['eth0'][:noip]).to be true

        expect(keepalived_vars[:by_nic]['eth1'][:vrid]).to eq '21'
        expect(keepalived_vars[:by_nic]['eth1'][:vips][0]).to eq '10.2.22.69/8'
        expect(keepalived_vars[:by_nic]['eth1'][:noip]).to be false

        expect(keepalived_vars[:by_vrid]['21'].keys).to eq %w[eth0 eth1]
    end

    it 'should render vrrp.conf' do
        clear_env

        ENV['ONEGATE_ENDPOINT'] = 'http://127.0.0.1:5030'

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

        allow(OneGate.instance).to receive(:service_show).and_return(nil)
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
                    10.2.30.69/8 dev eth0
                    10.2.30.86/8 dev eth0
                    10.2.31.69/8 dev eth1
                    10.2.31.86/8 dev eth1
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
                    10.2.33.69/8 dev eth3
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

        ENV['ONEGATE_ENDPOINT'] = 'http://127.0.0.1:5030'

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

        allow(OneGate.instance).to receive(:service_show).and_return(nil)
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

    # NOTE: ONEAPP_VNF_NAT4_SNAT_ADDRESS is not configured on the router. Keepalived owns it as a /32
    #       virtual address on the first outgoing NIC, so it is present on the VRRP MASTER only.
    describe 'NAT4 SNAT address' do
        let(:addr) { '203.0.113.10' }

        def vrrp_conf(address: nil, out: 'eth1', enabled: 'YES', &block)
            clear_env

            ENV['ONEGATE_ENDPOINT'] = 'http://127.0.0.1:5030'
            ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0 eth1'
            ENV['ONEAPP_VNF_KEEPALIVED_ETH0_VRID'] = '30'
            ENV['ONEAPP_VNF_KEEPALIVED_ETH1_VRID'] = '30'
            ENV['ETH0_IP'] = '10.2.30.2'
            ENV['ETH1_IP'] = '10.2.31.2'
            ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '10.2.30.69'
            ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '10.2.31.69'

            ENV['ONEAPP_VNF_NAT4_ENABLED'] = enabled
            ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = out unless out.nil?
            ENV['ONEAPP_VNF_NAT4_SNAT_ADDRESS'] = address unless address.nil?

            block&.call

            load './main.rb'; include Service::Keepalived

            allow(OneGate.instance).to receive(:service_show).and_return(nil)
            allow(Service::Keepalived).to receive(:ip_link_set_up).and_return(nil)
            allow(Service::Keepalived).to receive(:detect_nics).and_return(%w[eth0 eth1])
            allow(Service::Keepalived).to receive(:toggle).and_return(nil)

            clear_vars Service::Keepalived

            Dir.mktmpdir do |dir|
                Service::Keepalived.configure basedir: dir
                return File.read("#{dir}/conf.d/vrrp.conf")
            end
        end

        def vip_lines(conf)
            conf[/virtual_ipaddress \{\n(.*?)\n\s*\}/m, 1].lines.map(&:strip)
        end

        it 'should render the address as /32 after the VIPs, on the outgoing NIC' do
            expect(vip_lines(vrrp_conf(address: addr))).to eq [
                '10.2.30.69/8 dev eth0', '10.2.31.69/8 dev eth1', "#{addr}/32 dev eth1"
            ]
        end

        it 'should always use /32, whatever prefix length is given' do
            expect(vip_lines(vrrp_conf(address: "#{addr}/24"))).to include "#{addr}/32 dev eth1"
        end

        it 'should render a single copy on the first outgoing NIC' do
            conf = vrrp_conf(address: addr, out: 'eth1,eth0')

            expect(conf.scan(addr).count).to eq 1
            expect(vip_lines(conf)).to include "#{addr}/32 dev eth0"
        end

        it 'should leave the real VIPs untouched in the parsed vars' do
            vrrp_conf(address: addr)

            expect(Service::Keepalived.parse_env[:by_nic]['eth1'][:vips]).to eq ['10.2.31.69/8']
        end

        it 'should render nothing when the attribute is unset' do
            expect(vrrp_conf).not_to include '/32'
        end

        it 'should render nothing when NAT4 is disabled' do
            expect(vrrp_conf(address: addr, enabled: 'NO')).not_to include addr
        end

        it 'should render nothing when NAT4 has no outgoing NIC' do
            expect(vrrp_conf(address: addr, out: nil)).not_to include addr
        end

        it 'should render nothing for a NIC that has no VRRP instance' do
            expect(vrrp_conf(address: addr, out: 'eth5')).not_to include addr
        end

        it 'should not use a management NIC' do
            conf = vrrp_conf(address: addr, out: 'eth0,eth1') { ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES' }

            expect(vip_lines(conf)).to include "#{addr}/32 dev eth1"
        end

        ['1.2.3.4; reboot', '999.1.1.1', '2001:db8::1', 'eth0', '0.0.0.0', '127.0.0.1', '224.0.0.1',
         '240.0.0.1', '255.255.255.255'].each do |bad|
            it "should render nothing for #{bad.inspect}" do
                expect(vip_lines(vrrp_conf(address: bad))).to eq ['10.2.30.69/8 dev eth0', '10.2.31.69/8 dev eth1']
            end
        end

        it 'should not duplicate an address that is already a VIP' do
            conf = vrrp_conf(address: '10.2.31.69')

            expect(conf.scan('10.2.31.69').count).to eq 1
        end

        it 'should not duplicate an address that is a NIC address' do
            expect(vrrp_conf(address: '10.2.31.2')).not_to include '10.2.31.2'
        end

        context 'when the outgoing NIC gets no VRRP instance' do
            def eth_vrids(vrid0, vrid1)
                ENV['ONEAPP_VNF_KEEPALIVED_ETH0_VRID'] = vrid0
                ENV['ONEAPP_VNF_KEEPALIVED_ETH1_VRID'] = vrid1
            end

            it 'should skip a NIC with SKIP=YES that is alone in its VRID group' do
                conf = vrrp_conf(address: addr) { eth_vrids('30', '31'); ENV['ONEAPP_VNF_KEEPALIVED_ETH1_SKIP'] = 'YES' }

                expect(conf).not_to include addr
            end

            it 'should use a later eligible NIC when the first outgoing NIC is skipped' do
                conf = vrrp_conf(address: addr, out: 'eth0,eth1') { ENV['ONEAPP_VNF_KEEPALIVED_ETH0_SKIP'] = 'YES' }

                expect(vip_lines(conf)).to include "#{addr}/32 dev eth1"
                expect(conf.scan(addr).count).to eq 1
            end

            it 'should use a later NIC in another VRID group when the first is skipped' do
                conf = vrrp_conf(address: addr, out: 'eth0,eth1') { eth_vrids('30', '31'); ENV['ONEAPP_VNF_KEEPALIVED_ETH0_SKIP'] = 'YES' }

                expect(vip_lines(conf.split('vrrp_instance ').last)).to include "#{addr}/32 dev eth1"
            end

            it 'should not use a floating-only NIC (no IP)' do
                conf = vrrp_conf(address: addr, out: 'eth1') { ENV.delete('ETH1_IP') }

                expect(conf).not_to include addr
            end

            it 'should use the next NIC with an IP when the first outgoing NIC is floating-only' do
                conf = vrrp_conf(address: addr, out: 'eth0,eth1') { ENV.delete('ETH0_IP') }

                expect(vip_lines(conf)).to include "#{addr}/32 dev eth1"
            end

            it 'should use the first outgoing NIC when each NIC has its own VRID' do
                conf = vrrp_conf(address: addr, out: 'eth0,eth1') { eth_vrids('30', '31') }

                expect(conf.scan(addr).count).to eq 1
                expect(conf).to match(/vrrp_instance ETH0 \{.*#{addr}\/32 dev eth0.*vrrp_instance ETH1/m)
            end
        end

        context 'when the address is unusable' do
            it 'should render nothing for an address inside the subnet of a NIC' do
                expect(vrrp_conf(address: '10.9.9.9')).not_to include '10.9.9.9'
            end

            it 'should render nothing for an address inside the subnet of a non-outgoing NIC' do
                conf = vrrp_conf(address: '192.168.5.7', out: 'eth1') do
                    ENV['ETH0_IP'] = '192.168.5.2'
                    ENV['ETH0_MASK'] = '255.255.255.0'
                end

                expect(conf).not_to include '192.168.5.7'
            end

            it 'should render nothing for an address that is an alias of a NIC' do
                expect(vrrp_conf(address: addr) { ENV['ETH1_ALIAS0_IP'] = addr }).not_to include addr
            end

            it 'should render nothing for an address inside the subnet of an alias with a mask' do
                conf = vrrp_conf(address: '172.20.0.9') do
                    ENV['ETH1_ALIAS0_IP'] = '172.20.0.2'
                    ENV['ETH1_ALIAS0_MASK'] = '255.255.255.0'
                end

                expect(conf).not_to include '172.20.0.9'
            end

            it 'should render a valid address next to unrelated aliases' do
                conf = vrrp_conf(address: addr) { ENV['ETH1_ALIAS0_IP'] = '198.51.100.5' }

                expect(vip_lines(conf)).to include "#{addr}/32 dev eth1"
            end

            it 'should not raise on odd alias values and render nothing' do
                conf = nil
                expect do
                    conf = vrrp_conf(address: addr) do
                        ENV['ETH1_ALIAS0_IP'] = '198.51.100.5'
                        ENV['ETH1_ALIAS0_MASK'] = 'bogus'
                    end
                end.not_to raise_error

                expect(conf).not_to include addr
                expect(vip_lines(conf)).to eq ['10.2.30.69/8 dev eth0', '10.2.31.69/8 dev eth1']
            end
        end
    end
end
