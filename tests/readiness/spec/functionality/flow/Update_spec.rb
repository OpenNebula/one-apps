require 'init_functionality'
require 'flow_helper'

require 'tempfile'

# Update service template
#
# @param service_id [Integer] Service ID to check
# @param expected   [Boolean] False if update should fail
# @param append     [Boolean] True to append to template
#
# @return [JSON] New body
def update(service_id, expected = true, append = false)
    service = cli_action_json("oneflow show -j #{service_id}")
    body    = get_body(service)

    body = yield(body)

    # Update service
    template_file = Tempfile.new('service_template')
    template_file << body
    template_file.close

    if append
        cmd = "oneflow update #{service_id} #{template_file.path} --append"
    else
        cmd = "oneflow update #{service_id} #{template_file.path}"
    end

    cli_action(cmd, expected)

    get_body(cli_action_json("oneflow show -j #{service_id}"))
end

RSpec.describe 'OneFlow update service operation' do
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

        template_id = cli_create(
            "oneflow-template create #{template_file.path}"
        )

        # Instantiate Service Template
        @service_id = cli_create(
            "oneflow-template instantiate #{template_id}"
        )

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

    it 'update service description' do
        new_body = update(@service_id) do |body|
            # Change description
            body['description'] = 'new_description'
            body.to_json
        end

        expect(new_body['description']).to eq('new_description')
    end

    it 'update elasticity policies' do
        new_body = update(@service_id) do |body|
            # Add elasticity policy
            body['roles'][0]['min_vms'] = 0
            body['roles'][0]['max_vms'] = 4

            rule = { :type          => 'CHANGE',
                     :adjust        => 1,
                     :expression    => 'ATT>20',
                     :period_number => 2,
                     :period        => 2,
                     :cooldown      => 10 }

            body['roles'][0]['elasticity_policies'] << rule
            body.to_json
        end

        expect(new_body['roles'][0]['elasticity_policies'].size).to eq(1)
    end

    it 'check that elasticity policies are updated' do
        service = cli_action_json("oneflow show -j #{@service_id}")
        node    = get_deploy_id(get_master(service))

        # Update VM to set ATT
        cli_update("onevm update #{node}", 'ATT=80', true)

        # Wait until the service is SCALING
        wait_state(@service_id, 8)

        # Deploy roles
        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        # Wait until the service is RUNNING
        wait_state(@service_id, 2)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        expect(master['nodes'].size).to eq(2)
    end

    it 'update min_vms' do
        new_body = update(@service_id) do |body|
            # Change min_vms
            body['roles'][0]['min_vms'] = 2
            body.to_json
        end

        expect(new_body['roles'][0]['min_vms']).to eq(2)
    end

    it 'check that min_vms is updated' do
        cli_action("oneflow scale #{@service_id} MASTER 0 --force")

        # Wait until the service is RUNNING - we may miss the RUNNING
        # because it last only a second, instead wait for COOLDOWN
        wait_state(@service_id, 10)

        # Wait until the service is SCALING because min_vms
        wait_state(@service_id, 8)

        # Deploy roles
        service = cli_action_json("oneflow show -j #{@service_id}")

        get_master(service)['nodes'].each do |node|
            cli_action("onevm deploy #{node['deploy_id']} #{@host_id}")
        end

        # Wait until the service is RUNNING
        wait_state(@service_id, 2)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)

        expect(master['nodes'].size).to eq(2)
    end

    it 'update with append' do
        new_body = update(@service_id, true, true) do |_|
            # Add labels
            ret           = {}
            ret['labels'] = 'test'

            ret.to_json
        end

        expect(new_body['labels']).to eq('test')
    end

    ############################################################################
    # FAILING OPERATIONS
    ############################################################################

    it 'update immutable attr [FAIL]' do
        update(@service_id, false) do |body|
            body['state'] = 10
            body.to_json
        end
    end

    it 'update wrong JSON [FAIL]' do
        update(@service_id, false) do |_|
            'wrong JSON'
        end
    end

    it 'update [append] wrong JSON [FAIL]' do
        update(@service_id, false, true) do |_|
            'wrong JSON'
        end
    end

    it 'update wrong schema [FAIL]' do
        update(@service_id, false) do |body|
            body['description'] = {}
            body.to_json
        end
    end

    after(:all) do
        stop_flow
    end
end
