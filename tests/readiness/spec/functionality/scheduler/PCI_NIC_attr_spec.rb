require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'PCI devices as NIC' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # Helper functions for the tests
    #---------------------------------------------------------------------------
    def define_and_run(template)
        vmid = cli_create('onevm create', template)

        vm = VM.new(vmid)

        vm.running?

        return vmid, vm
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        h0_id = cli_create('onehost create host01 --im dummy --vm dummy')
        h1_id = cli_create('onehost create host02 --im dummy --vm dummy')

        h0 = Host.new(h0_id)
        h1 = Host.new(h1_id)

        h0.monitored?
        h1.monitored?

        cli_update('onehost update host01', 'PRIORITY = 5', true)
        cli_update('onehost update host02', 'PRIORITY = 2', true)

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        vn_template=<<-EOF
            NAME   = "passthrough"
            BRIDGE = br0
            VN_MAD = dummy
            VLAN_ID= 15
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        @vnet_id1 = cli_create('onevnet create', vn_template)

        vn_template=<<-EOF
            NAME   = "passthrough2"
            BRIDGE = br1
            VN_MAD = fw
            AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
        EOF

        @vnet_id2 = cli_create('onevnet create', vn_template)

        @vm_template = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
            SCHED_RANK=PRIORITY
        EOF
    end

    it 'should attach/detach interface by SHORT_ADDRESS' do
        _, vm = define_and_run(@vm_template)

        vm.nic_attach(@vnet_id1, :pci => '00:06.1')
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/NIC_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/BRIDGE']).to eq 'br0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/NETWORK']).to eq 'passthrough'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/TARGET']).to eq 'one-0-0'
        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/TYPE']).to eq 'NIC'

        vm.nic_detach(0)
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ SHORT_ADDRESS = "00:06.1" ]/PCI_ID']).to be_nil

        vm.terminate_hard

        vm.done?
    end

    it 'should attach/detach interface by DEVICE' do
        _, vm = define_and_run(@vm_template)

        vm.nic_attach(@vnet_id1, :pci_device => '0863')
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/NIC_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/BRIDGE']).to eq 'br0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/NETWORK']).to eq 'passthrough'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/TARGET']).to eq 'one-1-0'
        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/TYPE']).to eq 'NIC'

        vm.nic_detach(0)
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ DEVICE = "0863" ]/PCI_ID']).to be_nil

        vm.terminate_hard

        vm.done?
    end

    it 'should attach/detach interface by VENDOR' do
        _, vm = define_and_run(@vm_template)

        vm.nic_attach(@vnet_id1, :pci_vendor => '010de')
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/NIC_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/BRIDGE']).to eq 'br0'
        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/NETWORK']).to eq 'passthrough'
        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/TARGET']).to eq 'one-2-0'
        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/TYPE']).to eq 'NIC'

        vm.nic_detach(0)
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ VENDOR = "010de" ]/PCI_ID']).to be_nil

        vm.terminate_hard

        vm.done?
    end

    it 'should attach/detach interface by CLASS' do
        _, vm = define_and_run(@vm_template)

        vm.nic_attach(@vnet_id2, :pci_class => '0c03')
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/PCI_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/NIC_ID']).to eq '0'
        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/BRIDGE']).to eq 'br1'
        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/NETWORK']).to eq 'passthrough2'
        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/TARGET']).to eq 'one-3-0'
        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/TYPE']).to eq 'NIC'

        vm.nic_detach(0)
        xml = vm.info

        expect(xml['TEMPLATE/PCI [ CLASS = "0c03" ]/PCI_ID']).to be_nil

        vm.terminate_hard

        vm.done?
    end

    it 'should not attach pci device if is already in use' do
        vm_id, vm = define_and_run(@vm_template)

        vm.nic_attach(@vnet_id1, :pci => '00:06.1')
        cli_action("onevm nic-attach #{vm_id} --network #{@vnet_id1} --pci '00:06.1'", false)

        vm.terminate_hard

        vm.done?
    end
end
