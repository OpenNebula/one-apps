require 'init_functionality'
require 'flow_helper'
require 'sunstone_test'
require 'sunstone/Flow'
require 'sunstone/Vm'

RSpec.describe "Sunstone features", :type => 'skip' do
    include FlowHelper

    def restart_sunstone
        @one_test.stop_sunstone
        @one_test.start_sunstone
    end

    # Returns VM template
    def vm_template(image = false)
        template = <<-EOF
		NAME   = test_template
		CPU    = 1
		MEMORY = 128
		DISK = [
			IMAGE       = "test_img",
			IMAGE_UNAME = "oneadmin"
		]
        EOF
    end

	# Returns VNet template
    def vnet_template
        template = <<-EOF
            NAME   = public
            VN_MAD = dummy
            BRIDGE = br0
            AR = [
                TYPE = IP4,
                IP   = "1.1.1.1",
                SIZE = 20
            ]
        EOF
    end

    def change_feature(change, view = 'mixed/admin.yaml')
     	system "sed -i -e '#{change}' #{ONE_ETC_LOCATION}/sunstone-views/#{view}"
    end

    def update_feature(feature, old_value, new_value)
      	change_feature "s/#{feature}: #{old_value}/#{feature}: #{new_value}/"
    end

    ## -----------------------------------------------------------------------------------
    ## -----------------------------------------------------------------------------------

    before(:all) do
        update_feature('instantiate_hide_cpu', false, true)
        update_feature('instantiate_cpu_factor', false, 0.5)
        update_feature('show_vnet_instantiate_flow', true, false)

        restart_sunstone
        start_flow

        # Create Sunstone
        user = @client.one_auth.split(':')
        @auth = { :username => user[0], :password => user[1] }
        @sunstone_test = SunstoneTest.new(@auth)

        # Create dummy host
        @host_id = cli_create('onehost create localhost --im dummy --vm dummy')

        # Create Image
        @img_id = cli_create("oneimage create --name 'test_img' --size 1 -d default")
        @sunstone_test.wait_resource_create('image', 'test_img')

        # Create VM template
        template = vm_template(true)
        template.concat("GRAPHICS = [ LISTEN = \"0.0.0.0\", TYPE = \"VNC\" ]")
        @template_id = cli_create("onetemplate create", template)
        @sunstone_test.wait_resource_create('template', 'test_template')

        # Create VNet
        @vnet_id = cli_create('onevnet create', vnet_template)
        @sunstone_test.wait_resource_create('vnet', 'public')

        # Create Service template (name: TEST)
        flow_template = service_template('none', false, true)
        @flow_template_id = cli_create('oneflow-template create', flow_template)
        @sunstone_test.wait_resource_create('flow-template', 'TEST')

        # Login with credentials in Sunstone
        @sunstone_test.login

        @flow = Sunstone::Flow.new(@sunstone_test)
        @vm = Sunstone::Vm.new(@sunstone_test)
    end

	# feature: show_vnet_instantiate_flow
    it "should hide the network configuration to instantiate service template" do
        @flow.navigate_template_dt
        @flow.select_by_column('TEST', 4, 'dataTableServiceTemplates')
        sleep 1
        @flow.navigate_instantiate
		sleep 1

		network_section_xpath = "//*[@id='instantiateServiceTemplateFormWizard']//legend[text()='Network']"
		section = @sunstone_test.get_element_by_xpath(network_section_xpath)
        expect(section).to be false
    end

	# feature: instantiate_hide_cpu
    it "should hide the CPU setting in the VM creation dialog" do
        @vm.navigate_instantiate('test_template')
		sleep 1

		cpu_input_xpath = "//*[@id='instantiateTemplateDialogWizard']//*[starts-with(@class, 'cpu_input_wrapper')]"
		section = @sunstone_test.get_element_by_xpath(cpu_input_xpath)
        expect(section).to be false
    end

	# feature: instantiate_cpu_factor
	it "should scale the CPU from VCPU" do
		hash = {
			:name => 'test_cpu_factor_vm',
			:mem => '0.5',
			:vcpu => '2'
		}

		@vm.navigate_instantiate('test_template')
		sleep 1
		@vm.instantiate(hash)
		@sunstone_test.wait_resource_create("vm", hash[:name])

		vm = cli_action_xml("onevm show -x '#{hash[:name]}'") rescue nil
        expect(vm["TEMPLATE/CPU"]).to eql "1"

    end

    before(:each) do
        sleep 1
    end

	after(:all) do
		update_feature('instantiate_hide_cpu', true, false)
        update_feature('instantiate_cpu_factor', 0.5, false)
        update_feature('show_vnet_instantiate_flow', false, true)
        stop_flow
        @sunstone_test.sign_out
    end
end
