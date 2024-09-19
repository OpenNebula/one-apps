require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "PCI devices scheduling tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    def define_and_run(template, hid = -1)
        vmid = cli_create("onevm create", template)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{hid}") unless hid == -1

        vm.running?

        return vmid, vm
    end

    def check_pci(vm, pciid)
        xml = vm.info

        vm_address = xml["TEMPLATE/PCI [ PCI_ID = \"#{pciid}\" ]/VM_ADDRESS"]

        expect(vm_address).not_to be_nil
        expect(xml["TEMPLATE/CONTEXT/PCI#{pciid}_ADDRESS"]).to eq vm_address
    end

    def check_removed(vm, pciid)
        xml = vm.info

        vm_address =

        expect(xml["TEMPLATE/PCI [ PCI_ID = \"#{pciid}\" ]"]).to be_nil
        expect(xml["TEMPLATE/CONTEXT/PCI#{pciid}_ADDRESS"]).to be_nil
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        h0_id = cli_create("onehost create host01 --im dummy --vm dummy")
        h0    = Host.new(h0_id)

        h0.monitored?

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
            PCI = [ DEVICE="0863" ]
            PCI = [ DEVICE="0aa9" ]
            CONTEXT = [ NETWORK = "YES" ]
        EOF

        @vmid, @vm = define_and_run(@template_1, h0_id)

    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should not detach PCI devices in RUNNING" do
        cli_action("onevm pci-detach #{@vmid} 0", false)
    end

    it "should detach PCI devices in poweroff" do
        @vm.poweroff

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID'].to_i).to eql @vmid
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID'].to_i).to eql @vmid

        2.times { |i|
            cli_action("onevm pci-detach #{@vmid} #{i}")

            check_removed(@vm, i)
        }

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

        @vm.resume
    end

    it "should not attach PCI devices in RUNNING" do
        cli_action("onevm pci-attach --pci_device 0863 #{@vmid}", false)
    end

    it "should attach PCI devices in poweroff" do
        @vm.poweroff

        [[0,'0863'], [1,'0aa9']].each { |i|
            cli_action("onevm pci-attach --pci_device #{i[1]} #{@vmid}")

            check_pci(@vm, i[0])
        }

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID'].to_i).to eql @vmid
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID'].to_i).to eql @vmid
    end

    it "should detach PCI devices in undeploy" do
        @vm.undeploy

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

        2.times { |i|
            cli_action("onevm pci-detach #{@vmid} #{i}")

            check_removed(@vm, i)
        }

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

        cli_action("onevm deploy #{@vm.id} host01")

        @vm.running?

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"
    end

    it "should attach PCI devices in undeploy" do
        @vm.undeploy

        [[0,'0863'], [1,'0aa9']].each { |i|
            cli_action("onevm pci-attach --pci_device #{i[1]} #{@vmid}")

            check_pci(@vm, i[0])
        }

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID']).to eql "-1"

        cli_action("onevm deploy #{@vm.id} host01")

        @vm.running?

        host = cli_action_xml("onehost show host01 -x")

        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:02:00:0"]/VMID'].to_i).to eql @vmid
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:0"]/VMID']).to eql "-1"
        expect(host['HOST_SHARE/PCI_DEVICES/PCI[ADDRESS="0000:00:06:1"]/VMID'].to_i).to eql @vmid
    end

end
