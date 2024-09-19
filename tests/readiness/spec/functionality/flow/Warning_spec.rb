require 'init_functionality'
require 'flow_helper'

require 'json'
require 'tempfile'

RSpec.describe 'OneFlow warning state' do
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
        template = service_template('none', false, false, false, true)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")

        @service_id = cli_create("oneflow-template instantiate #{@template_id}")
    end

    it 'deploy all roles' do
        # flow state must be DEPLOYING
        wait_state(@service_id, 1, 30)

        service = cli_action_json("oneflow show -j #{@service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end
    end

    it 'check all nodes are running' do
        states = wait_state(@service_id, 2)

        # service and roles should be RUNNING
        states.each {|state| expect(state).to eq(2) }
    end

    it 'terminate VM to check that cardinality is adjusted' do
        service   = cli_action_json("oneflow show -j #{@service_id}")
        slave     = get_slave(service)
        deploy_id = get_deploy_id(slave)
        vm        = VM.new(deploy_id)

        cli_action("onevm terminate --hard #{deploy_id}")

        wait_loop do
            vm.info

            vm.state == 'DONE'
        end

        service = cli_action_json("oneflow show -j #{@service_id}")
        slave   = get_slave(service)

        # cardinality should be 0 because the role VM was terminated
        expect(slave['cardinality']).to eq(0)

        expect(slave['nodes'].empty?).to eq(true)

        # check that service is still RUNNING and don't change to WARNING
        expect(get_state(service)).to eq(2)
    end

    it 'power off VM so service enters in warning state' do
        service   = cli_action_json("oneflow show -j #{@service_id}")
        master    = get_master(service)
        deploy_id = get_deploy_id(master)

        cli_action("onevm poweroff --hard #{deploy_id}")

        wait_state(@service_id, 4)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        # service should be in WARNING state because vm is in UNKNOWN state
        expect(get_state(service)).to eq(4)

        # role should be in WARNING state too
        expect(master['state'].to_i).to eq(4)
    end

    it 'wait until VM is monitored again so service enters in RUNNING state' do
        service   = cli_action_json("oneflow show -j #{@service_id}")
        master    = get_master(service)
        deploy_id = get_deploy_id(master)

        cli_action("onevm resume #{deploy_id}")

        wait_state(@service_id, 2)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        # service should be in RUNNING state because vm is monitored
        expect(get_state(service)).to eq(2)

        # role should be in RUNNING state too
        expect(master['state'].to_i).to eq(2)
    end

    it 'undeploy service' do
        service   = cli_action_json("oneflow show -j #{@service_id}")
        master    = get_master(service)
        deploy_id = get_deploy_id(master)
        vm        = VM.new(deploy_id)

        cli_action("onevm terminate --hard #{deploy_id}")

        wait_loop do
            vm.info

            vm.state == 'DONE'
        end

        # Automatic deletion should undeploy the flow
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
