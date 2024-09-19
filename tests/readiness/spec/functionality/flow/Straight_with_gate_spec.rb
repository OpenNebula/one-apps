require 'init_functionality'
require 'flow_helper'

require 'json'
require 'tempfile'

RSpec.describe 'OneFlow strategy STRAIGHT WITH GATE' do
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
        template = service_template('straight', true)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")

        @service_id = cli_create("oneflow-template instantiate #{@template_id}")
    end

    it 'instantiate service template' do
        # wait until the service is DEPLOYING
        wait_state(@service_id, 1, 30)
    end

    it 'check all nodes are running' do
        service = cli_action_json("oneflow show -j #{@service_id}")

        master    = get_master(service)
        slave     = get_slave(service)
        deploy_id = get_deploy_id(master)

        # check that only master is PENDING
        expect(master['state'].to_i).to eq(1)
        expect(slave['state'].to_i).to eq(0)

        cli_action("onevm deploy #{deploy_id} #{@host_id}")

        # wait until master VM is RUNNING
        vm = VM.new(deploy_id)

        wait_loop do
            vm.state == 'RUNNING'
        end

        service = cli_action_json("oneflow show -j #{@service_id}")

        master = get_master(service)
        slave  = get_slave(service)

        # check that only master is PENDING
        expect(master['state'].to_i).to eq(1)
        expect(slave['state'].to_i).to eq(0)

        # fake onegate operation
        cli_update("onevm update #{deploy_id}", 'READY=YES', true)

        wait_role_state(@service_id, 'master', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        master    = get_master(service)
        slave     = get_slave(service)
        deploy_id = get_deploy_id(slave)

        # check that master is RUNNING and slave is PENDING
        expect(master['state'].to_i).to eq(2)
        expect(slave['state'].to_i).to eq(1)

        cli_action("onevm deploy #{deploy_id} #{@host_id}")

        # wait until master VM is RUNNING
        vm = VM.new(deploy_id)

        wait_loop do
            vm.state == 'RUNNING'
        end

        service = cli_action_json("oneflow show -j #{@service_id}")

        master = get_master(service)
        slave  = get_slave(service)

        # check that master is RUNNING and slave is PENDING
        expect(master['state'].to_i).to eq(2)
        expect(slave['state'].to_i).to eq(1)

        # fake onegate operation
        cli_update("onevm update #{deploy_id}", 'READY=YES', true)

        wait_role_state(@service_id, 'slave', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        master = get_master(service)
        slave  = get_slave(service)

        # check that master is RUNNING and slave is PENDING
        expect(master['state'].to_i).to eq(2)
        expect(slave['state'].to_i).to eq(2)
        expect(get_state(service)).to eq(2)
    end

    it 'scale UP' do
        cli_action("oneflow scale #{@service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{@service_id}")
        master    = get_master(service)
        deploy_id = get_deploy_id(master, 1)

        expect(master['state'].to_i).to eq(8)

        cli_action("onevm deploy #{deploy_id} #{@host_id}")

        # wait until master VM is RUNNING
        vm = VM.new(deploy_id)

        wait_loop do
            vm.state == 'RUNNING'
        end

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        expect(master['state'].to_i).to eq(8)

        # fake onegate operation
        cli_update("onevm update #{deploy_id}", 'READY=YES', true)

        wait_role_state(@service_id, 'master', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        expect(master['state'].to_i).to eq(2)
    end

    it 'undeploy service' do
        cli_action("oneflow delete #{@service_id}")

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
