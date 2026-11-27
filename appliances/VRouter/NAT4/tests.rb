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
    it 'should parse env vars' do
        clear_env

        ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = 'eth0'

        # valid
        ENV['ONEAPP_VNF_NAT4_PORT_FWD0'] = '14.15.16.17:1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD1'] = '14.15.16.17:1234:10.11.12.13'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD2'] = '1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD3'] = '2345:10.11.12.13'

        # ignored
        ENV['ONEAPP_VNF_NAT4_PORT_FWD4'] = ''
        ENV['ONEAPP_VNF_NAT4_PORT_FWD5'] = ':'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD6'] = '::'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD7'] = '1234:'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD8'] = '14.15.16.17:1234:10.11.12.13:4321:asd'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD9'] = 'asd:1234:10.11.12.13:4321'

        load './main.rb'; include Service::NAT4

        clear_vars Service::NAT4

        expect(Service::NAT4.parse_env).to eq ({
            dnat: { 0 => ['14.15.16.17', '1234', '10.11.12.13', '4321'],
                    1 => ['14.15.16.17', '1234', '10.11.12.13', nil],
                    2 => [nil, '1234', '10.11.12.13', '4321'],
                    3 => [nil, '2345', '10.11.12.13', nil] },

            masq: %w[eth0]
        })
    end

    it 'should parse and interpolate env vars' do
        clear_env

        ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = 'eth1'

        ENV['ETH0_IP'] = '14.15.16.17'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '15.16.17.18'
        ENV['ETH1_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'

        ENV['ONEAPP_VNF_NAT4_PORT_FWD0'] = '<ETH0_EP0>:1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD1'] = '<ETH1_EP0>:4321:10.11.12.13'

        load './main.rb'; include Service::NAT4

        clear_vars Service::NAT4

        expect(Service::NAT4.parse_env).to eq ({
            dnat: { 0 => ['14.15.16.86', '1234', '10.11.12.13', '4321'],
                    1 => ['15.16.17.18', '4321', '10.11.12.13', nil] },

            masq: %w[eth1]
        })
    end

    describe 'SNAT to the VIP' do
        def masq_rules(snat: nil, address: nil, out: 'eth0,eth1')
            clear_env

            ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
            ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = out
            ENV['ONEAPP_VNF_NAT4_SNAT_TO_VIP'] = snat unless snat.nil?
            ENV['ONEAPP_VNF_NAT4_SNAT_ADDRESS'] = address unless address.nil?

            ENV['ETH0_IP'] = '14.15.16.17'
            ENV['ETH0_MASK'] = '255.255.255.0'
            ENV['ETH1_IP'] = '192.168.1.2'
            ENV['ETH1_MASK'] = '255.255.255.0'

            yield if block_given?

            load './main.rb'; include Service::NAT4

            clear_vars Service::NAT4

            scripts = @scripts = []
            @errors = []
            @warnings = []
            allow(Service::NAT4).to receive(:bash) { |script| scripts << script; '' }
            allow(Service::NAT4).to receive(:toggle)
            allow(Service::NAT4).to receive(:msg) do |level, text|
                @errors << text if level == :error
                @warnings << text if level == :warn
            end
            Service::NAT4.execute

            scripts.flat_map(&:lines).map(&:strip).grep(/NAT4-MASQ -o/)
        end

        it 'should render MASQUERADE when the attribute is unset' do
            rules = masq_rules { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

            expect(rules).to eq [
                "iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE",
                "iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"
            ]
        end

        it 'should render MASQUERADE when the attribute is NO' do
            rules = masq_rules(snat: 'NO') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

            expect(rules).to eq [
                "iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE",
                "iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"
            ]
        end

        it 'should render SNAT with the ONEAPP_VROUTER_ETH<n>_VIP<m> address' do
            rules = masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'"]
        end

        it 'should render SNAT with the ETH<n>_VROUTER_IP floating IP' do
            rules = masq_rules(snat: 'YES', out: 'eth0') { ENV['ETH0_VROUTER_IP'] = '14.15.16.99' }

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.99'"]
        end

        it 'should ignore an IPv6 VIP at a lower index and SNAT to the IPv4 one' do
            rules = masq_rules(snat: 'YES', out: 'eth0') do
                ENV['ONEAPP_VROUTER_ETH0_VIP0'] = 'fd77::f0/64'
                ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '203.0.113.10/24'
            end

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'"]
        end

        it 'should ignore the IPv6 floating IP and SNAT to the IPv4 VIP' do
            rules = masq_rules(snat: 'YES', out: 'eth0') do
                ENV['ETH0_VROUTER_IP6'] = 'fd77::99'
                ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '203.0.113.10'
            end

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'"]
        end

        it 'should keep MASQUERADE when a NIC has only IPv6 VIPs' do
            rules = masq_rules(snat: 'YES', out: 'eth0') do
                ENV['ETH0_VROUTER_IP6'] = 'fd77::99'
                ENV['ONEAPP_VROUTER_ETH0_VIP0'] = 'fd77::f0/64'
            end

            expect(rules.join).to include('MASQUERADE')
            expect(rules.join).not_to include('SNAT')
        end

        it 'should fall back to MASQUERADE for a NIC without a VIP' do
            rules = masq_rules(snat: 'YES', out: 'eth1') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"]
        end

        it 'should mix SNAT and MASQUERADE per NIC' do
            rules = masq_rules(snat: 'YES') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

            expect(rules).to eq [
                "iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'",
                "iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"
            ]
        end

        it 'should use the first VIP of a NIC in index order' do
            rules = masq_rules(snat: 'YES', out: 'eth0') do
                ENV['ONEAPP_VROUTER_ETH0_VIP2'] = '14.15.16.88'
                ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '14.15.16.87'
            end

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.87'"]
        end

        it 'should strip a prefix length from the VIP' do
            rules = masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86/24' }

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'"]
        end

        it 'should quote the address in the SNAT rule' do
            expect(masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' })
                .to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'"]
        end

        # NOTE: stock detect_vips needs a parseable address, so the hostile values carry an explicit /24.
        [
            '1.2.3.4; reboot', '1.2.3.4 -j ACCEPT', '$(id)', '`id`', "1.2.3.4\nfoo",
            '999.1.1.1', '1.2.3', '01.2.3.4', '1.2.3.4.5', ' 1.2.3.4', "1.2.3.4\n"
        ].each do |bad|
            it "should reject the VIP #{bad.inspect} and fall back to MASQUERADE" do
                rules = masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = "#{bad}/24" }

                expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE"]
                expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '999')
            end
        end

        it 'should log an error naming the NIC for an invalid VIP' do
            masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '1.2.3.4; reboot/24' }

            expect(@errors.join).to include('eth0')
        end

        it 'should use the VIP when only a garbage prefix length is given' do
            rules = masq_rules(snat: 'YES', out: 'eth0') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '1.2.3.4/abc' }

            expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '1.2.3.4'"]
        end

        context 'with ONEAPP_VNF_NAT4_SNAT_ADDRESS' do
            it 'should SNAT every outgoing NIC to the address, without any VIP' do
                rules = masq_rules(address: '203.0.113.10')

                expect(rules).to eq [
                    "iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'",
                    "iptables -t nat -A NAT4-MASQ -o 'eth1' -j SNAT --to-source '203.0.113.10'"
                ]
            end

            it 'should only touch the NICs listed as outgoing' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1')

                expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j SNAT --to-source '203.0.113.10'"]
            end

            it 'should win over the VIP when SNAT to the VIP is enabled too' do
                rules = masq_rules(snat: 'YES', address: '203.0.113.10', out: 'eth0') do
                    ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'
                end

                expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'"]
            end

            it 'should render MASQUERADE when the attribute is empty' do
                expect(masq_rules(address: '', out: 'eth0'))
                    .to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE"]
            end

            it 'should strip a prefix length and surrounding spaces' do
                expect(masq_rules(address: ' 203.0.113.10/32 ', out: 'eth0'))
                    .to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'"]
            end

            [
                '1.2.3.4; reboot', '1.2.3.4 -j ACCEPT', '$(id)', '`id`', "1.2.3.4\nfoo",
                '999.1.1.1', '1.2.3', '01.2.3.4', '1.2.3.4.5', '2001:db8::1', 'eth0'
            ].each do |bad|
                it "should reject #{bad.inspect} and keep MASQUERADE, not the VIP" do
                    rules = masq_rules(snat: 'YES', address: bad, out: 'eth0') do
                        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'
                    end

                    expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE"]
                    expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '999')
                end
            end

            it 'should log an error that names the attribute, with at most 40 characters of the value' do
                masq_rules(address: "x#{'y' * 80}", out: 'eth0')

                expect(@errors.join).to include('ONEAPP_VNF_NAT4_SNAT_ADDRESS')
                expect(@errors.join).not_to include('y' * 41)
            end
        end

        # NOTE: The address is only SNATed to when Keepalived owns it (same helper), otherwise a packet for it
        #       without a conntrack entry would loop between the router and the upstream.
        context 'when Keepalived does not own the address' do
            let(:masq_eth1) { ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"] }

            it 'should render MASQUERADE, not SNAT, when the outgoing NIC has no VRRP instance' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1') { ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0' }

                expect(rules).to eq masq_eth1
                expect(@scripts.join).not_to include('SNAT --to-source')
            end

            it 'should warn that the address is not owned and MASQUERADE is used' do
                masq_rules(address: '203.0.113.10', out: 'eth1') { ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0' }

                expect(@warnings.join).to include('ONEAPP_VNF_NAT4_SNAT_ADDRESS', 'MASQUERADE')
            end

            it 'should not fall back to the VIP either' do
                rules = masq_rules(snat: 'YES', address: '203.0.113.10', out: 'eth1') do
                    ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0'
                    ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '192.168.1.99'
                end

                expect(rules).to eq masq_eth1
            end

            it 'should render MASQUERADE when the only outgoing NIC is skipped in Keepalived' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1') { ENV['ONEAPP_VNF_KEEPALIVED_ETH1_SKIP'] = 'YES' }

                expect(rules).to eq masq_eth1
            end

            it 'should render MASQUERADE for an address inside a NIC subnet' do
                rules = masq_rules(address: '192.168.1.77', out: 'eth1')

                expect(rules).to eq masq_eth1
                expect(@warnings.join).to include('192.168.1.77')
            end

            it 'should render MASQUERADE for an address that is an alias of a NIC' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1') { ENV['ETH0_ALIAS0_IP'] = '203.0.113.10' }

                expect(rules).to eq masq_eth1
            end

            it 'should keep SNAT for a valid address next to unrelated aliases' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1') { ENV['ETH0_ALIAS0_IP'] = '198.51.100.5' }

                expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j SNAT --to-source '203.0.113.10'"]
            end

            it 'should not raise on odd network values and render MASQUERADE' do
                rules = masq_rules(address: '203.0.113.10', out: 'eth1') do
                    ENV['ETH0_ALIAS0_IP'] = '198.51.100.5'
                    ENV['ETH0_ALIAS0_MASK'] = 'bogus'
                end

                expect(rules).to eq masq_eth1
            end
        end

        # NOTE: SNAT rewrites everything that leaves the NIC, including the packets the router sends itself.
        #       VRRP advertisements would then carry the NAT address as source for both nodes, so neither
        #       can win the election, and both keep the VIPs.
        context 'with locally generated traffic' do
            let(:return_local) { 'iptables -t nat -A NAT4-MASQ -m addrtype --src-type LOCAL -j RETURN' }

            def all_rules
                @scripts.flat_map(&:lines).map(&:strip).grep(/-A NAT4-MASQ/)
            end

            it 'should not SNAT packets with a local source address' do
                masq_rules(address: '203.0.113.10', out: 'eth0')

                expect(all_rules).to eq [
                    return_local,
                    "iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '203.0.113.10'"
                ]
            end

            it 'should return local traffic before any SNAT rule when SNAT to the VIP is used' do
                masq_rules(snat: 'YES') { ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86' }

                expect(all_rules.first).to eq return_local
                expect(all_rules.index { |r| r.include?('SNAT --to-source') }).to be > 0
            end

            it 'should render the local return rule once, not once per NIC' do
                masq_rules(address: '203.0.113.10')

                expect(all_rules.count(return_local)).to eq 1
            end

            it 'should leave the MASQUERADE rules unchanged' do
                masq_rules(out: 'eth0,eth1')

                expect(all_rules).to eq [
                    "iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE",
                    "iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"
                ]
            end

            it 'should not add the local return rule when an invalid address keeps MASQUERADE' do
                masq_rules(address: '1.2.3.4; reboot', out: 'eth0')

                expect(all_rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth0' -j MASQUERADE"]
            end

            context 'with ONEAPP_VNF_NAT4_SNAT_LOCAL' do
                def local_rule(match)
                    "iptables -t nat -A NAT4-MASQ -m addrtype --src-type LOCAL #{match} -j RETURN"
                end

                def render(local: 'YES', address: '203.0.113.10', snat: nil, out: 'eth1')
                    masq_rules(address: address, snat: snat, out: out) do
                        ENV['ONEAPP_VNF_NAT4_SNAT_LOCAL'] = local
                        yield if block_given?
                    end
                    all_rules
                end

                let(:snat_eth1) { "iptables -t nat -A NAT4-MASQ -o 'eth1' -j SNAT --to-source '203.0.113.10'" }

                let(:fixed) do
                    ['-d 224.0.0.0/4', '--dst-type BROADCAST', '-d 169.254.0.0/16', '-p 112', '-p 89',
                     '-d 192.168.1.0/24', '-p tcp --dport 179', '-p tcp --sport 179',
                     '-p udp -m multiport --dports 3784,3785,4784', '-p 47', '-p 4']
                end

                it 'should return only the exceptions, in order, before SNAT' do
                    expect(render).to eq(fixed.map { |m| local_rule(m) } + [snat_eth1])
                end

                it 'should keep the single return rule with NO' do
                    expect(render(local: 'NO')).to eq [return_local, snat_eth1]
                end

                it 'should render no return rule when the address is invalid' do
                    expect(render(address: 'bogus')).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"]
                end

                it 'should render no return rule when Keepalived does not own the address' do
                    rules = render { ENV['ONEAPP_VNF_KEEPALIVED_INTERFACES'] = 'eth0' }

                    expect(rules).to eq ["iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"]
                end

                it 'should return the VIP and alias subnets of the outgoing NIC only' do
                    rules = render do
                        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '198.51.100.9/28'
                        ENV['ETH1_ALIAS0_IP']   = '10.9.8.7'
                        ENV['ETH1_ALIAS0_MASK'] = '255.255.0.0'
                    end

                    expect(rules).to include(local_rule('-d 198.51.100.0/28'), local_rule('-d 10.9.0.0/16'))
                    expect(rules.join).not_to include('14.15.16.')
                end

                it 'should skip IPv6 subnets' do
                    rules = render { ENV['ONEAPP_VROUTER_ETH1_VIP0'] = 'fd77::f0/64' }

                    expect(rules.join).not_to include('fd77')
                    expect(rules.last).to eq snat_eth1
                end

                # With a SNAT address such values already fail the ownership check, so use SNAT to the VIP.
                it 'should skip unparsable VIPs and aliases' do
                    rules = render(address: nil, snat: 'YES', out: 'eth0,eth1') do
                        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'
                        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '1.2.3.4; reboot/24'
                        ENV['ETH1_ALIAS0_IP']   = '10.9.8.7'
                        ENV['ETH1_ALIAS0_MASK'] = 'bogus'
                    end

                    expect(rules.join).not_to include('reboot', '10.9.', 'bogus')
                    expect(rules).to include("iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'")
                end

                it 'should return traffic of a masqueraded NIC before MASQUERADE' do
                    rules = render(address: nil, snat: 'YES', out: 'eth0,eth1') do
                        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'
                    end

                    expect(rules[-3..]).to eq [
                        "iptables -t nat -A NAT4-MASQ -o 'eth0' -j SNAT --to-source '14.15.16.86'",
                        local_rule("-o 'eth1'"),
                        "iptables -t nat -A NAT4-MASQ -o 'eth1' -j MASQUERADE"
                    ]
                end

                it 'should return the unicast conntrack sync peer' do
                    rules = render { ENV['ONEAPP_VNF_CONNTRACK_SYNC_PEER'] = '10.20.30.40' }

                    expect(rules).to include(local_rule('-d 10.20.30.40'))
                end

                it 'should return the WireGuard source port, default 51820' do
                    rules = render { ENV['ONEAPP_VNF_WG_ENABLED'] = 'YES' }

                    expect(rules).to include(local_rule('-p udp --sport 51820'))
                end

                it 'should use the configured WireGuard port' do
                    rules = render do
                        ENV['ONEAPP_VNF_WG_ENABLED'] = 'YES'
                        ENV['ONEAPP_VNF_WG_LISTEN_PORT'] = '4500'
                    end

                    expect(rules).to include(local_rule('-p udp --sport 4500'))
                end

                it 'should not return a WireGuard port when WireGuard is disabled' do
                    expect(render.join).not_to include('51820')
                end

                it 'should skip a malformed peer and port and log both' do
                    rules = render do
                        ENV['ONEAPP_VNF_CONNTRACK_SYNC_PEER'] = '1.2.3.4; reboot'
                        ENV['ONEAPP_VNF_WG_ENABLED'] = 'YES'
                        ENV['ONEAPP_VNF_WG_LISTEN_PORT'] = '$(id)'
                    end

                    expect(rules.join).not_to include('reboot', '$(id)', '--sport 51820')
                    expect(@errors.join).to include('ONEAPP_VNF_CONNTRACK_SYNC_PEER', 'ONEAPP_VNF_WG_LISTEN_PORT')
                end
            end
        end
    end

    # NOTE: The SNAT address is owned by Keepalived (a /32 virtual_ipaddress, MASTER only), see Keepalived/tests.rb.
    #       NAT4 itself never configures addresses, it only validates the value and renders the rules.
    describe 'SNAT address ownership' do
        def run(op, address:)
            clear_env

            ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
            ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = 'eth0,eth1'
            ENV['ONEAPP_VNF_NAT4_SNAT_ADDRESS'] = address
            ENV['ETH0_IP'] = '14.15.16.17'
            ENV['ETH1_IP'] = '192.168.1.2'

            load './main.rb'; include Service::NAT4

            clear_vars Service::NAT4

            @scripts = scripts = []
            allow(Service::NAT4).to receive(:bash) { |script, **_| scripts << script; '' }
            allow(Service::NAT4).to receive(:toggle)
            allow(Service::NAT4).to receive(:msg)
            Service::NAT4.public_send(op)
        end

        %i[execute cleanup].each do |op|
            it "should not touch interface addresses in #{op}" do
                run(op, address: '203.0.113.10')

                expect(@scripts.join).not_to match(/\bip\b/)
            end
        end

        ['0.0.0.0', '0.1.2.3', '127.0.0.1', '127.1.2.3', '224.0.0.1', '239.1.2.3', '240.0.0.1',
         '255.255.255.255'].each do |bad|
            it "should reject #{bad.inspect} and keep MASQUERADE" do
                run(:execute, address: bad)

                expect(@scripts.join).to include("-o 'eth0' -j MASQUERADE")
                expect(@scripts.join).not_to include('SNAT --to-source')
            end
        end

        it 'should accept a public unicast address' do
            run(:execute, address: '203.0.113.10/24')

            expect(@scripts.join).to include("-o 'eth0' -j SNAT --to-source '203.0.113.10'")
        end
    end

    describe 'boot with saved rules' do
        def configure_nat4(local:, running:, enabled: 'YES')
            clear_env

            ENV['ONEAPP_VNF_NAT4_ENABLED'] = enabled
            ENV['ONEAPP_VNF_NAT4_SNAT_LOCAL'] = local

            load './main.rb'; include Service::NAT4

            clear_vars Service::NAT4

            calls = []
            allow(Service::NAT4).to receive(:msg)
            allow(Service::NAT4).to receive(:toggle) { |ops| calls.concat(ops) }
            allow(Service::NAT4).to receive(:bash) do |script|
                raise '3: stopped' if script.include?('rc-service one-nat4 status') && !running

                calls << script.strip if script.include?('-F NAT4-MASQ')
                ''
            end
            Service::NAT4.configure
            calls
        end

        let(:flush) { 'if iptables -t nat -nL NAT4-MASQ; then iptables -t nat -F NAT4-MASQ; fi' }

        it 'should flush restored source NAT rules before saving while one-nat4 is stopped' do
            expect(configure_nat4(local: 'YES', running: false)).to eq [flush, :save]
        end

        it 'should keep the rules while one-nat4 is running' do
            expect(configure_nat4(local: 'YES', running: true)).to eq [:save]
        end

        it 'should leave the rules alone with NO' do
            expect(configure_nat4(local: 'NO', running: false)).to eq [:save]
        end
    end
end
