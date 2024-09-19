require 'init_functionality'
require 'flow_helper'

require 'tempfile'

RSpec.describe 'OneFlow custom attributes' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        # Create VM template
        template = vm_template

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        cli_action("onetemplate create #{template_file.path}")

        # Create Service template
        template = service_template('none', false, false, true, false, false, false)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")

        # Create Service template with custom role attributes
        template = service_template('none', false, false, true, false, false, true)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template2_id = cli_create("oneflow-template create #{template_file.path}")
    end

    it 'instantiate service with custom attributes values using stdin template' do
        extra_template = '{"custom_attrs_values":{"Man": "mandatory"}}'
        cmd = "oneflow-template instantiate #{@template_id}"
        service_id = cli_create(cmd, extra_template)

        # flow state must be DEPLOYING
        wait_state(service_id, 1, 30)

        service = cli_action_json("oneflow show -j #{service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(service_id, 2)

        # check custom attributes values
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(service['DOCUMENT']['TEMPLATE']['BODY'] \
            ['custom_attrs_values']['Man']).to eq('mandatory')

        cli_action("oneflow delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end
    end

    it 'instantiate service with custom role attributes values' do
        tempfile = Tempfile.new('flow-custom')

        # create extra template
        tempfile << '{"custom_attrs_values":{"Man":"mandatory"},"roles":[{"name":"SLAVE"},' \
                    '{"name":"MASTER","custom_attrs_values":{"Man":"role-mandatory"}}]}'
        tempfile.close

        service_id = cli_create("oneflow-template instantiate #{@template2_id} #{tempfile.path}")

        # flow state must be DEPLOYING
        wait_state(service_id, 1, 30)

        service = cli_action_json("oneflow show -j #{service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(service_id, 2)

        # check custom attributes values
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(service['DOCUMENT']['TEMPLATE']['BODY']['roles'][1] \
            ['custom_attrs_values']['Man']).to eq('role-mandatory')

        cli_action("oneflow delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end
    end

    ############################################################################
    # FAILING OPERATIONS
    ############################################################################

    it 'instantiate service with wrong custom attributes values [FAIL]' do
        tempfile = Tempfile.new('flow-custom')

        # create extra template
        tempfile << '{"custom_attrs_values":{"M": "mandatory"}}'
        tempfile.close

        cli_action("oneflow-template instantiate #{@template_id} #{tempfile.path}", false)
    end

    it 'instantiate service with nil custom role attributes values [FAIL]' do
        tempfile = Tempfile.new('flow-custom')

        # create extra template with non custom role values
        tempfile << '{"custom_attrs_values":{"Man": "mandatory"}}'
        tempfile.close

        cli_action("oneflow-template instantiate #{@template2_id} #{tempfile.path}", false)
    end

    it 'instantiate service with wrong custom role attributes values [FAIL]' do
        tempfile = Tempfile.new('flow-custom')

        # create extra template with wrong role custom values
        tempfile << '{"custom_attrs_values":{"Man":"mandatory"},"roles":[{"name":"MASTER"},' \
                    '{"name":"SLAVE","custom_attrs_values":{"Man":"role-mandatory"}}]}'
        tempfile.close

        cli_action("oneflow-template instantiate #{@template2_id} #{tempfile.path}", false)
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
