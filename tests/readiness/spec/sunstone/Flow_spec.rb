require 'init_functionality'
require 'flow_helper'
require 'sunstone_test'
require 'sunstone/Flow'
require 'sunstone/VMGroup'
require 'sunstone/Vm'
require 'sunstone/Zone'
require 'sunstone/Utils'

RSpec.describe "Sunstone services (flow) tab", :type => 'skip' do
    include FlowHelper

    # Define constant names
    ROLE_NAME = "master"
    ROLE_NAME_SLAVE = "minion"
    SERVICE_NAME = "oneflow_test"
    VMGROUP_NAME = "test_vmgroups_services"

    def check_command_cli(command = "")
      begin
        cli_action_json(command, nil)
      rescue
      end
    end

    def create_and_instantiate_service(service_template)
        # Create Service Template with automatic deletion
        @flow.navigate_template_dt
        @flow.create_template(service_template)
        @sunstone_test.wait_resource_create("flow-template", service_template[:info][:name], 600)

        # Instantiate Service template
        @flow.navigate_template_dt
        $driver.save_screenshot("/tmp/create_and_instantiate_service_#{service_template[:info][:name]}_1.png")
        @flow.refresh_template_dt_until_row(service_template[:info][:name],20)
        $driver.save_screenshot("/tmp/create_and_instantiate_service_#{service_template[:info][:name]}_2.png")
        @flow.instantiate_template(service_template[:info][:name], service_template)
        $driver.save_screenshot("/tmp/create_and_instantiate_service_#{service_template[:info][:name]}_3.png")
        @sunstone_test.wait_resource_create("flow", service_template[:info][:name], 600)

        # Get service ID
        service_json = cli_action_json("oneflow show #{service_template[:info][:name]} -j")
        expect(service_json).not_to be_nil
        service_json['DOCUMENT']['ID']
    end

    def build_vnet_template(name, size, extra_attributes = '')
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[ TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end

    def wait_service_undeploy(service_id)
      wait_loop do
        !system("oneflow show #{service_id} > /dev/null")
      end
    end

    def wait_service_template_delete(service_template_id)
      wait_loop do
        !system("oneflow-template show #{service_template_id} > /dev/null")
      end
    end

    def wait_template_delete(template_id)
        wait_loop do
          !system("onetemplate show #{template_id} > /dev/null")
        end
    end

    def wait_image_delete(image_id)
        wait_loop do
          !system("oneimage show #{image_id} > /dev/null")
        end
    end

    def create_service_template_json(name, description, roles, automatic_deletion = false)
      return {
        :info => {
          :name => name,
          :description => description,
          :automatic_deletion => automatic_deletion
        },
        :roles => roles
      }
    end

    def create_role_json(name, template_id, cardinality = nil, networks = nil, elasticity = nil)
      role = {
        :name => name,
        :template_vm_id => template_id.to_s
      }

      role[:cardinality] = cardinality.to_s if !cardinality.nil?
      role[:networks] = networks if !networks.nil?
      role[:elasticity] = elasticity if !elasticity.nil?

      role
    end

    def create_service_template(name,
                                image     = true,
                                strategy  = 'none',
                                gate      = false,
                                network   = false,
                                custom    = false,
                                automatic = false,
                                hold      = false)
        # Create the VM template
        template = vm_template(image, name, name)
        cli_action("oneimage create -d default --name #{name} --size 1") if image
        template_id = cli_create("onetemplate create", template)
        
        # Create Service template
        template = JSON.parse(service_template(strategy))

        # Add change information
        template['name'] = name
        template['roles'][0]['vm_template'] = template_id
        template['roles'][1]['vm_template'] = template_id

        template_file = Tempfile.new('service_template')
        template_file << template.to_json
        template_file.close

        cli_create("oneflow-template create #{template_file.path}")
    end
    
    def instantiate_service_template(name)
        # Instantiate the service template
        service_id = cli_create("oneflow-template instantiate #{name}")
        
        # Flow state must be DEPLOYING
        wait_state(service_id, 1)

        service_json = cli_action_json("oneflow show #{service_id} -j")

        # Force deploy role vms
        get_roles(service_json).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # Wait until the service is RUNNING
        wait_state(service_id, 2, 120)
    end

    #----------------------------------------------------------------------
    #----------------------------------------------------------------------

    before(:all) do
        start_flow

        user = @client.one_auth.split(":")
        @auth = {
          :username => user[0],
          :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @utils = Sunstone::Utils.new(@sunstone_test)
        @zone = Sunstone::Zone.new(@sunstone_test, @one_test)
        #create a new zone
        cli_action("onezone create /tmp/new_flow_zone.conf")
        @sunstone_test.wait_resource_create("zone", "zone_flow")

        # Create dummy host
        @host_id = cli_create("onehost create localhost --im dummy --vm dummy")

        # Create Image
        cli_action('oneimage create -d default --name test_flow --size 1')

        # Create VM template
        template = vm_template(true)
        template.concat("GRAPHICS = [ LISTEN = \"0.0.0.0\", TYPE = \"VNC\" ]")

        @user_input_text = 'TEST_INPUT'
        template.concat("CONTEXT = [ TEST_INPUT = \"$TEST_INPUT\" ]")
        template.concat("USER_INPUTS = [ TEST_INPUT = \"M|text|text description| |text_default_value\" ]")

        @template_id = cli_create("onetemplate create", template)

        # Create virtual network
        @vnet_name = 'test_vnet'
        @vnet_id = cli_create("onevnet create", build_vnet_template(@vnet_name, 10))
        @sunstone_test.wait_resource_create('vnet', @vnet_id)

        # Create the templates to be deleted on this tests
        @service_delete_tmp_name = 'oneflow_test_delete_tmpls'
        @service_delete_tmp_img_name = 'oneflow_test_delete_tmpls_imgs'
        @service_delete_name = 'oneflow_test_delete'
        @service_add_charters_name = 'oneflow_add_charters'

        create_service_template(@service_delete_tmp_name)
        create_service_template(@service_delete_tmp_img_name)
        create_service_template(@service_delete_name)
        create_service_template(@service_add_charters_name, false)


        # Instantiate Service
        instantiate_service_template(@service_add_charters_name)

        # Login with credentials in Sunstone
        @sunstone_test.login

        @flow = Sunstone::Flow.new(@sunstone_test)
        @vmgroup = Sunstone::VMGroup.new(@sunstone_test)
        @vm = Sunstone::Vm.new(@sunstone_test)

        networks_array = [
          { name: 'public' },
          { name: 'private', alias: 'public' }
        ]

        @simple_service_template = {
            info: {
                name: SERVICE_NAME,
                description: "Template to testing oneflow in Sunstone"
            },
            networks: [
              {
                name: 'public',
                description: 'Public network',
                type: 'id',
                network_id: @vnet_id.to_s
              },
              {
                name: 'private',
                description: 'Private network',
                type: 'id',
                network_id: @vnet_id.to_s
              }
            ],
            leases: true,
            roles: [
              create_role_json(
                ROLE_NAME,
                @template_id,
                1,
                networks_array,
                { 
                  :min_vms => '0', 
                  :max_vms => '1',
                  :cooldown => '5'
                }
              ),
              create_role_json(
                ROLE_NAME_SLAVE,
                @template_id,
                1,
                networks_array
              )
            ]
        }
    end

    before(:each) do
        sleep 1
    end

    it "should create a service template" do
        @flow.create_template(@simple_service_template)
        @sunstone_test.wait_resource_create("flow-template", SERVICE_NAME)
        template_service = cli_action_json("oneflow-template show #{SERVICE_NAME} -j")
        expect(template_service).not_to be_nil
    end

    it "should check charters into service template" do
        @sunstone_test.wait_resource_create("flow-template", SERVICE_NAME)
        template_service = cli_action_json("oneflow-template show #{SERVICE_NAME} -j")
        expect(template_service["DOCUMENT"]["TEMPLATE"]["BODY"]["roles"][0]["vm_template_contents"]).to include("SCHED_ACTION")
    end

    it "should instantiate a service template" do
        begin
            # change default values to user inputs from vm template
            # reference: 'sunstone/Template_ui_spec.rb'
            roles = @simple_service_template[:roles].map { |role|
            {
                name: role[:name],
                inputs: [{
                    name: @user_input_text,
                    type: 'text',
                    post: { value: "text_value_by_#{role[:name]}" },
                }]
            }
            }

            service = { info: { name: SERVICE_NAME }, roles: roles }
            @flow.instantiate_template(SERVICE_NAME, service)
            @sunstone_test.wait_resource_create("flow", service[:info][:name])
            wait_state(service[:info][:name], 1) #deploying

            service_json = cli_action_json("oneflow show #{service[:info][:name]} -j")
            expect(service_json).not_to be_nil
            # --------------------------------------

            # force deploy role vms
            get_roles(service_json).each do |role|
                if role["nodes"]
                  cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
                else
                  raise "nodes not found"
                end
            end

            service_id = service_json['DOCUMENT']['ID']
            # wait until the service is RUNNING
            wait_state(service_id, 2, 30)
        rescue StandardError => e
            @utils.save_temp_screenshot("instantiate-service-template", e)
        end
    end

    it "should check user inputs in role vms" do
        service_json = cli_action_json("oneflow show #{SERVICE_NAME} -j")

        # check INPUTS each role VM
        get_roles(service_json).each { |role|
            vm_id = get_deploy_id(role)

            xml_vm = cli_action_xml("onevm show -x #{vm_id}") rescue nil

            role['user_inputs_values'].collect { |input, value|
                expect(xml_vm["TEMPLATE/CONTEXT/#{input}"]).to eql value
            }
        }
    end

    it "should check NIC and Alias in role vms datatable" do
        service_json = cli_action_json("oneflow show #{SERVICE_NAME} -j")

        # check NIC's each role VM's datatable
        get_roles(service_json).each { |role|
            vm_id = get_deploy_id(role)

            ips = @flow.get_nics_in_role_dt(SERVICE_NAME, role['name'], vm_id.to_s)

            xml = cli_action_xml("onevm show -x #{vm_id}") rescue nil

            expect(ips.include?(xml['TEMPLATE/NIC/IP'])).to be true
            expect(ips.include?(xml['TEMPLATE/NIC_ALIAS/IP'])).to be true
        }
    end

    it "should check charters into service instantiated" do
        @flow.check_charters_dialog(SERVICE_NAME)
    end

    it "should check VNC button in datatable of role vms" do
        begin

        vnc_button = @flow.get_vnc_button(SERVICE_NAME, ROLE_NAME)

        expect(vnc_button).not_to be(false)
        rescue StandardError => e
            @utils.save_temp_screenshot("check-VNC-button", e)
        end
    end

    it "should clone a service template" do
        template_name = SERVICE_NAME
        clone_template_name = "none_#{template_name}"
        clone_vm_template_name = "vm_template-#{clone_template_name}"
        clone_image_template_name = "#{clone_vm_template_name}-disk-0"

        @flow.clone_template(template_name, clone_template_name, "none")

        @sunstone_test.wait_resource_create("flow-template", clone_template_name)
        expect(cli_action_json("oneflow-template show #{clone_template_name} -j")).not_to be_nil

        cli_action("onetemplate show #{clone_vm_template_name}", false)
        cli_action("oneimage show #{clone_image_template_name}", false)
    end

    it "should clone a service template recursively with just template" do
        template_name = SERVICE_NAME
        clone_template_name = "templates_#{template_name}"
        clone_vm_template_name = "vm_template-#{clone_template_name}"
        clone_image_template_name = "#{clone_vm_template_name}-disk-0"

        @flow.clone_template(template_name, clone_template_name, "templates")

        @sunstone_test.wait_resource_create("flow-template", clone_template_name)
        expect(cli_action_json("oneflow-template show #{clone_template_name} -j")).not_to be_nil

        @sunstone_test.wait_resource_create("template", clone_vm_template_name)
        expect(cli_action_xml("onetemplate show #{clone_vm_template_name} -x")).not_to be_nil

        cli_action("oneimage show #{clone_image_template_name}", false)
    end

    it "should clone a service template recursively with all" do
        template_name = SERVICE_NAME
        clone_template_name = "all_#{template_name}"
        clone_vm_template_name = "vm_template-#{clone_template_name}"
        clone_image_template_name = "#{clone_vm_template_name}-disk-0"

        @flow.clone_template(template_name, clone_template_name, "all")

        @sunstone_test.wait_resource_create("flow-template", clone_template_name)
        expect(cli_action_json("oneflow-template show #{clone_template_name} -j")).not_to be_nil

        @sunstone_test.wait_resource_create("template", clone_vm_template_name)
        expect(cli_action_xml("onetemplate show #{clone_vm_template_name} -x")).not_to be_nil

        @sunstone_test.wait_resource_create("image", clone_image_template_name)
        expect(cli_action_xml("oneimage show #{clone_image_template_name} -x")).not_to be_nil
    end

    it "should delete role service templates" do
        template_name = SERVICE_NAME
        @flow.remove_roles(template_name, [ROLE_NAME_SLAVE] )
        
        # Needs to wait a little so the update is received by the core
        sleep 2

        template = cli_action_json("oneflow-template show #{template_name} -j")
        expect(template["DOCUMENT"]["TEMPLATE"]["BODY"]["roles"].length).to be(1)
    end

    it "should instantiate a service with a VMGroup from Services tab" do
        # Create a service template to work with on this test
        service_name = "oneflow_test_instantiate"
        description = "Template to test oneflow service instantiate in Sunstone"
        roles = [
            create_role_json(ROLE_NAME, @template_id),
            create_role_json(ROLE_NAME_SLAVE, @template_id)
        ]

        service_template = create_service_template_json(service_name, description, roles)
        @flow.create_template(service_template)
        @sunstone_test.wait_resource_create("flow-template", service_name)
        
        # Create a VM group to assign it
        hash_roles = {
            :roles => [
                { :name => 'master', :affinity => "NONE"}
            ]
        }
        @vmgroup.create_for_service(VMGROUP_NAME, hash_roles)

        @flow.navigate_create_instantiate(service_name, 'master', VMGROUP_NAME)
        @sunstone_test.wait_resource_create("flow", service_name)

        pass = false
        data = cli_action_json("oneflow show -j #{service_name}") rescue nil
        if data["DOCUMENT"] && data["DOCUMENT"]["TEMPLATE"] && data["DOCUMENT"]["TEMPLATE"]["BODY"] && data["DOCUMENT"]["TEMPLATE"]["BODY"]["roles"]
            roles = data["DOCUMENT"]["TEMPLATE"]["BODY"]["roles"]
            roles.each do |role|
            if role["name"] == 'master' && role["vm_template_contents"]
                if role["vm_template_contents"].include? "ROLE = \"master\""
                pass = true
                end
            end
            end
        end
        expect(pass).to be(true)
    end

    it "should delete service template and related VM templates" do
        @flow.delete_template(@service_delete_tmp_name,'templates')
        wait_service_template_delete(@service_delete_tmp_name)
        
        check_image = check_command_cli("oneimage show #{@service_delete_tmp_name} -j")
        check_template = check_command_cli("onetemplate show #{@service_delete_tmp_name} -j")
        expect(check_image && !check_template).to be(true)
    end

    it "should delete service template and its related VM templates and its images" do
        @flow.delete_template(@service_delete_tmp_img_name,'all')
        wait_service_template_delete(@service_delete_tmp_img_name)

        check_image = check_command_cli("oneimage show #{@service_delete_tmp_img_name} -j")
        check_template = check_command_cli("onetemplate show #{@service_delete_tmp_img_name} -j")
        expect(!check_image && !check_template).to be(true)
    end

    it "should delete service" do
        @flow.delete_template(@service_delete_name)
        wait_service_template_delete(@service_delete_name)

        check_image = check_command_cli("oneimage show #{@service_delete_name} -j")
        check_template = check_command_cli("onetemplate show #{@service_delete_name} -j")
        expect(!!check_image && !!check_template).to be(true)
    end

    it "should add charters in template instantiated and in the roles VMs" do
        begin
            @flow.navigate_service_dt()
            @flow.add_charters_service(@service_add_charters_name)
            sleep 30
            val_service_json = cli_action_json("oneflow show #{@service_add_charters_name} -j")
            expect(val_service_json).not_to be_nil
            #this check the roles
            get_roles(val_service_json).each do |role|
                #validate the role VM
                vm_template = cli_action_json("onevm show #{get_deploy_id(role)} -j")
                if vm_template["VM"]["TEMPLATE"]["SCHED_ACTION"] && vm_template["VM"]["TEMPLATE"]["SCHED_ACTION"].kind_of?(Array)
                  vm_template["VM"]["TEMPLATE"]["SCHED_ACTION"].each do |sched_action|
                    expect(["terminate", "suspend"]).to include(sched_action["ACTION"])
                  end
                else
                  raise "can't find schedule actions in vm template"
                end
            end
        rescue StandardError => e
            @utils.save_temp_screenshot("add-charters-in-template", e)
        end
    end

    it 'should delete a service when all VMs terminated' do
        @flow.navigate_template_dt 

        template = vm_template(false, "automatic_deletion")
        template_id = cli_create("onetemplate create", template)

        # Create a service template to work with on this test
        service_name = "oneflow_test_automatic_deletion"
        description = "Template to testing oneflow in Sunstone"
        roles = [
            create_role_json(ROLE_NAME, template_id, 1),
        ]
        automatic_deletion = true

        service_template = create_service_template_json(service_name, description, roles, automatic_deletion)
        service_id = create_and_instantiate_service(service_template)

        wait_state(service_name, 1) #deploying

        service   = cli_action_json("oneflow show -j #{service_id}")
        vm_id     = get_deploy_id(get_master(service))
        vm        = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} #{@host_id}" )
        vm.state?('RUNNING')
        wait_state(service_id, 2, 30)

        # Delete VM
        vm.info
        vm_name = vm['NAME']
        @vm.terminate(vm_name)
        @sunstone_test.wait_vm_delete(vm_id)

        # Automatic deletion should undeploy the flow
        wait_service_undeploy(service_id)
    end

    # This test does zone changes
    # It is better if its the last one
    #
    # It use the services creates at start to check if 
    # the datatable shows empty when performing a zone change
    it 'should show data for own opennebula zone' do
        begin
            @zone.change_zone("zone_flow")
            @flow.navigate_service_dt()
            expect(@flow.if_empty_datatable()).not_to be_nil
            @zone.change_zone("OpenNebula")
        rescue StandardError => e
            @utils.save_temp_screenshot("show-data-zone", e)
        end
    end

    after(:all) do
        stop_flow
        @sunstone_test.sign_out
    end
end
