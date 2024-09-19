
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Attach/Detach nics to/from a VM" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @one_test.stop_sched

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        cli_create_user("uA", "abc")

        cli_create('onegroup create gA')
        cli_action('oneuser chgrp uA gA')

        cli_create("onevdc create vdcA")
        cli_action("onevdc addgroup vdcA gA")
        cli_action("onevdc addcluster vdcA 0 ALL")

        cli_create("onehost create host0 --im dummy --vm dummy")

        @vnet1_id = cli_create("onevnet create", <<-EOT)
            NAME = "test_vnet1"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
            AR = [
               TYPE = "IP4",
               IP = "10.0.0.1",
               SIZE = "200"
            ]
        EOT

        @vnet2_id = cli_create("onevnet create", <<-EOT)
            NAME = "test_vnet2"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
            AR = [
               TYPE = "IP4",
               IP = "10.0.1.1",
               SIZE = "200"
            ]
        EOT

        cli_action("onevnet chown test_vnet1 uA")
        cli_action("onevnet chown test_vnet2 uA")

        as_user("uA") do
            @img1_id = cli_create("oneimage create -d 1", <<-EOT)
                NAME = "test_img1"
                PATH = "/tmp/none"
            EOT

            wait_loop() do
                xml = cli_action_xml("oneimage show -x #{@img1_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
            end

            @id = cli_create("onevm create --name test_vm --memory 1024 " <<
                             " --cpu 1 --nic test_vnet1 --disk test_img1")
            @vm = VM.new(@id)
        end
    end

    it "should fail to attach a nic to a non-running VM" do
        as_user("uA") do
            cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}", false)

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to be_nil
        end
    end

    it "should attach a nic to a VM and update user quotas" do
        cli_action("onevm deploy #{@id} 0")
        @vm.running?

        as_user("uA") do
            cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")
            @vm.running?

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/NIC[NIC_ID='1']/NETWORK_ID"]).to eql "#{@vnet2_id}"

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql "1"
        end
    end

    it "should fail to attach a nic with wrong IP to a VM and update user quotas" do
        @vm.running?

        filename = "/tmp/nicattach_test_template"
        `echo "NIC = [ NETWORK_ID = #{@vnet2_id}, IP = "192.168.192.168.192" ]" > #{filename}`

        as_user("uA") do
            cli_create("onevm nic-attach #{@id} --file", <<-EOT, false)
                NIC = [
                    NETWORK_ID = #{@vnet2_id},
                    IP = "192.168.192.168.192" ]
            EOT

            @vm.running?

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/NIC[NIC_ID='1']/NETWORK_ID"]).to eql "#{@vnet2_id}"

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql "1"
        end
    end

    it "should attach a nic to a POWEROFF VM and update user quotas" do
        @vm.safe_poweroff

        as_user("uA") do
            cli_action("onevm nic-attach #{@id} --network #{@vnet2_id}")

            @vm.state?("POWEROFF")

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/NIC[NIC_ID='1']/NETWORK_ID"]).to eql "#{@vnet2_id}"
            expect(vxml["TEMPLATE/NIC[NIC_ID='2']/NETWORK_ID"]).to eql "#{@vnet2_id}"

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql "2"
        end
    end

    it 'resume VM' do
        cli_action("onevm resume #{@id}")
        @vm.running?
    end

    it "should not detach a non-existing nic from a VM" do
        as_user("uA") do
            cli_action("onevm nic-detach #{@id} 23", false)
        end
    end

    it "should detach a nic from a VM and update user quotas" do
        as_user("uA") do
            cli_action("onevm nic-detach #{@id} 1")
            @vm.running?

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to eql "1"

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/NIC[NIC_ID='1']"]).to be_nil
        end
    end

    it "should detach a nic from a POWEROFF VM and update user quotas" do
        as_user("uA") do
            cli_action("onevm nic-detach #{@id} 2")
            @vm.running?

            uxml = cli_action_xml("oneuser show -x")

            expect(uxml["VM_QUOTA/VM/CPU_USED"]).to eql "1"
            expect(uxml["VM_QUOTA/VM/MEMORY_USED"]).to eql "1024"

            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet1_id}']/LEASES_USED"]).to eql "1"
            expect(uxml["NETWORK_QUOTA/NETWORK[ID='#{@vnet2_id}']/LEASES_USED"]).to be_nil

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/NIC[NIC_ID='1']"]).to be_nil
            expect(vxml["TEMPLATE/NIC[NIC_ID='2']"]).to be_nil
        end
    end

    it 'should attach a NIC with a template via STDIN to a POWEROFF VM' do
        @vm.poweroff

        cmd = "onevm nic-attach #{@id}"

        template = <<~EOT
            NIC = [ NETWORK_ID = #{@vnet2_id} ]
        EOT

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        cli_action(stdin_cmd)
        vxml = cli_action_xml("onevm show -x #{@id}")
        expect(vxml["TEMPLATE/NIC[NIC_ID='1']/NETWORK_ID"]).to eql @vnet2_id.to_s
    end
end
