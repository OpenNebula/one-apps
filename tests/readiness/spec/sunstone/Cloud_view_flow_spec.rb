require 'init_functionality'
require 'flow_helper'
require 'sunstone_test'
require 'sunstone/CloudView'
require 'sunstone/Flow'

RSpec.describe "Sunstone services (flow) tab", :type => 'skip' do
    include FlowHelper

    def build_vnet_template(name, size, extra_attributes = '')
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[ TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end

    #----------------------------------------------------------------------
    #----------------------------------------------------------------------

    before(:all) do
        start_flow

        user = @client.one_auth.split(":")
        @auth = { :username => user[0], :password => user[1] }

        @sunstone_test = SunstoneTest.new(@auth)
        @cloudview = Sunstone::CloudView.new(@sunstone_test)
        @flow = Sunstone::Flow.new(@sunstone_test)

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

        # Login with credentials in Sunstone
        @sunstone_test.login

        @simple_service_template = {
            info: {
                name: 'oneflow_test',
                description: 'Template to testing oneflow in Sunstone'
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
                {
                    name: 'master',
                    cardinality: "1",
                    template_vm_id: @template_id.to_s,
                    networks: [
                      { name: 'public' },
                      { name: 'private', alias: 'public' }
                    ],
                    elasticity: { min_vms: '0', max_vms: '1', cooldown: '5' }
                },
                {
                  name: 'minion',
                  template_vm_id: @template_id.to_s,
                  networks: [
                    { name: 'public' },
                    { name: 'private', alias: 'public' }
                  ]
                }
            ]
        }
    end

    it "(admin view) should create a service template" do
        @flow.create_template(@simple_service_template)
        @sunstone_test.wait_resource_create("flow-template", @simple_service_template[:info][:name])
        template_service = cli_action_json("oneflow-template show #{@simple_service_template[:info][:name]} -j")
        expect(template_service).not_to be_nil
    end

    it "(cloud view) should instantiate a service template" do
        # change to cloud view
        @cloudview.navigate

        template_name = @simple_service_template[:info][:name]

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

        service = { info: { name: template_name }, roles: roles }
        @cloudview.instantiate_flow_template(template_name, service)

        @sunstone_test.wait_resource_create("flow", service[:info][:name])

        service_json = cli_action_json("oneflow show #{service[:info][:name]} -j")

        # --------------------------------------

        # force deploy role vms
        get_roles(service_json).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        service_id = service_json['DOCUMENT']['ID']
        # wait until the service is RUNNING
        wait_state(service_id, 2, 30)
    end

    it "(cloud view) should check user inputs in role vms" do
        service_name = @simple_service_template[:info][:name]

        service_json = cli_action_json("oneflow show #{service_name} -j")

        # check INPUTS each role VM
        get_roles(service_json).each { |role|
            vm_id = get_deploy_id(role)

            xml_vm = cli_action_xml("onevm show -x #{vm_id}") rescue nil

            role['user_inputs_values'].collect { |input, value|
                expect(xml_vm["TEMPLATE/CONTEXT/#{input}"]).to eql value
            }
        }
    end

    it "(cloud view) should change cardinality to role vm" do
        service_name = @simple_service_template[:info][:name]
        role_master_name = @simple_service_template[:roles][0][:name] # role master
        new_cardinality = 0

        @cloudview.change_flow_role_cardinality(service_name, role_master_name, new_cardinality)
        
        service_json = cli_action_json("oneflow show #{service_name} -j")

        service_id = service_json['DOCUMENT']['ID']
        # wait until the service is RUNNING
        wait_state(service_id, 2, 30)
        
        # refresh service json
        service_json = cli_action_json("oneflow show #{service_name} -j")

        master_json = get_master(service_json)
        expect(master_json['cardinality']).to eql new_cardinality
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        stop_flow
        @sunstone_test.sign_out
    end
end
