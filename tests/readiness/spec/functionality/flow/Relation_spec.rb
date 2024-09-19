require 'init_functionality'
require 'flow_helper'

require_relative 'flow_operations'

require 'json'
require 'tempfile'

RSpec.describe 'OneFlow STRAIGHT relations' do
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

        cli_action("onevm deploy #{get_deploy_id(master)} #{@host_id}")

        # wait until master role is RUNNING
        wait_role_state(@service_id, 'master', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # take master and slave information
        master = get_master(service)
        slave  = get_slave(service)

        cli_action("onevm deploy #{get_deploy_id(slave)} #{@host_id}")

        # wait until slave role is RUNNING
        wait_role_state(@service_id, 'slave', 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # take master and slave information
        slave = get_slave(service)
        vm    = cli_action_xml("onevm show #{slave['nodes'][0]['deploy_id']} -x")

        expect(vm['//NOT_FOUND']).to be_empty
        expect(vm['//TEST']).to eq('MASTER_0_(service_1)')
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
