require 'init_functionality'
require 'flow_helper'

require_relative 'flow_operations'

require 'json'
require 'tempfile'

RSpec.describe 'OneFlow strategy NONE' do
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

        @service_id = cli_create("oneflow-template instantiate #{@template_id}")
    end

    it 'instantiate service template' do
        # wait until the service is DEPLOYING
        wait_state(@service_id, 1, 30)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # all service roles should be PENDING
        get_roles(service).each do |role|
            expect(role['state'].to_i).to eq(1)
        end
    end

    it 'deploy all roles' do
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

    it 'undeploy service' do
        cli_action("oneflow delete #{@service_id}")

        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    ############################################################################
    # RECOVER
    ############################################################################
    it 'recover deploy' do
        File.open('/tmp/opennebula_dummy_actions/deploy', 'w') do |file|
            file.write("0\n")
            file.write("0\n")
            file.write("1\n")
            file.write("1\n")
        end

        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1, 30)

        service    = cli_action_json("oneflow show -j #{service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(service_id, 7)

        # deploy should fail and put the service on FAILED_DEPLOYING
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(7)

        cli_action("oneflow recover #{service_id}")

        wait_state(service_id, 2)

        # recover the service should put the service in RUNNING
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(2)

        cli_action("oneflow delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        FileUtils.rm('/tmp/opennebula_dummy_actions/deploy')
    end

    it 'recover scale' do
        File.open('/tmp/opennebula_dummy_actions/deploy', 'w') do |file|
            file.write("1\n")
            file.write("1\n")
            file.write("0\n")
            file.write("1\n")
        end

        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1, 30)

        service    = cli_action_json("oneflow show -j #{service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(service_id, 2)

        cli_action("oneflow scale #{service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        wait_state(service_id, 9)

        # scale should fail and put the service on FAILED_SCALING
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(9)

        cli_action("oneflow recover #{service_id}")

        wait_state(service_id, 2)

        # recover the service should put the service in RUNNING
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(2)

        cli_action("oneflow delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        FileUtils.rm('/tmp/opennebula_dummy_actions/deploy')
    end

    it 'recover delete' do
        File.open('/tmp/opennebula_dummy_actions/deploy', 'w') do |file|
            file.write("0\n")
            file.write("0\n")
            file.write("1\n")
            file.write("1\n")
        end

        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1, 30)

        service    = cli_action_json("oneflow show -j #{service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(service_id, 7)

        # deploy should fail and put the service on FAILED_DEPLOYING
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(7)

        cli_action("oneflow recover --delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        FileUtils.rm('/tmp/opennebula_dummy_actions/deploy')
    end

    it 'recover [FAIL]' do
        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1, 30)

        service    = cli_action_json("oneflow show -j #{service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(service_id, 2)

        # should fail to recover a RUNNING service
        cli_action("oneflow recover #{service_id}", false)

        cli_action("oneflow delete #{service_id}")

        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end
    end

    context 'flow operations' do
        include_examples 'flow_operations', true
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
