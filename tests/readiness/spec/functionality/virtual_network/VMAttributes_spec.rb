#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualNetwork attributes test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        template=<<-EOF
         NAME   = "sip4"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = 802.1Q
         VLAN_ID= 13
         DNS    = "8.8.8.8"
         GATEWAY= "1.1.1.1"
         VLAN_TAGGED_ID = 12
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1", DNS="9.9.9.9",
                NETWORK_ADDRESS="192.168.0.0", VLAN_TAGGED_ID="57" ]
         AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1", VLAN_ID="17", PHYDEV=eth1]
        EOF

        vn = VN.create(template)
        @ip4_id = vn.id

        vn.ready?

        @hid = cli_create("onehost create host01 -i dummy -v dummy")

        cli_create_user("userA", "abc")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create a NIC & CONTEXT with VNET & AR configuration attributes" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "sip4" ]
         CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK']).to eq("sip4")
        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to eq("192.168.0.1")
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to eq("eth0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_ID']).to eq("13")
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_TAGGED_ID']).to eq("57")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq("9.9.9.9")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq("1.1.1.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq("192.168.0.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_NETWORK']).to eq("192.168.0.0")
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")
    end

    it "should create a NIC with VNET & AR configuration attributes" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "sip4", IP="10.0.0.2" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK']).to eq("sip4")
        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to eq("10.0.0.2")
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to eq("eth1")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_ID']).to eq("17")
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to eq("1")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_TAGGED_ID']).to eq("12")
    end

    it "should create a VNET and generate the VLAN_ID" do
        template=<<-EOF
         NAME   = "vlannet"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = 802.1Q
         AUTOMATIC_VLAN_ID= "YES"
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['VLAN_ID_AUTOMATIC']).to eq("1")
        expect(vnet_xml['VLAN_ID']).to eq("3")

        expect(vnet_xml['OUTER_VLAN_ID_AUTOMATIC']).to eq("0")
        expect(vnet_xml['OUTER_VLAN_ID']).to eq("")

        vn.delete
    end

    it "should create a VNET and generate the VLAN_ID & OUTER_VLAN_ID" do
        template=<<-EOF
         NAME   = "vlannet2"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = "ovswitch_vxlan"
         AUTOMATIC_VLAN_ID= "YES"
         AUTOMATIC_OUTER_VLAN_ID= "YES"
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['VLAN_ID_AUTOMATIC']).to eq("1")
        expect(vnet_xml['VLAN_ID']).to eq("4")

        expect(vnet_xml['OUTER_VLAN_ID_AUTOMATIC']).to eq("1")
        expect(vnet_xml['OUTER_VLAN_ID']).to eq("4")

        vn.delete
    end

    it "should create a VNET and fix VLAN_ID & OUTER_VLAN_ID" do
        template=<<-EOF
         NAME   = "vlannet3"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = "ovswitch_vxlan"
         VLAN_ID = 13
         OUTER_VLAN_ID = 31
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['VLAN_ID_AUTOMATIC']).to eq("0")
        expect(vnet_xml['VLAN_ID']).to eq("13")

        expect(vnet_xml['OUTER_VLAN_ID_AUTOMATIC']).to eq("0")
        expect(vnet_xml['OUTER_VLAN_ID']).to eq("31")

        vn.delete
    end

    it "should create a NIC & CONTEXT with VNET and NETWORK_MODE = auto" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK_MODE = "auto" ]
         CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_MODE']).to eq("auto")
        expect(vm_xml['TEMPLATE/NIC[1]/NIC_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_TAGGED_ID']).to be_nil

        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_DNS']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_IP']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_NETWORK']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")
    end

    it "should create a NIC & CONTEXT with VNET and NETWORK_MODE = auto and other without NETWORK_MODE" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "sip4", VIRTIO_QUEUES = 4 ]
         NIC    = [ NETWORK_MODE = "auto", VIRTIO_QUEUES = 8 ]
         CONTEXT= [ NETWORK = "YES", VIRTIO_QUEUES = "$NIC[VIRTIO_QUEUES, NETWORK_MODE=\\\"auto\\\"]" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK']).to eq("sip4")
        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to eq("192.168.0.2")
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to eq("eth0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_ID']).to eq("13")
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_TAGGED_ID']).to eq("57")
        expect(vm_xml['TEMPLATE/NIC[1]/VIRTIO_QUEUES']).to eq("4")

        expect(vm_xml['TEMPLATE/NIC[2]/NETWORK_MODE']).to eq("auto")
        expect(vm_xml['TEMPLATE/NIC[2]/NIC_ID']).to eq("1")
        expect(vm_xml['TEMPLATE/NIC[2]/IP']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/BRIDGE']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/PHYDEV']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/AR_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_TAGGED_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/VIRTIO_QUEUES']).to eq("8")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq("9.9.9.9")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq("1.1.1.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq("192.168.0.2")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_NETWORK']).to eq("192.168.0.0")
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")
        expect(vm_xml['TEMPLATE/CONTEXT/VIRTIO_QUEUES']).to eq("8")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_DNS']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_GATEWAY']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_IP']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_NETWORK']).to be_nil
    end

    it "should create a NIC & CONTEXT with VNET and NETWORK_MODE = auto and a user without networks" do

        as_user("userA") do
            template=<<-EOF
            NAME   = "vmtest"
            CPU    = 1
            MEMORY = 128
            NIC    = [ NETWORK_MODE = "auto" ]
            CONTEXT= [ NETWORK = "YES" ]
            EOF

            vm_id  = cli_create("onevm create", template)
            vm_xml = cli_action_xml("onevm show -x #{vm_id}")

            template=<<-EOF
            NAME   = "vmtest"
            CPU    = 1
            MEMORY = 128
            NIC    = [ NETWORK = "sip4" ]
            CONTEXT= [ NETWORK = "YES" ]
            EOF

            vm_id  = cli_create("onevm create", template, false)
        end
    end

    it "should deploy a VM with a NIC with NETWORK_MODE auto" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "sip4" ]
         NIC    = [ NETWORK_MODE = "auto" ]
         CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK']).to eq("sip4")
        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to eq("192.168.0.3")
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to eq("eth0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_ID']).to eq("13")
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/VLAN_TAGGED_ID']).to eq("57")

        expect(vm_xml['TEMPLATE/NIC[2]/NETWORK_MODE']).to eq("auto")
        expect(vm_xml['TEMPLATE/NIC[2]/NIC_ID']).to eq("1")
        expect(vm_xml['TEMPLATE/NIC[2]/IP']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/BRIDGE']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/PHYDEV']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/AR_ID']).to be_nil
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_TAGGED_ID']).to be_nil

        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq("9.9.9.9")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq("1.1.1.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq("192.168.0.3")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_NETWORK']).to eq("192.168.0.0")
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_DNS']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_GATEWAY']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_IP']).to be_nil
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_NETWORK']).to be_nil

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("4")

        template_deploy=<<-EOF
         NIC    = [ NIC_ID = 1, NETWORK_MODE = "auto", NETWORK_ID = #{@ip4_id} ]
        EOF

        file = Tempfile.new('extra_deploy')
        file << template_deploy
        file.flush

        cli_action("onevm deploy #{vm_id} #{@hid} -f #{file.path}")

        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[2]/NETWORK_MODE']).to eq("auto")
        expect(vm_xml['TEMPLATE/NIC[2]/NETWORK']).to eq("sip4")
        expect(vm_xml['TEMPLATE/NIC[2]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[2]/IP']).to eq("192.168.0.4")
        expect(vm_xml['TEMPLATE/NIC[2]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[2]/PHYDEV']).to eq("eth0")
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_ID']).to eq("13")
        expect(vm_xml['TEMPLATE/NIC[2]/AR_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[2]/VLAN_TAGGED_ID']).to eq("57")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_DNS']).to eq("9.9.9.9")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_GATEWAY']).to eq("1.1.1.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_IP']).to eq("192.168.0.4")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_NETWORK']).to eq("192.168.0.0")
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("5")
    end

    it "should deploy a VM with a NIC with NETWORK_MODE auto" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "sip4" ]
         NIC    = [ NETWORK_MODE = "auto" ]
         CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("6")

        template_deploy=<<-EOF
         NIC    = [ NIC_ID = 1, NETWORK_MODE = "auto", NETWORK_ID = #{@ip4_id} ]
        EOF

        file = Tempfile.new('extra_deploy')
        file << template_deploy
        file.flush

        cli_action("onevm deploy #{vm_id} #{@hid} -f #{file.path}")

        vm = VM.new(vm_id)

        vm.running?

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("7")

        cli_action("onevm undeploy #{vm_id}")

        vm.undeployed?

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("7")

        cli_action("onevm deploy #{vm_id} #{@hid} -f #{file.path}")

        vnet_xml = cli_action_xml("onevnet show sip4 -x")

        expect(vnet_xml["USED_LEASES"]).to eq("7")
    end

end
