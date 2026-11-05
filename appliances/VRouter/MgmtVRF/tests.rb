# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.start_with?('ONEGATE') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

RSpec.describe self do
    def run_execute(env = {})
        clear_env
        env.each { |k, v| ENV[k] = v }

        load './main.rb'; include Service::MgmtVRF

        @scripts = []
        @errors = []
        scripts = @scripts
        allow(Service::MgmtVRF).to receive(:bash) { |script| scripts << script; '' }
        allow(Service::MgmtVRF).to receive(:toggle)
        allow(Service::MgmtVRF).to receive(:msg) { |level, text| @errors << text if level == :error }

        Dir.mktmpdir do |dir|
            Service::MgmtVRF.execute basedir: dir
            @sysctl = File.exist?("#{dir}/97-MgmtVRF.conf") ? File.read("#{dir}/97-MgmtVRF.conf") : nil
        end

        @scripts.flat_map(&:lines).map(&:strip).reject(&:empty?)
    end

    let(:mgmt) { { 'ETH0_VROUTER_MANAGEMENT' => 'YES', 'ETH0_IP' => '172.20.128.210', 'ETH0_GATEWAY' => '172.20.128.1' } }

    it 'should create the VRF and move the management NIC into it' do
        cmds = run_execute(mgmt)

        expect(cmds).to include("ip link add 'mgmt' type vrf table 1000")
        expect(cmds).to include("ip link set 'mgmt' up")
        expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
    end

    it 'should put the default route of the management NIC into the VRF table' do
        cmds = run_execute(mgmt)

        expect(cmds).to include("ip route replace default via '172.20.128.1' dev 'eth0' table 1000")
    end

    it 'should create the VRF before it enslaves the NIC and routes in it' do
        cmds = run_execute(mgmt)

        expect(cmds.index { |c| c.include?('type vrf') }).to be < cmds.index { |c| c.include?('master') }
        expect(cmds.index { |c| c.include?('master') }).to be < cmds.index { |c| c.include?('ip route') }
    end

    it 'should let listeners in the default VRF accept connections on the management NIC' do
        run_execute(mgmt)

        expect(@sysctl).to include('net.ipv4.tcp_l3mdev_accept = 1')
        expect(@sysctl).to include('net.ipv4.udp_l3mdev_accept = 1')
    end

    it 'should do nothing without a NIC marked as management' do
        cmds = run_execute('ETH0_IP' => '172.20.128.210', 'ETH0_GATEWAY' => '172.20.128.1')

        expect(cmds).to be_empty
        expect(@sysctl).to be_nil
    end

    it 'should do nothing when the NIC is explicitly not management' do
        cmds = run_execute(mgmt.merge('ETH0_VROUTER_MANAGEMENT' => 'NO'))

        expect(cmds).to be_empty
    end

    it 'should do nothing when disabled' do
        cmds = run_execute(mgmt.merge('ONEAPP_VNF_MGMT_VRF_ENABLED' => 'NO'))

        expect(cmds).to be_empty
        expect(@sysctl).to be_nil
    end

    it 'should move the NIC but add no route without a gateway' do
        cmds = run_execute(mgmt.reject { |k, _| k == 'ETH0_GATEWAY' })

        expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
        expect(cmds.grep(/ip route/)).to be_empty
    end

    it 'should move every management NIC into the same VRF' do
        cmds = run_execute(mgmt.merge('ETH2_VROUTER_MANAGEMENT' => 'YES', 'ETH2_GATEWAY' => '10.0.0.1'))

        expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
        expect(cmds).to include("ip link set 'eth2' master 'mgmt'")
        expect(cmds.count("ip link add 'mgmt' type vrf table 1000")).to eq 1
    end

    it 'should leave a NIC that is not marked outside the VRF' do
        cmds = run_execute(mgmt.merge('ETH1_IP' => '100.126.128.43', 'ETH1_GATEWAY' => '100.126.128.1'))

        expect(cmds.grep(/eth1/).grep(/master|table/)).to be_empty
    end

    [
        '1.2.3.4; reboot', '1.2.3.4 -j ACCEPT', '$(id)', '`id`', "1.2.3.4\nfoo",
        '999.1.1.1', '1.2.3', '01.2.3.4', '1.2.3.4.5', '2001:db8::1'
    ].each do |bad|
        it "should reject the gateway #{bad.inspect}, keep the NIC move and add no route" do
            cmds = run_execute(mgmt.merge('ETH0_GATEWAY' => bad))

            expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
            expect(cmds.grep(/ip route/)).to be_empty
            expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '999')
            expect(@errors.join).to include('eth0')
        end
    end

    # NOTE: Moving a NIC into a VRF flushes its IPv6 addresses and routes, so they must be put back
    #       (inside the VRF table), the same way one-context applies them.
    describe 'IPv6' do
        let(:mgmt6) { mgmt.merge('ETH0_IP6' => 'fd00:128::210', 'ETH0_GATEWAY6' => 'fec0::2') }

        it 'should put the static IPv6 address back after the NIC moved, with a /64 by default' do
            cmds = run_execute(mgmt6)

            expect(cmds).to include("ip -6 addr replace 'fd00:128::210/64' dev 'eth0'")
        end

        it 'should use the configured prefix length' do
            cmds = run_execute(mgmt6.merge('ETH0_IP6_PREFIX_LENGTH' => '48'))

            expect(cmds).to include("ip -6 addr replace 'fd00:128::210/48' dev 'eth0'")
        end

        it 'should accept ETH<n>_IPV6 as the alias of ETH<n>_IP6' do
            cmds = run_execute(mgmt.merge('ETH0_IPV6' => 'fd00:128::211'))

            expect(cmds).to include("ip -6 addr replace 'fd00:128::211/64' dev 'eth0'")
        end

        it 'should put the ULA address back as a /64' do
            cmds = run_execute(mgmt6.merge('ETH0_IP6_ULA' => 'fd12:3456::210', 'ETH0_IP6_PREFIX_LENGTH' => '48'))

            expect(cmds).to include("ip -6 addr replace 'fd12:3456::210/64' dev 'eth0'")
        end

        it 'should put the IPv6 default route into the VRF table' do
            cmds = run_execute(mgmt6)

            expect(cmds).to include("ip -6 route replace default via 'fec0::2' dev 'eth0' onlink table 1000")
        end

        it 'should prefer ETH<n>_IP6_GATEWAY over ETH<n>_GATEWAY6' do
            cmds = run_execute(mgmt6.merge('ETH0_IP6_GATEWAY' => 'fec0::3'))

            expect(cmds).to include("ip -6 route replace default via 'fec0::3' dev 'eth0' onlink table 1000")
            expect(cmds.grep(/fec0::2/)).to be_empty
        end

        it 'should accept a link-local gateway' do
            cmds = run_execute(mgmt6.merge('ETH0_GATEWAY6' => 'fe80::1'))

            expect(cmds).to include("ip -6 route replace default via 'fe80::1' dev 'eth0' onlink table 1000")
        end

        it 'should move the NIC, then restore the address, then add the route' do
            cmds = run_execute(mgmt6)

            master = cmds.index { |c| c.include?('master') }
            addr   = cmds.index { |c| c.start_with?('ip -6 addr') }
            route  = cmds.index { |c| c.start_with?('ip -6 route') }

            expect(master).to be < addr
            expect(addr).to be < route
        end

        it 'should leave IPv6 alone when the NIC has no IPv6 configuration' do
            expect(run_execute(mgmt).grep(/ip -6/)).to be_empty
        end

        it 'should not touch the IPv6 configuration of a NIC that is not marked' do
            cmds = run_execute(mgmt6.merge('ETH1_IP6' => 'fd00:129::1', 'ETH1_GATEWAY6' => 'fec1::2'))

            expect(cmds.grep(/eth1/)).to be_empty
        end

        [
            'fd00::1; reboot', 'fd00::1 -j ACCEPT', '$(id)', '`id`', "fd00::1\nfoo",
            'fe80::1%eth0', '1.2.3.4', 'zzzz::1', ':::', '12345::1', 'fd00::1/64'
        ].each do |bad|
            it "should reject the address #{bad.inspect} and add no IPv6 address" do
                cmds = run_execute(mgmt6.merge('ETH0_IP6' => bad))

                expect(cmds.grep(/ip -6 addr/)).to be_empty
                expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
                expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '%eth0')
                expect(@errors.join).to include('eth0')
            end

            it "should reject the IPv6 gateway #{bad.inspect} and add no IPv6 route" do
                cmds = run_execute(mgmt6.merge('ETH0_GATEWAY6' => bad))

                expect(cmds.grep(/ip -6 route/)).to be_empty
                expect(cmds).to include("ip link set 'eth0' master 'mgmt'")
                expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '%eth0')
                expect(@errors.join).to include('eth0')
            end
        end

        %w[0 129 -1 abc 64;reboot 6.4].each do |bad|
            it "should reject the prefix length #{bad.inspect} and add no IPv6 address" do
                cmds = run_execute(mgmt6.merge('ETH0_IP6_PREFIX_LENGTH' => bad))

                expect(cmds.grep(/ip -6 addr/)).to be_empty
                expect(@scripts.join).not_to include('reboot')
                expect(@errors.join).to include('eth0')
            end
        end
    end

    # NOTE: The default VRF cannot reach hosts behind the management NIC any more, but the appliance talks to
    #       OneGate from the default VRF, so a policy rule sends the traffic for the OneGate address to the VRF table.
    describe 'OneGate' do
        it 'should route the OneGate IPv4 address through the VRF table' do
            cmds = run_execute(mgmt.merge('ONEGATE_ENDPOINT' => 'http://10.0.2.2:5030'))

            expect(cmds).to include("ip rule add pref 100 to '10.0.2.2/32' lookup 1000")
        end

        it 'should route the OneGate IPv6 address through the VRF table' do
            cmds = run_execute(mgmt.merge('ONEGATE_ENDPOINT' => 'http://[fd00::1]:5030'))

            expect(cmds).to include("ip -6 rule add pref 100 to 'fd00::1/128' lookup 1000")
        end

        it 'should remove a former rule first so that running twice does not pile up rules' do
            cmds = run_execute(mgmt.merge('ONEGATE_ENDPOINT' => 'http://10.0.2.2:5030'))

            del = cmds.index { |c| c.start_with?("ip rule del pref 100 to '10.0.2.2/32' lookup 1000") }
            add = cmds.index { |c| c.start_with?("ip rule add") }

            expect(del).not_to be_nil
            expect(del).to be < add
        end

        it 'should add the rule after the NIC moved into the VRF' do
            cmds = run_execute(mgmt.merge('ONEGATE_ENDPOINT' => 'http://10.0.2.2:5030'))

            expect(cmds.index { |c| c.include?('master') }).to be < cmds.index { |c| c.start_with?('ip rule add') }
        end

        it 'should add no rule without a OneGate endpoint' do
            expect(run_execute(mgmt).grep(/ip (-6 )?rule/)).to be_empty
        end

        ['http://onegate.example.com:5030', 'http://10.0.2.2;reboot:5030', 'http://999.1.1.1:5030', 'not a uri', 'http://[fd00::1%25eth0]:5030'].each do |bad|
            it "should add no rule for the endpoint #{bad.inspect}" do
                cmds = run_execute(mgmt.merge('ONEGATE_ENDPOINT' => bad))

                expect(cmds.grep(/ip (-6 )?rule/)).to be_empty
                expect(@scripts.join).not_to include('reboot')
            end
        end
    end

    # NOTE: one-context adds the default route of every NIC with `ip route add`, so the first NIC wins and
    #       the gateways of the others are never installed. Once the gateway of the management NIC is in
    #       the VRF, the gateways of the other NICs are applied the way one-context would have done it.
    describe 'gateways of the other NICs' do
        let(:other) { mgmt.merge('ETH1_IP' => '198.51.100.2', 'ETH1_GATEWAY' => '198.51.100.1') }

        it 'should apply the gateway of a NIC that is not management in the main table' do
            cmds = run_execute(other)

            expect(cmds).to include("ip route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '198.51.100.1' dev 'eth1' 2>/dev/null ||:")
        end

        it 'should add a gateway only when the NIC has no default route yet' do
            cmds = run_execute(other)

            expect(cmds.grep(/198\.51\.100\.1/)).to eq(["ip route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '198.51.100.1' dev 'eth1' 2>/dev/null ||:"])
        end

        it 'should not add a default route for a management NIC without a gateway' do
            cmds = run_execute('ETH0_VROUTER_MANAGEMENT' => 'YES', 'ETH0_IP' => '172.20.128.210', 'ETH1_IP' => '198.51.100.2', 'ETH1_GATEWAY' => '198.51.100.1')

            expect(cmds.grep(/table 1000/).grep(/default/)).to be_empty
        end

        it 'should keep the gateway of the management NIC in the VRF table only' do
            cmds = run_execute(other)

            expect(cmds).to include("ip route replace default via '172.20.128.1' dev 'eth0' table 1000")
            expect(cmds.grep(/172\.20\.128\.1/).grep_v(/table 1000/)).to be_empty
            expect(cmds.grep(/198\.51\.100\.1/).grep(/table/)).to be_empty
        end

        it 'should apply it after the management NIC moved into the VRF' do
            cmds = run_execute(other)

            expect(cmds.index { |c| c.include?('master') }).to be < cmds.index { |c| c.include?("dev 'eth1'") }
        end

        it 'should honor the metric of the NIC' do
            cmds = run_execute(other.merge('ETH1_METRIC' => '20'))

            expect(cmds).to include("ip route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '198.51.100.1' dev 'eth1' metric 20 2>/dev/null ||:")
        end

        it 'should apply the gateways of several NICs in the order of their index' do
            cmds = run_execute(other.merge('ETH2_IP' => '10.10.0.2', 'ETH2_GATEWAY' => '10.10.0.1', 'ETH2_METRIC' => '50'))

            first  = cmds.index { |c| c.include?("dev 'eth1'") }
            second = cmds.index { |c| c.include?("dev 'eth2'") }

            expect(first).to be < second
        end

        it 'should apply the IPv6 gateway of a NIC that is not management in the main table' do
            cmds = run_execute(other.merge('ETH1_IP6' => 'fd00:129::2', 'ETH1_GATEWAY6' => 'fd00:129::1'))

            expect(cmds).to include("ip -6 route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip -6 route add default via 'fd00:129::1' dev 'eth1' 2>/dev/null ||:")
        end

        it 'should prefer ETH<n>_IP6_GATEWAY over ETH<n>_GATEWAY6' do
            cmds = run_execute(other.merge('ETH1_GATEWAY6' => 'fd00:129::1', 'ETH1_IP6_GATEWAY' => 'fd00:129::5'))

            expect(cmds).to include("ip -6 route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip -6 route add default via 'fd00:129::5' dev 'eth1' 2>/dev/null ||:")
            expect(cmds.grep(/fd00:129::1'/)).to be_empty
        end

        it 'should touch nothing of a NIC without a gateway' do
            cmds = run_execute(mgmt.merge('ETH1_IP' => '198.51.100.2'))

            expect(cmds.grep(/eth1/)).to be_empty
        end

        it 'should do nothing for the other NICs without a management NIC' do
            cmds = run_execute(other.reject { |k, _| k == 'ETH0_VROUTER_MANAGEMENT' })

            expect(cmds).to be_empty
        end

        it 'should do nothing for the other NICs when disabled' do
            expect(run_execute(other.merge('ONEAPP_VNF_MGMT_VRF_ENABLED' => 'NO'))).to be_empty
        end

        [
            '1.2.3.4; reboot', '1.2.3.4 -j ACCEPT', '$(id)', '`id`', "1.2.3.4\nfoo", '999.1.1.1', '01.2.3.4', '2001:db8::1'
        ].each do |bad|
            it "should reject the gateway #{bad.inspect} of another NIC" do
                cmds = run_execute(other.merge('ETH1_GATEWAY' => bad))

                expect(cmds.grep(/dev 'eth1'/)).to be_empty
                expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '999')
                expect(@errors.join).to include('eth1')
            end

            next if bad == '2001:db8::1' # a valid IPv6 address

            it "should reject the IPv6 gateway #{bad.inspect} of another NIC" do
                cmds = run_execute(other.merge('ETH1_GATEWAY6' => bad))

                expect(cmds.grep(/ip -6 route add/)).to be_empty
                expect(@scripts.join).not_to include('reboot', 'ACCEPT', '$(id)', '`id`', 'foo', '999')
                expect(@errors.join).to include('eth1')
            end
        end

        %w[abc -1 5;reboot 1.5 1234567890123].each do |bad|
            it "should reject the metric #{bad.inspect} and add no route for the NIC" do
                cmds = run_execute(other.merge('ETH1_METRIC' => bad))

                expect(cmds.grep(/ip route add/)).to be_empty
                expect(@scripts.join).not_to include('reboot')
                expect(@errors.join).to include('eth1')
            end
        end
    end

    describe 'static routes of the management NIC' do
        let(:routed) { mgmt.merge('ETH0_ROUTES' => '10.50.0.0/16 via 172.20.128.254, 192.0.2.7 via 172.20.128.253') }

        it 'should put them into the VRF table' do
            cmds = run_execute(routed)

            expect(cmds).to include("ip route replace '10.50.0.0/16' via '172.20.128.254' dev 'eth0' table 1000")
            expect(cmds).to include("ip route replace '192.0.2.7' via '172.20.128.253' dev 'eth0' table 1000")
        end

        it 'should add them after the NIC moved into the VRF' do
            cmds = run_execute(routed)

            expect(cmds.index { |c| c.include?('master') }).to be < cmds.index { |c| c.include?("'10.50.0.0/16'") }
        end

        it 'should not touch the main table for them' do
            cmds = run_execute(routed)

            expect(cmds.grep(/10\.50\.0\.0/).grep_v(/table 1000/)).to be_empty
        end

        it 'should add nothing without ETH0_ROUTES' do
            expect(run_execute(mgmt).grep(/replace '/)).to be_empty
        end

        it 'should skip an invalid entry, log it and keep the others' do
            cmds = run_execute(mgmt.merge('ETH0_ROUTES' => "10.50.0.0/16 via 1.1.1.1; reboot, 10.60.0.0/33 via 1.1.1.1, bogus, 10.70.0.0/24 via 172.20.128.254"))

            expect(cmds.grep(/replace '/)).to eq(["ip route replace '10.70.0.0/24' via '172.20.128.254' dev 'eth0' table 1000"])
            expect(@errors.grep(/invalid ETH0_ROUTES entry/).size).to eq(3)
        end

        it 'should leave the routes of a NIC that is not management alone' do
            cmds = run_execute(mgmt.merge('ETH1_IP' => '198.51.100.2', 'ETH1_ROUTES' => '10.80.0.0/16 via 198.51.100.254'))

            expect(cmds.grep(/10\.80/)).to be_empty
        end
    end

    describe 'cleanup' do
        def run_cleanup(env = {})
            clear_env
            ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'
            env.each { |k, v| ENV[k] = v }

            load './main.rb'; include Service::MgmtVRF

            scripts = @scripts = []
            allow(Service::MgmtVRF).to receive(:bash) { |script| scripts << script; '' }
            allow(Service::MgmtVRF).to receive(:toggle)
            allow(Service::MgmtVRF).to receive(:msg)

            Dir.mktmpdir do |dir|
                File.write("#{dir}/97-MgmtVRF.conf", 'x')
                Service::MgmtVRF.cleanup basedir: dir
                @conf_left = File.exist?("#{dir}/97-MgmtVRF.conf")
            end

            @scripts.flat_map(&:lines).map(&:strip).reject(&:empty?)
        end

        it 'should delete the VRF, which releases its NICs' do
            expect(run_cleanup).to include("ip link del 'mgmt'")
        end

        it 'should delete the OneGate rule' do
            cmds = run_cleanup('ONEGATE_ENDPOINT' => 'http://10.0.2.2:5030')

            expect(cmds).to include("ip rule del pref 100 to '10.0.2.2/32' lookup 1000 2>/dev/null ||:")
        end

        it 'should remove the sysctl file' do
            run_cleanup

            expect(@conf_left).to be false
        end

        it 'should give the default route of the management NIC back to the main table' do
            cmds = run_cleanup('ETH0_GATEWAY' => '172.20.128.1')

            expect(cmds).to include("ip route show dev 'eth0' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '172.20.128.1' dev 'eth0' 2>/dev/null ||:")
        end

        it 'should keep the metric of the NIC' do
            cmds = run_cleanup('ETH0_GATEWAY' => '172.20.128.1', 'ETH0_METRIC' => '20')

            expect(cmds).to include("ip route show dev 'eth0' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '172.20.128.1' dev 'eth0' metric 20 2>/dev/null ||:")
        end

        it 'should give the static routes back to the main table' do
            cmds = run_cleanup('ETH0_ROUTES' => '10.50.0.0/16 via 172.20.128.254')

            expect(cmds).to include("ip route replace '10.50.0.0/16' via '172.20.128.254' dev 'eth0'")
        end

        it 'should give the IPv6 default route and addresses back' do
            cmds = run_cleanup('ETH0_IP6' => '2001:db8::10', 'ETH0_IP6_GATEWAY' => '2001:db8::1')

            expect(cmds).to include("ip -6 addr replace '2001:db8::10/64' dev 'eth0'")
            expect(cmds).to include("ip -6 route show dev 'eth0' 2>/dev/null | grep '^default' >/dev/null || ip -6 route add default via '2001:db8::1' dev 'eth0' onlink 2>/dev/null ||:")
        end

        it 'should restore the routes only after the VRF was deleted' do
            cmds = run_cleanup('ETH0_GATEWAY' => '172.20.128.1', 'ETH0_ROUTES' => '10.50.0.0/16 via 172.20.128.254')

            expect(cmds.index { |c| c.include?('ip link del') }).to be < cmds.index { |c| c.include?('ip route') }
        end

        it 'should give the default routes of the other NICs back where they are missing' do
            cmds = run_cleanup('ETH1_IP' => '198.51.100.2', 'ETH1_GATEWAY' => '198.51.100.1', 'ETH1_METRIC' => '5',
                               'ETH1_IP6_GATEWAY' => 'fd00:129::1')

            expect(cmds).to include("ip route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip route add default via '198.51.100.1' dev 'eth1' metric 5 2>/dev/null ||:")
            expect(cmds).to include("ip -6 route show dev 'eth1' 2>/dev/null | grep '^default' >/dev/null || ip -6 route add default via 'fd00:129::1' dev 'eth1' 2>/dev/null ||:")
        end

        it 'should only add a default route when the NIC has none' do
            cmds = run_cleanup('ETH0_GATEWAY' => '172.20.128.1')

            expect(cmds.grep(/172\.20\.128\.1/).first).to start_with("ip route show dev 'eth0' 2>/dev/null | grep '^default' >/dev/null || ")
        end

        it 'should add no route without a gateway or routes' do
            expect(run_cleanup.grep(/ip (-6 )?route/)).to be_empty
        end

        it 'should do nothing about routes without a management NIC' do
            clear_env
            load './main.rb'; include Service::MgmtVRF
            scripts = []
            allow(Service::MgmtVRF).to receive(:bash) { |script| scripts << script; '' }
            allow(Service::MgmtVRF).to receive(:msg)
            Dir.mktmpdir { |dir| Service::MgmtVRF.cleanup basedir: dir }

            expect(scripts.join).not_to match(/ip (-6 )?route/)
        end
    end

    # The bash helper runs scripts with pipefail. A guard that ends in `grep -q` makes grep leave at the first
    # match, ip then gets SIGPIPE while it still writes, and the pipeline fails although a default exists.
    describe 'the default route guard under pipefail' do
        def guard_output(routes)
            ip = <<~SH
                ip() { case "$*" in *show*) #{routes};; *) echo ADDED;; esac; }
            SH
            guard = Service::MgmtVRF.send(:default_if_missing, 'eth1', '198.51.100.1')

            IO.popen(['/bin/bash', '-c', "set -o errexit -o nounset -o pipefail\n#{ip}#{guard}"], err: File::NULL, &:read)
        end

        it 'does not add a route when a default exists and the dump is long' do
            expect(guard_output("echo 'default via 198.51.100.1 metric 1 onlink'; seq 1 100000")).not_to include('ADDED')
        end

        it 'does not add a route when the default is the only line' do
            expect(guard_output("echo 'default via 198.51.100.1 metric 1 onlink'")).not_to include('ADDED')
        end

        it 'adds the route when the NIC has no default' do
            expect(guard_output("echo '198.51.100.0/24 proto kernel scope link'")).to include('ADDED')
        end
    end
end
