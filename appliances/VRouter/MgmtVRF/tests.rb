# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
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

        expect(cmds.grep(/eth1/)).to be_empty
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

    describe 'cleanup' do
        def run_cleanup
            clear_env
            ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

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

        it 'should remove the sysctl file' do
            run_cleanup

            expect(@conf_left).to be false
        end
    end
end
