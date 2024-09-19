require 'init_functionality'
require 'flow_helper'

RSpec.describe 'OneFlow instantiate on HOLD' do
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
        template = service_template('none', false, false, false, false, true)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create(
            "oneflow-template create #{template_file.path}"
        )
        @service_id = cli_create(
            "oneflow-template instantiate #{@template_id}"
        )
    end

    it 'instantiate service template' do
        # service should be HOLD
        wait_state(@service_id, 15)
        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_state(service)).to eq(15) # TODO: 15

        # all service roles should be HOLD
        get_roles(service).each do |role|
            expect(role['state'].to_i).to eq(11)
        end
    end

    it 'release service with vms on hold' do
        service = cli_action_json("oneflow show -j #{@service_id}")

        # all service roles should be HOLD
        get_roles(service).each do |role|
            expect(role['state'].to_i).to eq(11)
        end

        cli_action("oneflow release #{@service_id}")

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(@service_id, 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # all service roles should be RUNNING
        expect(get_state(service)).to eq(2)
        get_roles(service).each do |role|
            expect(role['state'].to_i).to eq(2)
        end
    end

    ############################################################################
    # FAILING OPERATIONS
    ############################################################################

    it 'release service of non-existing service' do
        cli_action('oneflow release 9999999', false)
    end

    it 'release service in RUNNING state' do
        # Check RUNNING state
        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_state(service)).to eq(2)

        # Try to release service
        cli_action("oneflow release #{@service_id}", false)
    end

    it 'release service with service on WARNING state' do
        service = cli_action_json("oneflow show -j #{@service_id}")

        # Poweroff vms to get WARNING service state
        get_roles(service).each do |role|
            cli_action("onevm poweroff #{get_deploy_id(role)}")
        end

        # Wait until WARNING
        wait_state(@service_id, 4)

        # Check warning state
        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_state(service)).to eq(4)

        # Try to release service
        cli_action("oneflow release #{@service_id}", false)
    end

    it 'release service with service on FAILED_DEPLOYMENT state' do
        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # service should be HOLD
        wait_state(service_id, 15)

        # all service roles should be HOLD
        service = cli_action_json("oneflow show -j #{service_id}")

        get_roles(service).each do |role|
            expect(role['state'].to_i).to eq(11)
        end

        # Release roles
        cli_action("oneflow release #{service_id}")

        %x(printf "%s\n" "failure" > /tmp/opennebula_dummy_actions/deploy)

        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # deploy should fail and put the service on FAILED_DEPLOYING
        wait_state(service_id, 7)
        service = cli_action_json("oneflow show -j #{service_id}")
        expect(get_state(service)).to eq(7)

        # Try to release service
        cli_action("oneflow release #{service_id}", false)
    end

    it 'release service with service on FAILED_SCALING state' do
        service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # service should be HOLD
        wait_state(service_id, 15)

        # Release roles
        cli_action("oneflow release #{service_id}")

        # Deploy roles
        service = cli_action_json("oneflow show -j #{service_id}")
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # Flow state must be RUNNING
        wait_state(service_id, 2)

        # Scale from RUNING state must transit to SCALING state
        cli_action("oneflow scale #{service_id} MASTER 2")
        wait_state(service_id, 8)

        # Cause failure on next deploy
        %x(printf "%s\n" "failure" > /tmp/opennebula_dummy_actions/deploy)

        # Deploy the scaled VM
        service = cli_action_json("oneflow show -j #{service_id}")
        vm_id = get_roles(service)[0]['nodes'][1]['deploy_id']
        cli_action("onevm deploy #{vm_id}, #{@host_id}")

        # After VM deploy failure state must transit
        # from SCALING to FAILED_SCALING
        wait_state(service_id, 9)

        # Try to release service
        cli_action("oneflow release #{service_id}", false)
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end

    after(:all) do
        stop_flow
    end
end
