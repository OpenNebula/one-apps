require 'init_functionality'
require 'flow_helper'

require_relative 'flow_operations'

require 'json'
require 'tempfile'

RSpec.describe 'OneFlow strategy STRAIGHT WITHOUT GATE' do
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
        template = service_template('straight')

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

        # take master and slave information
        master = get_master(service)
        slave  = get_slave(service)

        # check that only master is PENDING
        expect(master['state'].to_i).to eq(1)
        expect(slave['state'].to_i).to eq(0)

        cli_action("onevm deploy #{get_deploy_id(master)} #{@host_id}")

        # wait until master role is RUNNING
        wait_role_state(@service_id, 'master', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # take master and slave information
        master = get_master(service)
        slave  = get_slave(service)

        # check master is RUNNING and slave is PENDING
        expect(master['state'].to_i).to eq(2)
        expect(slave['state'].to_i).to eq(1)

        cli_action("onevm deploy #{get_deploy_id(slave)} #{@host_id}")

        # wait until slave role is RUNNING
        wait_role_state(@service_id, 'slave', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # take master and slave information
        master = get_master(service)
        slave  = get_slave(service)

        # check master and slave are RUNNING
        expect(master['state'].to_i).to eq(2)
        expect(slave['state'].to_i).to eq(2)
    end

    it 'undeploy service' do
        cli_action("oneflow delete #{@service_id}")

        wait_loop do
            if system("oneflow show -j #{@service_id} &> /dev/null")
                service = cli_action_json("oneflow show -j #{@service_id}")
                state   = get_state(service)

                # take master and slave information
                master = get_master(service)
                slave  = get_slave(service)

                # if slave is undeploying, master should be running
                if slave['state'].to_i == 3
                    expect(master['state'].to_i).to eq(2)
                # if slave is already undeployed,
                # master slave should be undeploying
                elsif slave['state'].to_i == 5 && state != 5
                    expect(master['state'].to_i).to eq(3)
                end
            else
                true
            end
        end
    end

    context 'flow operations' do
        include_examples 'flow_operations', false
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
