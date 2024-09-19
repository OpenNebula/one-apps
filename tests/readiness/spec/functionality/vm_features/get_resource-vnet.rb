
require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine NIC" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_action("oneacl create '* NET/* CREATE'")
        cli_action("oneacl create '* CLUSTER/#0 ADMIN'")

        cli_action('onehost create host0 --im dummy --vm dummy')
    end

    before(:each) do
        @vm_id = nil

        @vnet = VN.create(<<-EOT)
            NAME = test_vnet
            BRIDGE = vbr0
            NETWORK_ADDRESS = "10.0.0.0"
            VN_MAD = dummy
            FILTER_IP_SPOOFING = "yes"
            FILTER_MAC_SPOOFING = "yes"
            INBOUND_AVG_BW = "111"
            INBOUND_PEAK_BW = "222"
            CONF = [ A = "a", B = "b" ]
            AR = [
                TYPE = "IP4",
                SIZE = 255,
                IP = "10.0.0.1",
                INBOUND_PEAK_KB = "333"
            ]
        EOT
        @vnet.ready?
    end

    after(:each) do
        cli_action("onevm recover --delete #{@vm_id}") unless @vm_id.nil?
        @vnet.delete
        @vnet.deleted?
    end

    after(:all) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end

    it "should get the vnet by its id" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK_ID = #{@vnet.id} ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        expect(xml["TEMPLATE/NIC[1]/BRIDGE"]).to eq "vbr0"
    end

    it "should get the network by its name" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        expect(xml["TEMPLATE/NIC[1]/BRIDGE"]).to eq "vbr0"
    end

    it "should get the network by its name and uid" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NETWORK_UID = 0 ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        expect(xml["TEMPLATE/NIC[1]/BRIDGE"]).to eq "vbr0"
    end

    it "should get the network by its name and uname" do
        cli_create_user("userA", "passwordA")

        as_user("userA") do
            vnet = VN.create(<<-EOT)
                NAME = test_vnet
                BRIDGE = test_net
                NETWORK_ADDRESS = "10.0.0.0"
                VN_MAD = dummy
                AR = [
                    TYPE = "IP4",
                    SIZE = 255,
                    IP = "10.0.0.1" ]
            EOT
            vnet.ready?
        end

        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NETWORK_UNAME = userA ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        expect(xml["TEMPLATE/NIC[1]/BRIDGE"]).to eq "test_net"
    end

    it "should not create a VM with non existent network" do
        cli_create("onevm create", <<-EOT, false)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NETWORK_UID = 3 ]
        EOT

        cli_create("onevm create", <<-EOT, false)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = DOES_NOT_EXIST ]
        EOT

        cli_create("onevm create", <<-EOT, false)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NETWORK_UNAME = userB ]
        EOT

        cli_create("onevm create", <<-EOT, false)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK_ID = 23 ]
        EOT
    end

    it "should inherit simple values" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, FILTER_MAC_SPOOFING = "no" ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        expect(xml["TEMPLATE/NIC[1]/FILTER_IP_SPOOFING"]).to eq "yes"
        expect(xml["TEMPLATE/NIC[1]/FILTER_MAC_SPOOFING"]).to eq "no"
    end

    it "should inherit vector values" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, B = "overriden" ]
        EOT

        xml = cli_action_xml("onevm show -x #{@vm_id}")
        # Test values inherited from vector value CONF
        expect(xml["TEMPLATE/NIC[1]/A"]).to eq "a"
        expect(xml["TEMPLATE/NIC[1]/B"]).to eq "overriden"
    end

    it "Virtual Network update should update the VM NIC" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NAME = test_nic, INBOUND_PEAK_BW = "444" ]
            NIC_ALIAS = [ NETWORK = test_vnet, PARENT = test_nic ]
            PCI = [ DEVICE="0863", TYPE="NIC", NETWORK="test_vnet" ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "444"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/NIC[1]/OUTBOUND_AVG_BW"]).to be nil

        # NIC alias
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/OUTBOUND_AVG_BW"]).to be nil

        # PCI NIC
        expect(xml["TEMPLATE/PCI[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/PCI[1]/OUTBOUND_AVG_BW"]).to be nil

        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        tmpl = <<-EOF
            INBOUND_AVG_BW="555"
            INBOUND_PEAK_BW="666"
            INBOUND_PEAK_KB="777"
            OUTBOUND_AVG_BW="888"
        EOF

        cli_update("onevnet update #{@vnet.id}", tmpl, true)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "444" # Not updated, keep NIC value
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333" # Inherited from AR
        expect(xml["TEMPLATE/NIC[1]/OUTBOUND_AVG_BW"]).to eq "888"

        # Update of NIC alias is not supported (version 6.6)
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/NIC_ALIAS[1]/OUTBOUND_AVG_BW"]).to be nil

        # Update of PCI NIC is not supported (version 6.6)
        expect(xml["TEMPLATE/PCI[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_BW"]).to eq "666"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/PCI[1]/OUTBOUND_AVG_BW"]).to eq "888"

        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        # Check the VM is in VN updated list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
    end

    it "Address Range update should update VM NIC" do
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, INBOUND_PEAK_BW = "444" ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "444"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/NIC[1]/OUTBOUND_AVG_BW"]).to eq nil
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        tmpl = <<-EOF
            INBOUND_AVG_BW="555",
            INBOUND_PEAK_BW="666",
            INBOUND_PEAK_KB="777",
            OUTBOUND_AVG_BW="888"
        EOF

        cli_update("onevnet updatear #{@vnet.id} 0", tmpl, true)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "111"   # Not updated, keep VN value
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "444"  # Not updated, keep NIC value
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "777"
        expect(xml["TEMPLATE/NIC[1]/OUTBOUND_AVG_BW"]).to eq "888"
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        # Check the VM is in VN updated list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
    end

    it "nic-update should trigger nic_update action" do
        # Create and deploy VM
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, INBOUND_PEAK_KB = "444" ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "444"
        expect(xml["TEMPLATE/NIC[1]/IP6_METHOD"]).to be nil
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        tmpl = <<-EOF
            INBOUND_AVG_BW="555"
            INBOUND_PEAK_KB="666"
            IP6_METHOD="new"
        EOF

        # Call nic-update
        cli_update("onevm nic-update #{@vm_id} 0", tmpl, true)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "666"
        expect(xml["TEMPLATE/NIC[1]/IP6_METHOD"]).to be nil # Not allowed to update
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        # Check the VM is in VN updated list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
    end

    it "nic-update should fail for nic_alias" do
        # Create and deploy VM
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet, NAME = test_nic ]
            NIC_ALIAS = [ NETWORK = test_vnet, PARENT = test_nic ]
            PCI = [ DEVICE="0863", TYPE="NIC", NETWORK="test_vnet" ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        tmpl = <<-EOF
            INBOUND_AVG_BW="555"
            INBOUND_PEAK_KB="666"
        EOF

        # Update of NIC alias is not suported ((version 6.8)
        cli_update("onevm nic-update #{@vm_id} 0", tmpl, true)
        vm.running?
        cli_update("onevm nic-update #{@vm_id} 1", tmpl, true) # PCI
        vm.running?
        cli_update("onevm nic-update #{@vm_id} 2", tmpl, true, false) # NIC Alias
    end

    it "nic-update should trigger nic_update action for PCI NIC" do
        # Create and deploy VM
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            PCI = [ DEVICE="0863", TYPE="NIC", NETWORK="test_vnet", INBOUND_PEAK_KB = "444" ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/PCI[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_KB"]).to eq "444"
        expect(xml["TEMPLATE/PCI[1]/IP6_METHOD"]).to be nil
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        tmpl = <<-EOF
            INBOUND_AVG_BW="555"
            INBOUND_PEAK_KB="666"
            IP6_METHOD="new"
        EOF

        # Call nic-update
        cli_update("onevm nic-update #{@vm_id} 0", tmpl, true)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/PCI[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/PCI[1]/INBOUND_PEAK_KB"]).to eq "666"
        expect(xml["TEMPLATE/PCI[1]/IP6_METHOD"]).to be nil # Not allowed to update
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        # Check the VM is in VN updated list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
    end

    it "fail onevnet update and call recover" do
        # Deploy VM
        @vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            NIC = [ NETWORK = test_vnet ]
        EOT

        cli_action("onevm deploy #{@vm_id} host0")

        vm = VM.new(@vm_id)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "111"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "222"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        tmpl = <<-EOF
            INBOUND_AVG_BW="555"
            INBOUND_PEAK_BW="666"
            INBOUND_PEAK_KB="777"
        EOF

        # The driver action will fail
        File.write('/tmp/opennebula_dummy_actions/update_nic', '0')

        cli_update("onevnet update #{@vnet.id}", tmpl, true)

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "666"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/VNET_UPDATE"]).not_to be nil

        # Check the VM is in VN error list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['STATE']).to eq "6" # UPDATE_FAILURE

        # The driver action will succeed
        File.write('/tmp/opennebula_dummy_actions/update_nic', '1')

        cli_action("onevnet recover --retry #{@vnet.id}")

        vm.running?

        xml = vm.info

        # Test NIC attributes
        expect(xml["TEMPLATE/NIC[1]/INBOUND_AVG_BW"]).to eq "555"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_BW"]).to eq "666"
        expect(xml["TEMPLATE/NIC[1]/INBOUND_PEAK_KB"]).to eq "333"
        expect(xml["TEMPLATE/VNET_UPDATE"]).to be nil

        # Check the VM is in VN updated list
        vn_hash = @vnet.xml.to_hash
        expect(vn_hash['VNET']['UPDATED_VMS']['ID']).to include(@vm_id.to_s)
        expect(vn_hash['VNET']['ERROR_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['UPDATING_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['OUTDATED_VMS']['ID']).to be nil
        expect(vn_hash['VNET']['STATE']).to eq "1" # READY
    end
end
