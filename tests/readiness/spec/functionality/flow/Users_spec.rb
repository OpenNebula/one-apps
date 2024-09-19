require 'init_functionality'
require 'flow_helper'

require 'tempfile'

RSpec.describe 'OneFlow ownership' do
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
        template = service_template('none')

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")
        @service_id  = cli_create("oneflow-template instantiate #{@template_id}")
        @user_id     = cli_create('oneuser create test_user test')
    end

    it 'deploy service' do
        # wait until the service is DEPLOYING
        wait_state(@service_id, 1, 30)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action(
                "onevm deploy #{get_deploy_id(role)} #{@host_id}"
            )
        end

        # wait until the service is RUNNING
        wait_state(@service_id, 2)
    end

    it 'change ownership of the flow' do
        cli_action("oneflow chown #{@service_id} #{@user_id}")

        service = cli_action_json("oneflow show -j #{@service_id}")

        expect(service['DOCUMENT']['UID'].to_i).to eq(@user_id.to_i)
    end

    it 'scale service' do
        cli_action("oneflow scale #{@service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        # wait until the service is RUNNING
        wait_state(@service_id, 2)

        service   = cli_action_json("oneflow show -j #{@service_id}")
        master    = get_master(service)
        deploy_id = get_deploy_id(master, 1)

        vm = cli_action_xml("onevm show #{deploy_id} -x")

        expect(vm['UID'].to_i).to eq(@user_id.to_i)
    end

    it 'delete service' do
        cli_action("oneflow delete #{@service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
