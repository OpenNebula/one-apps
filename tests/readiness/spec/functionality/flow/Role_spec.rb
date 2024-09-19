require 'init_functionality'
require 'flow_helper'

require_relative 'flow_operations'

require 'json'
require 'tempfile'

# Check role is correctly added
def check_add(role, size)
end

RSpec.describe 'OneFlow strategy NONE' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        # create virtual network
        template = <<-EOF
                NAME   = public
                VN_MAD = dummy
                BRIDGE = br0
                AR = [
                    TYPE = IP4,
                    IP   = "1.1.1.1",
                    SIZE = 20
                ]
            EOF

        template_file = Tempfile.new('vnet')
        template_file << template
        template_file.close

        @vnet = cli_create("onevnet create #{template_file.path}")

        # Create VM template
        template = vm_template

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        cli_action("onetemplate create #{template_file.path}")

        # Create Service template
        template = service_template('none', false, true)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        tempfile = Tempfile.new('flow-net')
        # create extra template
        tempfile << "{\"networks_values\":[{\"Public\":{\"id\":\"0\"}}]}"
        tempfile.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")
        @service_id  = cli_create("oneflow-template instantiate #{@template_id} #{tempfile.path}")
    end

    it 'instantiate service template' do
        # wait until the service is DEPLOYING
        wait_state(@service_id, 1, 30)
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

    ############################################################################
    # Add Role
    ############################################################################

    it 'add role' do
        role = ''

        role << '{'
        role << "\"name\": \"MASTER_1\","
        role << "\"cardinality\": 1,"
        role << "\"vm_template\": 0,"
        role << "\"min_vms\": 1,"
        role << "\"max_vms\": 2,"
        role << "\"vm_template_contents\": \"NIC=[NETWORK_ID=$Public]\","
        role << "\"elasticity_policies\": [],"
        role << "\"scheduled_policies\": []"
        role << '}'

        cli_update("oneflow add-role #{@service_id}", role, false)

        service = cli_action_json("oneflow show -j #{@service_id}")

        # service should be DEPLOYING
        expect(get_state(service)).to eq(1)

        # get role
        role = get_role(service, 'MASTER_1')

        # role should be DEPLOYING
        expect(Integer(role['state'])).to eq(1)

        cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")

        states = wait_state(@service_id, 2)

        # service and roles should be RUNNING
        states.each {|state| expect(state).to eq(2) }

        service = cli_action_json("oneflow show -j #{@service_id}")

        expect(get_roles(service).size).to eq(3)
    end

    it 'add role that already exists [FAIL]' do
        role = ''

        role << '{'
        role << "\"name\": \"MASTER\","
        role << "\"cardinality\": 1,"
        role << "\"vm_template\": 0,"
        role << "\"min_vms\": 1,"
        role << "\"max_vms\": 2,"
        role << "\"elasticity_policies\": [],"
        role << "\"scheduled_policies\": []"
        role << '}'

        cmd = cli_update("oneflow add-role #{@service_id}", role, false, false)
        expect(cmd.stderr.strip).to match('Role MASTER already exists')
    end

    it 'add malformed role [FAIL]' do
        role = ''

        role << "\"name\": \"MASTER\","
        role << "\"cardinality\": 1,"
        role << "\"vm_template\": 0,"
        role << "\"min_vms\": 1,"
        role << "\"max_vms\": 2,"
        role << "\"elasticity_policies\": [],"
        role << "\"scheduled_policies\": []"
        role << '}'

        cmd = cli_update("oneflow add-role #{@service_id}", role, false, false)
        expect(cmd.stderr.include?("unexpected token at '")).to eq(true)
    end

    it 'add wrong format JSON [FAIL]' do
        role = ''

        role << '{'
        role << "\"cardinality\": 1,"
        role << "\"vm_template\": 0,"
        role << "\"min_vms\": 1,"
        role << "\"max_vms\": 2,"
        role << "\"elasticity_policies\": [],"
        role << "\"scheduled_policies\": []"
        role << '}'

        cmd = cli_update("oneflow add-role #{@service_id}", role, false, false)
        expect(cmd.stderr.strip).to match("KEY: 'name' is required;")
    end

    ############################################################################
    # Remove Role
    ############################################################################

    it 'remove role' do
        cli_action("oneflow remove-role #{@service_id} MASTER_1")

        wait_state(@service_id, 2)

        service = cli_action_json("oneflow show -j #{@service_id}")

        expect(get_roles(service).size).to eq(2)
        expect(get_role(service, 'MASTER_1')).to be_nil
    end

    it 'remove role that does not exist [FAIL]' do
        cmd = cli_action("oneflow remove-role #{@service_id} not_exist", false)
        expect(cmd.stderr.strip).to match('Role not_exist does not exist')
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
