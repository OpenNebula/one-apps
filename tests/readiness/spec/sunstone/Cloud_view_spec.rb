require 'init_functionality'
require 'sunstone_test'
require 'sunstone/CloudView'

RSpec.describe "Cloud View test", :type => 'skip' do

    vmname = "test_vm_2"
    vmname_ipv4 = "test_vm_ipv4"
    vmname_saveas = "test_saveas"
    vmname_vmgroup = "test_vmgroup"
    hash_snap = { name: "test_snap" }
    edit_size = "2048"

    def wait_vm_lcm_state(vm, state)
        wait_loop() do
          xml = cli_action_xml("onevm show #{vm} -x")
          OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == state
        end
    end

    def wait_vm_state(vm, state)
        wait_loop() do
          xml = cli_action_xml("onevm show #{vm} -x")
          OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == state
        end
    end

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }
        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @cloudView = Sunstone::CloudView.new(@sunstone_test)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
        @host_id = cli_create("onehost create localhost --im dummy --vm dummy")

        template = <<-EOF
            NAME   = test
            CPU    = 2
            VCPU   = 1
            MEMORY = 128
            ATT1   = "VAL1"
            ATT2   = "VAL2"
            DISK   = [
                FORMAT = "raw",
                SIZE = "1024",
                TYPE = "fs"
            ]
        EOF

        @template_id = cli_create("onetemplate create", template)
        @sunstone_test.wait_resource_create("template", @template_id)

        @vm_id = cli_create("onetemplate instantiate #{@template_id} --name test_vm")
        wait_vm_lcm_state(@vm_id, "LCM_INIT");
        cli_action("onevm deploy #{@vm_id} #{@host_id}")
        wait_vm_lcm_state(@vm_id, "RUNNING");

        vmg = <<-EOT
            NAME         = "Test group"
            ROLE         = [ NAME = web ]
            ROLE         = [ NAME = db  ]
            ROLE         = [ NAME = app  ]
            AFFINED      = "web, db"
            ANTI_AFFINED = "app"
        EOT

        @vmg_id = cli_create("onevmgroup create", vmg)
        @sunstone_test.wait_resource_create("vmgroup", @vmg_id)

        vnet = <<-EOF
            NAME   = "test_vnet"
            BRIDGE = br0
            VN_MAD = dummy
            AR     = [
                TYPE = "ETHER",
                SIZE = "128",
                MAC  = "00:02:01:02:03:04"
            ]
        EOF

        @vnet_id = cli_create("onevnet create", vnet)
        @sunstone_test.wait_resource_create("vnet", @vnet_id)

        vnet = <<-EOF
            NAME   = "test_vnet_ipv4"
            BRIDGE = br0
            VN_MAD = dummy
            AR     = [
                TYPE = "IP4",
                SIZE = "51",
                IP   = "10.0.0.150"
            ]
        EOF

        @vnet2_id = cli_create("onevnet create", vnet)
        @sunstone_test.wait_resource_create("vnet", @vnet2_id)
        
        @image_id = cli_create("oneimage create --name test_img --size 100 --type datablock -d default")
        @sunstone_test.wait_resource_create("image", @image_id)

        @cloudView.navigate
    end

    before(:each) do
        sleep 1
    end

    after(:each) do
        @cloudView.provision_dashboard
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "Instantiate template w/ vmgroup and check it" do
        hash = { mem: "256", vmgroup: "Test group", role: "db", disk: "1024", disk_unit: "MB" }
        @cloudView.instantiate_template(vmname_vmgroup, hash)
        
        @sunstone_test.wait_resource_create("vm", vmname_vmgroup)
        vm = cli_action_xml("onevm show -x #{vmname_vmgroup}") rescue nil
        expect(vm["TEMPLATE/VMGROUP/VMGROUP_ID"]).to eql @vmg_id.to_s
        expect(vm["TEMPLATE/VMGROUP/ROLE"]).to eql "db"
    end

    it "Instantiate template w/ vnet and check it" do
        hash = { mem: "256", vnet: "test_vnet", disk: "1024", disk_unit: "MB" }
        @cloudView.instantiate_template(vmname, hash)

        @sunstone_test.wait_resource_create("vm", vmname)
        cli_action("onevm deploy  #{vmname} #{@host_id}")
        vm = cli_action_xml("onevm show -x  #{vmname}") rescue nil
        expect(vm["TEMPLATE/NIC/NETWORK_ID"]).to eql @vnet_id.to_s
        expect(vm["TEMPLATE/NIC/NETWORK"]).to eql "test_vnet"
        expect(vm["TEMPLATE/NIC/BRIDGE"]).to eql "br0"
        expect(vm["TEMPLATE/NIC/VN_MAD"]).to eql "dummy"
        expect(vm["TEMPLATE/NIC/MAC"]).to eql "00:02:01:02:03:04"
    end

    it "Instantiate template w/ vnet and force IPv4 and check it" do
        hash = { mem: "256", vnet: "test_vnet_ipv4", force_ipv4: "10.0.0.155"}
        @cloudView.instantiate_template(vmname_ipv4, hash)

        @sunstone_test.wait_resource_create("vm", vmname_ipv4)
        cli_action("onevm deploy  #{vmname_ipv4} #{@host_id}")
        vm = cli_action_xml("onevm show -x  #{vmname_ipv4}") rescue nil
        expect(vm["TEMPLATE/NIC/NETWORK_ID"]).to eql @vnet2_id.to_s
        expect(vm["TEMPLATE/NIC/NETWORK"]).to eql "test_vnet_ipv4"
        expect(vm["TEMPLATE/NIC/BRIDGE"]).to eql "br0"
        expect(vm["TEMPLATE/NIC/VN_MAD"]).to eql "dummy"
        expect(vm["TEMPLATE/NIC/IP"]).to eql "10.0.0.155"
    end

    it "Attach and resize disk" do
        wait_vm_state(vmname, "ACTIVE");
        hash_attach = { id: @image_id }
        @cloudView.storage(vmname, hash_attach)

        wait_vm_state(vmname, "ACTIVE");
        hash_resize = { id: 0, size: edit_size }
        @cloudView.storage(vmname, nil, hash_resize)
    end

    it "Attach nic" do
        wait_vm_lcm_state(vmname, "RUNNING");
        hash_attach = { id: @vnet_id }
        @cloudView.network(vmname, hash_attach)
    end

    it "VM snapshot" do
        wait_vm_lcm_state(vmname, "RUNNING");
        @cloudView.snapshot(vmname, hash_snap)
    end

    it "Check new vm attributes" do
        wait_vm_lcm_state(vmname, "RUNNING");
        vm = cli_action_xml("onevm show -x #{vmname}") rescue nil
        expect(vm["TEMPLATE/DISK[DISK_ID='0']/SIZE"]).to eql edit_size # check resize
        expect(vm["TEMPLATE/DISK[IMAGE_ID='#{@image_id}']/IMAGE"]).to eql "test_img" # chech attach disk
        expect(vm["TEMPLATE/NIC[NIC_ID='#{@vnet_id}']/BRIDGE"]).to eql "br0" # check attach nic
        expect(vm["TEMPLATE/SNAPSHOT/NAME"]).to eql "test_snap" # check snapshot
    end

    it "Detach disk" do
        wait_vm_lcm_state(vmname, "RUNNING");
        hash_detach = { id: @image_id }
        @cloudView.detach_storage(vmname, hash_detach)
    end

    it "Detach nic" do
        wait_vm_lcm_state(vmname, "RUNNING");
        hash_detach = { id: @vnet_id }
        @cloudView.detach_network(vmname, hash_detach)
    end

    it "Delete snapshot" do
        wait_vm_lcm_state(vmname, "RUNNING");
        @cloudView.delete_snapshot(vmname, hash_snap)
    end

    it "Check detachs in VM" do
        wait_vm_lcm_state(vmname, "RUNNING");
        vm = cli_action_xml("onevm show -x #{vmname}") rescue nil
        expect(vm["TEMPLATE/DISK[SIZE='#{edit_size}']"]).to be nil # check detach disk
        expect(vm["TEMPLATE/NIC[NIC_ID='#{@vnet_id}']"]).to be nil # check detach nic
        expect(vm["TEMPLATE/SNAPSHOT"]).to be nil # check delete snapshot
    end

    it "Capacity resize" do
        cli_action("onevm poweroff #{vmname}")
        wait_vm_state(vmname, "POWEROFF");
        hash = {
            mem: 256,
            cpu: 3,
            vcpu: 2
        }
        @cloudView.capacity(vmname, hash)

        @sunstone_test.wait_resource_update("vm", vmname, { :key=>'TEMPLATE/CPU', :value=>hash[:cpu].to_s })
        vm = cli_action_xml("onevm show -x #{vmname}") rescue nil
        expect(vm["TEMPLATE/MEMORY"]).to eql hash[:mem].to_s
        expect(vm["TEMPLATE/CPU"]).to eql hash[:cpu].to_s
        expect(vm["TEMPLATE/VCPU"]).to eql hash[:vcpu].to_s
        expect(vm["STATE"]).to eql "8"
    end

    it "Save as template" do
        hash_saveas = {
            name: vmname_saveas,
            #description: "Testing save as",
            persistent: false
        }
        @cloudView.save_as(vmname, hash_saveas)
        @sunstone_test.wait_resource_create("template", vmname_saveas)
        template = cli_action_xml("onetemplate show -x #{vmname_saveas}") rescue nil
        expect(template["TEMPLATE/MEMORY"]).to eql "128"
        expect(template["TEMPLATE/CPU"]).to eql "2"
        expect(template["TEMPLATE/VCPU"]).to eql "1"
        
        @sunstone_test.wait_resource_create("image", "#{vmname_saveas}-disk-1")
        image = cli_action_xml("oneimage show -x #{vmname_saveas}-disk-1") rescue nil
        expect(image["SIZE"]).to eql "100"
    end

    it "Terminate VM" do
        @cloudView.terminate(vmname)

        @sunstone_test.wait_resource_delete("vm", vmname)
        xml = cli_action_xml("onevm list -x") rescue nil
        expect(xml["VM[NAME='#{vmname}']"]).to be nil
    end
end
