#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualNetwork operations test" do
    def build_vnet
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        template=<<-EOF
         NAME   = "net1"
         BRIDGE = br0
         VN_MAD = dummy
         VLAN_ID= 15
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        @vnet_id1 = cli_create("onevnet create", template)

        template=<<-EOF
         NAME   = "net2"
         BRIDGE = br1
         VN_MAD = fw
         AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
        EOF

        @vnet_id2 = cli_create("onevnet create", template)

        @cluster_id = cli_create("onecluster create test_cluster")

        cli_action("onecluster delvnet default net1")

        cli_action("onecluster addvnet test_cluster net1")

        @vm_template = <<-EOF
            NAME = testvm2
            CPU  = 1
            MEMORY = 128
            SCHED_RANK=PRIORITY
            PCI = [ DEVICE="0863", TYPE="NIC", NETWORK="net1" ]
            PCI = [ DEVICE="0aa9" ]
            CONTEXT = [ NETWORK = "YES" ]
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create VM with PCI of TYPE NIC and get an IP & CONTEXT" do
        vm_id = cli_create("onevm create", @vm_template)
        vm    = VM.new(vm_id)

        xml   = vm.info

        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/BRIDGE']).to eq 'br0'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VN_MAD']).to eq 'dummy'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/IP']).to eq '192.168.0.1'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/IP']).to be_nil
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/PCI_ID']).to eq '1'

        expect(xml['TEMPLATE/CONTEXT/PCI0_ADDRESS']).to eq '01:01.0'
        expect(xml['TEMPLATE/CONTEXT/PCI0_IP']).to eq '192.168.0.1'
        expect(xml['TEMPLATE/CONTEXT/PCI0_MAC']).to eq '00:03:c0:a8:00:01'
        expect(xml['TEMPLATE/CONTEXT/PCI0_VLAN_ID']).to eq '15'

        expect(xml['TEMPLATE/CONTEXT/PCI1_ADDRESS']).to eq '01:02.0'
        expect(xml['TEMPLATE/CONTEXT/PCI1_IP']).to be_nil
        expect(xml['TEMPLATE/CONTEXT/PCI1_MAC']).to be_nil

        vnet = cli_action_xml('onevnet show -x net1')

        expect(vnet['AR_POOL/AR/LEASES/LEASE [ IP = "192.168.0.1" ]/VM']).to eq "#{vm_id}"
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '1'

        cli_action("onevm terminate --hard #{vm_id}")

        vnet = cli_action_xml('onevnet show -x net1')

        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '0'
    end

    it "should create VM with PCI of TYPE NIC and NICs and get IPs" do
        tmpl  = @vm_template + "\nNIC=[ NETWORK = \"net1\"]\n"
        vm_id = cli_create("onevm create", tmpl)
        vm    = VM.new(vm_id)

        xml   = vm.info

        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/BRIDGE']).to eq 'br0'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VN_MAD']).to eq 'dummy'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/IP']).to eq '192.168.0.2'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/IP']).to be_nil

        vnet = cli_action_xml('onevnet show -x net1')

        expect(vnet['AR_POOL/AR/LEASES/LEASE [ IP = "192.168.0.1" ]/VM']).to eq "#{vm_id}"
        expect(vnet['AR_POOL/AR/LEASES/LEASE [ IP = "192.168.0.2" ]/VM']).to eq "#{vm_id}"
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '2'

        cli_action("onevm terminate --hard #{vm_id}")

        vnet = cli_action_xml('onevnet show -x net1')

        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '0'
    end

    it "should not create VMs with NIC/PCI imposible setups" do
        tmpl  = @vm_template + "\nNIC=[ NETWORK = \"net2\"]\n"
        vm_id = cli_create("onevm create", tmpl, false)
    end

    it "should create VM with PCIs and assign VM addresses" do
        vm_id = cli_create("onevm create", @vm_template)
        vm    = VM.new(vm_id)

        xml   = vm.info

        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VM_ADDRESS']).to eq '01:01.0'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VM_BUS']).to eq '0x01'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VM_DOMAIN']).to eq '0x0000'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VM_FUNCTION']).to eq '0'
        expect(xml['TEMPLATE/PCI [ TYPE = "NIC" ]/VM_SLOT']).to eq '0x01'

        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/PCI_ID']).to eq '1'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/VM_ADDRESS']).to eq '01:02.0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/VM_BUS']).to eq '0x01'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/VM_DOMAIN']).to eq '0x0000'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/VM_FUNCTION']).to eq '0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0aa9" ]/VM_SLOT']).to eq '0x02'
    end

    it "should overrride BUS attribute" do
        tmpl  = @vm_template + "\nPCI=[ DEVICE = \"0bb9\", VM_BUS=\"0x06\"]\n"

        vm_id = cli_create("onevm create", tmpl)
        vm    = VM.new(vm_id)

        xml   = vm.info

        expect(xml['TEMPLATE/PCI [ DEVICE = "0bb9" ]/PCI_ID']).to eq '2'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0bb9" ]/VM_ADDRESS']).to eq '06:03.0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0bb9" ]/VM_BUS']).to eq '0x06'
    end

    it "should not create a VM with wrong BUS attribute" do
        tmpl  = @vm_template + "\nPCI=[ DEVICE = \"0bb9\", VM_BUS=\"f?w2 06\"]\n"

        vm_id = cli_create("onevm create", tmpl, false)
    end

    it "should create a VM with SHORT_ADDRESS attribute" do
        tmpl  = @vm_template + "\nPCI=[ SHORT_ADDRESS = \"00:06.1\"]\n"

        vm_id = cli_create("onevm create", tmpl)
        vm    = VM.new(vm_id)

        xml   = vm.info

        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/PCI_ID']).to eq '2'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/VM_ADDRESS']).to eq '01:03.0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/VM_BUS']).to eq '0x01'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/VM_DOMAIN']).to eq '0x0000'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/VM_FUNCTION']).to eq '0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/VM_SLOT']).to eq '0x03'
    end

    it "should not create a VM with SHORT_ADDRESS and DEVICE attribute" do
        tmpl  = @vm_template + "\nPCI=[ SHORT_ADDRESS = \"02:00.0\", DEVICE = \"0863\"]\n"

        vm_id = cli_create("onevm create", tmpl, false)
    end
end
