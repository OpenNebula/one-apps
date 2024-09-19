require 'init'

# ------------------------------------------------------------------------------
# Test the Virtual Network Update for PCI-SRIOV
# ------------------------------------------------------------------------------
#
# This test can be run in any kvm front-end. Configuration:
#   - [SM12] Make sure vf's are defined (ip link | grep vf), if not:
#      cd /sys//devices/pci0000:40/0000:40:01.4/0000:44:00.1/net/enp68s0f1/device
#      echo 8 > sriov_numvfs
#   - [SM12] onehost offline localhost and rm -rf /var/tmp/one
#   - [SM12] Add the public key of oneadmin account to sm12 oneadmin
#   - [MICROENV - FE] Update default and system datastore to use ssh if needed
#   - [MICROENV - FE] Add 172.20.0.1 as host
#   - [MICROENV - FE] Run the test (may need to sudo gem install rspec)
#         cd /var/lib/one/readiness
#         cp ../defaults.yaml .
#         rspec spec/manual-sriov-update-sm12_spec.rb
# ------------------------------------------------------------------------------

RSpec.describe 'SR-IOV NIC update' do

    def check_vf
      host = Host.new('172.20.0.1')

        cmd = "ip link | grep 'vf 0'"

        rc = host.ssh(cmd, false, {}, 'oneadmin')

        m = rc.stdout.match(/vlan ([0-9]+), spoof checking ([onf]+), link-state auto, trust ([onf]+)/)

        return "", "", "" if m.nil?

        return m[1], m[2], m[3]
    end

    before(:all) do
        @info     = {}
        @defaults = RSpec.configuration.defaults

        # Create Virtual Network
        template=<<-EOF
            NAME   = "sriov"
            BRIDGE = "br_sriov"

            PHYDEV = "tap0"

            SPOOFCHK = "YES"
            TRUST    = "YES"
            VLAN_ID  = "725"
            VN_MAD   = "802.1Q"

            AR      = [ TYPE="IP4", SIZE="50", IP="192.168.151.1" ]
        EOF

        @info[:vn_id] = cli_create('onevnet create', template)

        template=<<-EOF
            NAME   = "sriov"
            CPU    = "1.0"
            MEMORY = "512"

            ARCH = "x86_64"

            CONTEXT = [
              NETWORK="YES",
              SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]"
            ]

            DISK = [
              IMAGE="alpine"
            ]

            PCI = [
              NETWORK="sriov",
              SHORT_ADDRESS="44:0a.0",
              TYPE="NIC"
            ]
        EOF

        @info[:tmp_id] = cli_create('onetemplate create', template)
    end

    after(:all) do
        @info[:vm].terminate_hard
        @info[:vm].done?

        cli_action("onetemplate delete #{@info[:tmp_id]}")
        cli_action("onevnet delete #{@info[:vn_id]}")
    end

    it 'creates a running VM' do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@info[:tmp_id]}'")

        @info[:vm] = VM.new(@info[:vm_id] )

        @info[:vm].running?

        v, s, t = check_vf

        expect(v).to eq '725'

        expect(s).to eq 'on'

        expect(t).to eq 'on'
    end

    it 'Update VLAN_ID, SPOOFCHK and TRUST ' do
        template = <<-EOF
            VLAN_ID = "836"

            SPOOFCHK = "NO"
            TRUST    = "NO"
        EOF

        cli_update("onevnet update #{@info[:vn_id]}", template, true)

        wait_loop(:timeout => 60) {
            xml = cli_action_xml("onevnet show -x #{@info[:vn_id]}")

            xml['OUTDATED_VMS'].empty? && xml['UPDATING_VMS'].empty? && xml['ERROR_VMS'].empty?
        }

        v, s, t = check_vf

        expect(v).to eq '836'

        expect(s).to eq 'off'

        expect(t).to eq 'off'
    end
end
