require 'init_functionality'
require 'flow_helper'

require 'json'
require 'tempfile'

# Check elasticity policy
#
# @param type      [String]  Policy type
# @param adjust    [Integer] Number of VMs to add/sub
# @param val       [String]  Value to update in VM
# @param size      [Integer] Role nodes number
# @param expr      [String]  Expression to evaluate
def policy(type, adjust, val, size, expr)
    # Create change object
    change = {}
    change['type']          = type
    change['adjust']        = adjust
    change['expression']    = expr
    change['period_number'] = 2
    change['period']        = 2
    change['cooldown']      = 10

    # Create Service template
    template = JSON.parse(service_template('none'))

    # Add change information
    template['roles'][1]['elasticity_policies'] << change

    template_file = Tempfile.new('service_template')
    template_file << template.to_json
    template_file.close

    template_id = cli_create("oneflow-template create #{template_file.path}")
    service_id  = cli_create("oneflow-template instantiate #{template_id}")

    # flow state must be DEPLOYING
    wait_state(service_id, 1)

    # Deploy all roles
    service = cli_action_json("oneflow show -j #{service_id}")

    # speed up VM deployment if vms still on pending
    get_roles(service).each do |role|
        deploy_id = get_deploy_id(role)

        try_deploy(deploy_id, @host_id)
    end

    # Wait until the flow is RUNNING
    wait_state(service_id, 2)

    service   = cli_action_json("oneflow show -j #{service_id}")
    slave     = get_slave(service)
    deploy_id = get_deploy_id(slave)

    cli_update("onevm update #{deploy_id}", val, true)

    if adjust > 0
        # Wait until the flow is SCALING because auto policy
        wait_state(service_id, 8)

        service = cli_action_json("oneflow show -j #{service_id}")

        slave     = get_slave(service)
        deploy_id = get_deploy_id(slave, 1)

        # try to speed up VM deployment
        try_deploy(deploy_id, @host_id)
    else
        # Wait until the flow is COLDOWN because auto policy
        wait_state(service_id, 10)
    end

    # Wait until the flow is RUNNING
    wait_state(service_id, 2)

    service = cli_action_json("oneflow show -j #{service_id}")
    slave   = get_slave(service)

    expect(slave['nodes'].size).to eq(size)

    cli_action("oneflow delete #{service_id}")

    wait_loop do
        !system("oneflow show #{service_id} > /dev/null")
    end
end

# Check scheduled policy
#
# @param type      [String]  Policy type
# @param adjust    [Integer] Number of VMs to add/sub
# @param size      [Integer] Role nodes number
def scheduled(type, adjust, size)
    # Create schedule object
    sched = {}
    sched['type']       = type
    sched['adjust']     = adjust
    sched['recurrence'] = '*/1 * * * *'
    sched['cooldown']   = 10

    # Create Service template
    template = JSON.parse(service_template('none'))

    # Add change information
    template['roles'][1]['scheduled_policies'] << sched

    template_file = Tempfile.new('service_template')
    template_file << template.to_json
    template_file.close

    template_id = cli_create("oneflow-template create #{template_file.path}")
    service_id  = cli_create("oneflow-template instantiate #{template_id}")

    # flow state must be DEPLOYING
    wait_state(service_id, 1)

    # Deploy all roles
    service = cli_action_json("oneflow show -j #{service_id}")

    get_roles(service).each do |role|
        deploy_id = get_deploy_id(role)

        try_deploy(deploy_id, @host_id)
    end

    # Wait until the flow is RUNNING
    wait_state(service_id, 2)

    if adjust > 0
        # Wait until the flow is SCALING because auto policy
        wait_state(service_id, 8)

        service = nil
        slave   = nil

        # sometimes the service info is updated a bit later
        wait_loop do
            service = cli_action_json("oneflow show -j #{service_id}")
            slave   = get_slave(service)

            break if slave['nodes'].size > 1
        end

        deploy_id = get_deploy_id(slave, 1)

        # try to speed up VM deployment
        try_deploy(deploy_id, @host_id)
    else
        # Wait until the flow is COLDOWN because auto policy
        wait_state(service_id, 10)
    end

    # Wait until the flow is RUNNING
    wait_state(service_id, 2)

    service = cli_action_json("oneflow show -j #{service_id}")
    slave   = get_slave(service)

    expect(slave['nodes'].size).to eq(size)

    cli_action("oneflow delete #{service_id}")

    wait_loop do
        !system("oneflow show #{service_id} > /dev/null")
    end
end

def try_deploy(vm_id, host_id)
    vm = VM.new(vm_id)
    cli_action("onevm deploy #{vm_id} #{host_id}") if vm.state == 'PENDING'
end

RSpec.describe 'OneFlow AutoScaling' do
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
    end

    it 'CHANGE UP policy' do
        policy('CHANGE', 1, 'ATT=60', 2, 'ATT > 50')
    end

    it 'CHANGE DOWN policy' do
        policy('CHANGE', -1, 'ATT=40', 0, 'ATT < 50')
    end

    it 'CARDINALITY UP policy' do
        policy('CARDINALITY', 2, 'ATT=60', 2, 'ATT > 50')
    end

    it 'CARDINALITY DOWN policy' do
        policy('CARDINALITY', 0, 'ATT=40', 0, 'ATT < 50')
    end

    it 'PERCENTAGE_CHANGE UP policy' do
        policy('PERCENTAGE_CHANGE', 100, 'ATT=60', 2, 'ATT > 50')
    end

    it 'PERCENTAGE_CHANGE DOWN policy' do
        policy('PERCENTAGE_CHANGE', -100, 'ATT=40', 0, 'ATT < 50')
    end

    it 'SCHEDULE CHANGE UP policy' do
        scheduled('CHANGE', 1, 2)
    end

    it 'SCHEDULE CHANGE DOWN policy' do
        scheduled('CHANGE', -1, 0)
    end

    it 'SCHEDULE CARDINALITY UP policy' do
        scheduled('CARDINALITY', 2, 2)
    end

    it 'SCHEDULE CARDINALITY DOWN policy' do
        scheduled('CARDINALITY', 0, 0)
    end

    it 'SCHEDULE PERCENTAGE_CHANGE UP policy' do
        scheduled('PERCENTAGE_CHANGE', 100, 2)
    end

    it 'SCHEDULE PERCENTAGE_CHANGE DOWN policy' do
        scheduled('PERCENTAGE_CHANGE', -100, 0)
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
