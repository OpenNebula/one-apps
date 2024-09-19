require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'
require 'sunstone/VNet'
require 'sunstone/Image'
require 'sunstone/Datastore'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do

    def vm_template_vcenter(image, id)
        vm_tmpl = <<-EOF
        NAME   = #{image}
        CPU    = 2
        VCPU   = 1
        MEMORY = 1024
        VCENTER_CCR_REF = "0"
        VCENTER_INSTANCE_ID = "0"
        VCENTER_TEMPLATE_REF = "0"
        VCENTER_VM_FOLDER = ""
        HYPERVISOR = "vcenter"
        DISK = [ OPENNEBULA_MANAGED = "NO", IMAGE_ID = #{id} ]
        SCHED_RANK = "FREE_CPU * 100 - TEMPERATURE"
        EOF
    end

    def vm_template_kvm(image, id)
        vm_tmpl = <<-EOF
        NAME   = #{image}
        CPU    = 2
        VCPU   = 1
        MEMORY = 1024
        HYPERVISOR = "kvm"
        DISK = [ OPENNEBULA_MANAGED = "NO", IMAGE_ID = #{id} ]
        SCHED_RANK = "FREE_CPU * 100 - TEMPERATURE"
        EOF
    end

    def add_image_cli
        rtn = nil

        id = cli_create(
            'oneimage create --name ' \
            "#{@image_opennebula_kvm} " \
            '--size 100 --type datablock -d default'
        )

        cli_create(
            'onetemplate create',
            vm_template_kvm(@image_opennebula_kvm, id)
        )

        %W[#{@image_opennebula_manage} #{@image_opennebula_manage_change}].each do |image|
            id = cli_create(
                'oneimage create --name ' \
                "#{image} " \
                '--size 100 --type datablock -d default'
            )

            template = cli_create(
                'onetemplate create',
                vm_template_vcenter(image, id)
            )
            if image == @image_opennebula_manage
                rtn = template
            end
        end

        rtn
    end

    before(:all) do
        @image_opennebula_manage = "image_vcenter_X"
        @image_opennebula_manage_change = "image_vcenter_Y"
        @image_opennebula_kvm = "image_kvm"
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @host_id = cli_create("onehost create localhost --im dummy --vm dummy")

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @template = Sunstone::Template.new(@sunstone_test)
        @vnet = Sunstone::VNet.new(@sunstone_test)
        @image = Sunstone::Image.new(@sunstone_test)
        @ds = Sunstone::Datastore.new(@sunstone_test)
        
        vnet = { name: "vnet1", BRIDGE: "br0" }
        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "100" },
            { type: "ip4", ip: "192.168.0.2", size: "10" }
        ]
        @vnet.create(vnet[:name], vnet, ars)
        @sunstone_test.wait_resource_create("vnet", vnet[:name])

        hash = { name: "test_datablock", type: "DATABLOCK", size: "2" }
        @image.create(hash)
        @sunstone_test.wait_resource_create("image", "test_datablock")

        hash = {tm: "shared",type: "image"}
        @ds.create("ds-shared", hash)
        @sunstone_test.wait_resource_create("datastore", "ds-shared")

        hash = {tm: "ssh",type: "image"}
        @ds.create("ds-ssh", hash)
        @sunstone_test.wait_resource_create("datastore", "ds-ssh")
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it 'should check the attribute OPENNEBULA_MANAGE' do
        id_opennebula_manage = add_image_cli
        @template.change_opennebula_manage(
            @image_opennebula_manage,
            @image_opennebula_manage_change
        )

        # Check templates
        @sunstone_test.wait_resource_update(
            'template',
            @image_opennebula_manage,
            {
                :key=>'TEMPLATE/DISK/IMAGE',
                :value=> @image_opennebula_manage_change
            }
        )
        template = cli_action_xml("onetemplate show -x #{id_opennebula_manage}") rescue nil
        expect(template['TEMPLATE/DISK/OPENNEBULA_MANAGED']).to be_nil
    end

    it "should create a basic template" do
        template = {
            name: "temp_basic",
            mem: "2",
            cpu: "0.1",
            memory_cost: "1",
            cpu_cost: "2",
            disk_cost: "1"
        }
        if @template.navigate_create(template[:name])
            @template.add_general(template)
            @template.submit
        end

        #Check basic template created
        @sunstone_test.wait_resource_create("template", template[:name])
        tmp = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

        expect(tmp["TEMPLATE/MEMORY"]).to eql "2048"
        expect(tmp["TEMPLATE/CPU"]).to eql template[:cpu]
        expect(tmp["TEMPLATE/MEMORY_COST"]).to eql template[:memory_cost]
        expect(tmp["TEMPLATE/CPU_COST"]).to eql template[:cpu_cost]
        expect(tmp["TEMPLATE/DISK_COST"]).to eql (template[:disk_cost].to_i/1024.0).to_s
    end

    it "should create a basic template with hot resize" do
        template = {
            name: "temp_hot_resize",
            mem: "2",
            cpu: "0.1",
            memory_cost: "1",
            cpu_cost: "2",
            disk_cost: "1",
            memory_max: "4",
            vcpu_max: "2"
        }
        if @template.navigate_create(template[:name])
            @template.add_general(template)
            @template.submit
        end

        #Check basic template created
        @sunstone_test.wait_resource_create("template", template[:name])
        tmp = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

        expect(tmp["TEMPLATE/MEMORY"]).to eql "2048"
        expect(tmp["TEMPLATE/CPU"]).to eql template[:cpu]
        expect(tmp["TEMPLATE/MEMORY_COST"]).to eql template[:memory_cost]
        expect(tmp["TEMPLATE/CPU_COST"]).to eql template[:cpu_cost]
        expect(tmp["TEMPLATE/DISK_COST"]).to eql (template[:disk_cost].to_i/1024.0).to_s
        expect(tmp["TEMPLATE/MEMORY_MAX"]).to eql "4096"
        expect(tmp["TEMPLATE/VCPU_MAX"]).to eql "2"
        expect(tmp["TEMPLATE/HOT_RESIZE/CPU_HOT_ADD_ENABLED"]).to eql "YES"
        expect(tmp["TEMPLATE/HOT_RESIZE/MEMORY_HOT_ADD_ENABLED"]).to eql "YES"
    end

    it "should update a template" do
        @template.uncheck_options()
        template = { name: "temp_basic", mem: "2", cpu: "0.2" }
        @template.navigate_update(template[:name])
        @template.update_general(template)

        storage = { volatile: [{ size: "2", type: "fs", format: "qcow2" } ] }
        @template.update_storage(storage)

        network = { vnet: [ "vnet1" ] }
        @template.update_network(network)

        user_inputs = [
            { name: "input1", type: "text", desc: "input1", mand: "true" },
            { name: "input2", type: "boolean", desc: "input2", mand: "false" }
        ]

        @template.update_user_inputs(user_inputs)

        scheduling = { expression: "ROLE=prod" }
        @template.update_scheduling(scheduling)
        
        @template.submit

        # Check template updated
        @sunstone_test.wait_resource_update("template", template[:name], { :key=>"TEMPLATE/MEMORY", :value=>"2048" })
        tmp = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

        expect(tmp["TEMPLATE/MEMORY"]).to eql "2048"
        expect(tmp["TEMPLATE/CPU"]).to eql template[:cpu]
        expect(tmp['TEMPLATE/DISK[TYPE="fs"]/SIZE']).to eql "2048"
        expect(tmp['TEMPLATE/DISK[TYPE="fs"]/FORMAT']).to eql "qcow2"
        expect(tmp['TEMPLATE/NIC[NETWORK="vnet1"]']).not_to be(nil)
        expect(tmp['TEMPLATE/USER_INPUTS/INPUT1']).to eql "M|text|input1| |"
        expect(tmp['TEMPLATE/USER_INPUTS/INPUT2']).to eql "O|boolean|input2| |"
        expect(tmp['TEMPLATE/SCHED_REQUIREMENTS']).to eql scheduling[:expression]
    end

    it "should update a template to preservate information" do
        @template.uncheck_options()
        @template.navigate_update(@image_opennebula_kvm)

        template = { mem: "2", cpu: "0.2" }
        @template.update_general(template)

        @template.submit

        #Check preserved information after update
        @sunstone_test.wait_resource_update("template", @image_opennebula_kvm, { :key=>"TEMPLATE/SCHED_RANK", :value=>"FREE_CPU * 100 - TEMPERATURE" })
        tmp = cli_action_xml("onetemplate show -x #{@image_opennebula_kvm}") rescue nil
        expect(tmp['TEMPLATE/SCHED_RANK']).to eql "FREE_CPU * 100 - TEMPERATURE"
    end

    it "should delete a template" do
        template = { name: "temp_basic" }
        @template.delete(template[:name])

        @sunstone_test.wait_resource_delete("template", template[:name])
        xml = cli_action_xml("onetemplate list -x") rescue nil
        if !xml.nil?
            expect(xml["VMTEMPLATE[NAME='#{template[:name]}']"]).to be(nil)
        end
    end

    it "should create a template advanced mode" do
        template = <<-EOT
            NAME   = test-template-advanced
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
        EOT
        @template.create_advanced(template)

        #Check template created in advanced mode
        @sunstone_test.wait_resource_create("template", "test-template-advanced")
        temp = cli_action_xml("onetemplate show -x test-template-advanced") rescue nil
        expect(temp['TEMPLATE/CPU']).to eql "2"
        expect(temp['TEMPLATE/VCPU']).to eql "1"
        expect(temp['TEMPLATE/DISK/FORMAT']).to eql "raw"
        expect(temp['TEMPLATE/DISK/SIZE']).to eql "1024"
    end
end
