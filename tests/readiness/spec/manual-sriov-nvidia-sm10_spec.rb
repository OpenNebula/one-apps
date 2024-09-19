require 'init'

RSpec.describe 'SR-IOV NVIDIA attach test' do

    before(:all) do
        @info     = {}
        @defaults = RSpec.configuration.defaults

        # Create Virtual Network
        template=<<-EOF
            NAME=sriov-nvidia-net
            BRIDGE="onebr98121"
            BRIDGE_TYPE="linux"
            PHYDEV="tap0"
            SECURITY_GROUPS="0"
            VLAN="YES"
            VLAN_ID="3984"
            VN_MAD="802.1Q"
            AR = [ TYPE="IP4", SIZE="10", IP="192.168.150.220" ]
        EOF

        @info[:vn_id] = cli_create('onevnet create', template)

        template=<<-EOF
            NAME   = "sriov-nvidia"
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
            NIC=[
              NETWORK="sriov-nvidia-net"
            ]
            NIC_DEFAULT=[
              MODEL="virtio"
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

    it 'creates a running VM with device 41:00.4 attached' do
        device = '41:00.4'
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@info[:tmp_id]}' --raw='PCI=[ SHORT_ADDRESS=\"#{device}\" ] HOST=\"10.0.0.120\"'")
        @info[:vm] = VM.new(@info[:vm_id] )
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'check if the device has been added' do
       check_pci=@info[:vm].ssh('lspci')
       expect(check_pci.stdout).to match(/^[0-9]{2}:[0-9]{2}\.[0-9] Class 0300: 10de:[0-9]{4}$/)
    end
end

