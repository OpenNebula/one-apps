#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualNetwork hold/release functionality" do
    def test(xml, xpath, str)
        expect(xml[xpath]).to eq(str)
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:each) do
        @single_ip4 = <<-EOF
            NAME   = "sip4"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        @single_mac = <<-EOF
            NAME   = "smac"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="ETHER", SIZE="250", MAC="00:02:01:02:03:04" ]
        EOF

        @multi_ip4 = <<-EOF
            NAME   = "mip4"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
            AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        @multi_mac = <<-EOF
            NAME   = "mmac"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="ETHER", SIZE="250", MAC="00:02:01:02:03:04" ]
            AR = [ TYPE="ETHER", SIZE="250", MAC="00:02:01:02:03:04" ]
            AR = [ TYPE="ETHER", SIZE="250" ]
        EOF

        @single_ip6 = <<-EOF
            NAME   = "sip6"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="IP6_STATIC", SIZE="250", IP6="2001:0:0:a::1",
               PREFIX_LENGTH=48 ]
        EOF

        @multi_ip6 = <<-EOF
            NAME   = "mip6"
            BRIDGE = br0
            PHYDEV = eth0
            VLAN_ID= 13
            VN_MAD = 802.1Q
            AR = [ TYPE="IP6_STATIC", SIZE="250", IP6="2001:0:0:a::1",
                 PREFIX_LENGTH = 48 ]
            AR = [ TYPE="IP6_STATIC", SIZE="250", IP6="2001:0:1:a::1",
                 PREFIX_LENGTH = 48 ]
            AR = [ TYPE="IP6_STATIC", SIZE="250", IP6="2001:0:2:a::1",
                 PREFIX_LENGTH = 48 ]
        EOF

        @sip4_id = cli_create("onevnet create", @single_ip4)
        @mip4_id = cli_create("onevnet create", @multi_ip4)
        @smac_id = cli_create("onevnet create", @single_mac)
        @mmac_id = cli_create("onevnet create", @multi_mac)
        @sip6_id = cli_create("onevnet create", @single_ip6)
        @mip6_id = cli_create("onevnet create", @multi_ip6)

        net = VN.new(@mip6_id)
        net.ready?

        @vm_id = -1
    end

    after(:each) do
        if @vm_id != -1
            vm = VM.new(@vm_id)
            vm.terminate
        end

        cli_action("onevnet delete #{@sip4_id}")
        cli_action("onevnet delete #{@mip4_id}")
        cli_action("onevnet delete #{@smac_id}")
        cli_action("onevnet delete #{@mmac_id}")
        cli_action("onevnet delete #{@sip6_id}")

        net = VN.new(@mip6_id)
        net.delete
        net.deleted?
    end

    it "should get a any lease from a network (IP4 type)" do
        @vm_id = cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
                            " --nic sip4")
        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml, 'TEMPLATE/NIC/NETWORK', "sip4")
        test(vm_xml, 'TEMPLATE/NIC/IP', "192.168.0.1")
        test(vm_xml, 'TEMPLATE/NIC/AR_ID', "0")

        vnet_xml = cli_action_xml("onevnet show -x #{@sip4_id}")

        test(vnet_xml, 'USED_LEASES', "1")
        test(vnet_xml, 'AR_POOL/AR[AR_ID=0]/USED_LEASES', "1")
        test(vnet_xml, 'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/VM', "#{@vm_id}")
        test(vnet_xml, 'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/IP', "192.168.0.1")
    end

    it "should get a any lease from a network (MAC type)" do
        @vm_id = cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
                            " --nic smac")
        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml,'TEMPLATE/NIC/NETWORK',"smac")
        test(vm_xml,'TEMPLATE/NIC/IP',nil)
        test(vm_xml,'TEMPLATE/NIC/MAC',"00:02:01:02:03:04")
        test(vm_xml,'TEMPLATE/NIC/AR_ID',"0")

        vnet_xml = cli_action_xml("onevnet show -x #{@smac_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/VM',"#{@vm_id}")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/MAC',"00:02:01:02:03:04")
    end

    it "should get a any lease from a network (IP6 type)" do
        @vm_id = cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
                            " --nic sip6")
        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml, 'TEMPLATE/NIC/NETWORK', "sip6")
        test(vm_xml, 'TEMPLATE/NIC/IP6', "2001:0:0:a::1")
        test(vm_xml, 'TEMPLATE/NIC/AR_ID', "0")

        vnet_xml = cli_action_xml("onevnet show -x #{@sip6_id}")

        test(vnet_xml,'USED_LEASES', "1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/USED_LEASES', "1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/VM', "#{@vm_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/IP6',"2001:0:0:a::1")
    end

    it "should get a specific IP from a VNET" do
        @vm_id = cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
                            " --nic sip4:ip=192.168.0.23")
        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml,'TEMPLATE/NIC/NETWORK',"sip4")
        test(vm_xml,'TEMPLATE/NIC/IP',"192.168.0.23")
        test(vm_xml,'TEMPLATE/NIC/AR_ID',"0")

        vnet_xml = cli_action_xml("onevnet show -x #{@sip4_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/VM',"#{@vm_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=0]/LEASES/LEASE[1]/IP',"192.168.0.23")
    end

    it "should get a specific MAC from a VNET" do
        vm_str = <<-EOF
			NAME=vmtest
			CPU = 1
			MEMORY = 128
			NIC = [ NETWORK = "smac", MAC="00:02:01:02:03:94" ]
        EOF

        @vm_id = cli_create("onevm create", vm_str)
        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml,'TEMPLATE/NIC/NETWORK',"smac")
        test(vm_xml,'TEMPLATE/NIC/IP',nil)
        test(vm_xml,'TEMPLATE/NIC/MAC',"00:02:01:02:03:94")
        test(vm_xml,'TEMPLATE/NIC/AR_ID',"0")

        vnet_xml = cli_action_xml("onevnet show -x #{@smac_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/VM',"#{@vm_id}")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/MAC',"00:02:01:02:03:94")
    end

    it "should get a specific IP6 from a VNET" do
        vm_str = <<-EOF
			NAME=vmtest
			CPU = 1
			MEMORY = 128
			NIC = [ NETWORK = "mip6", IP6="2001:0:1:a::10" ]
        EOF
        @vm_id = cli_create("onevm create", vm_str)

        vm_xml = cli_action_xml("onevm show -x #{@vm_id}")

        test(vm_xml, 'TEMPLATE/NIC/NETWORK', "mip6")
        test(vm_xml,'TEMPLATE/NIC/IP',nil)
        test(vm_xml, 'TEMPLATE/NIC/IP6', "2001:0:1:a::10")
        test(vm_xml, 'TEMPLATE/NIC/AR_ID', "1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip6_id}")

        test(vnet_xml,'USED_LEASES', "1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/USED_LEASES', "1")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/LEASES/LEASE[1]/VM', "#{@vm_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/LEASES/LEASE[1]/IP6',"2001:0:1:a::10")
    end

    it "should fail to get a specific IP out of range from a VNET" do
        cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
				   " --nic sip4:ip=192.168.0.253", nil, false)

        cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
				   " --nic sip6:ip6=2001:f:0:a::1", nil, false)
    end

    it "should fail to get a specific MAC out of range from a VNET" do
        vm_str = <<-EOF
			NAME=vmtest
			CPU = 1
			MEMORY = 128
			NIC = [ NETWORK = "smac", MAC="00:02:01:02:03:fe" ]
        EOF

        cli_create("onevm create", vm_str, false)
    end

    it "should hold a specific IP from a VNET, fail if trying to acquire it and release it" do
        cli_action("onevnet hold #{@mip4_id} 10.0.0.3 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip4_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/IP',"10.0.0.3")

        cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
				   " --nic mip4:ip=10.0.0.3", nil, false)

        cli_action("onevnet release #{@mip4_id} 10.0.0.3 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip4_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/USED_LEASES',"0")
    end

    it "should hold a specific IP6 from a VNET, fail if trying to acquire it and release it" do
        cli_action("onevnet hold #{@mip6_id} 2001:0:1:a::10 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip6_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/IP6',"2001:0:1:a::10")

        cli_create("onevm create --name vmtest --cpu 1 --memory 128"\
				   " --nic mip4:ip6=2001:0:1:a::10", nil, false)

        cli_action("onevnet release #{@mip6_id} 2001:0:1:a::10 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip6_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/USED_LEASES',"0")
    end

    it "should hold a specific MAC from a VNET and release it" do
        cli_action("onevnet hold #{@mmac_id} 00:02:01:02:03:94 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mmac_id}")

        test(vnet_xml,'USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/MAC',"00:02:01:02:03:94")

        cli_action("onevnet release #{@mmac_id} 00:02:01:02:03:94 -a 1")

        vnet_xml = cli_action_xml("onevnet show -x #{@mmac_id}")
        test(vnet_xml,'AR_POOL/AR[AR_ID=1]/USED_LEASES',"0")
    end

    it "should hold a specific IP from all ARs in VNET and release all" do
        cli_action("onevnet hold #{@mip4_id} 192.168.0.16")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip4_id}")

        test(vnet_xml,'USED_LEASES',"2")
        test(vnet_xml,'AR_POOL/AR[1]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/IP',"192.168.0.16")
        test(vnet_xml,'AR_POOL/AR[3]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[3]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[3]/LEASES/LEASE[1]/IP',"192.168.0.16")

        cli_action("onevnet release #{@mip4_id} 192.168.0.16")

        vnet_xml = cli_action_xml("onevnet show -x #{@mip4_id}")

        test(vnet_xml,'USED_LEASES',"0")
    end

    it "should hold a specific MAC from all ARs in a VNET and release all" do
        cli_action("onevnet hold #{@mmac_id} 00:02:01:02:03:37")

        vnet_xml = cli_action_xml("onevnet show -x #{@mmac_id}")

        test(vnet_xml,'USED_LEASES',"2")
        test(vnet_xml,'AR_POOL/AR[1]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[1]/LEASES/LEASE[1]/MAC',"00:02:01:02:03:37")
        test(vnet_xml,'AR_POOL/AR[2]/USED_LEASES',"1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/VM',"-1")
        test(vnet_xml,'AR_POOL/AR[2]/LEASES/LEASE[1]/MAC',"00:02:01:02:03:37")

        cli_action("onevnet release #{@mmac_id} 00:02:01:02:03:37")

        vnet_xml = cli_action_xml("onevnet show -x #{@mmac_id}")

        test(vnet_xml,'USED_LEASES',"0")
    end
end

