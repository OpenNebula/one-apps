shared_examples_for 'flow_operations' do |none|
    ############################################################################
    # CREATE A SERVICE FOR EACH TEST
    ############################################################################
    def none(service_id, host_id)
        service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))

        get_roles(service).each do |role|
            deploy_id = get_deploy_id(role)
            execute_cmd("onevm deploy #{deploy_id} #{host_id}")
        end

        wait_state(service_id, 2)
    end

    def straight(service_id, host_id)
        service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))
        master  = get_master(service)

        deploy_id = get_deploy_id(master)
        execute_cmd("onevm deploy #{deploy_id} #{host_id}")

        wait_role_state(service_id, 'master', 2)

        service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))
        slave   = get_slave(service)

        deploy_id = get_deploy_id(slave)
        execute_cmd("onevm deploy #{deploy_id} #{host_id}")

        wait_state(service_id, 2)
    end

    before(:each) do
        @service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # wait until the service is DEPLOYING
        wait_state(@service_id, 1, 30)

        if none
            none(@service_id, @host_id)
        else
            straight(@service_id, @host_id)
        end
    end

    after(:each) do
        cli_action("oneflow delete #{@service_id}")

        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    ############################################################################
    # CLI Auth
    ############################################################################

    it 'passes the authentication via CLI arguments' do
        auth = '-u oneadmin -p opennebula'
        cmd = "oneflow-template instantiate #{auth} #{@template_id}"

        service_id = cli_create(cmd)
        wait_state(service_id, 1, 30)

        if none
            none(service_id, @host_id)
        else
            straight(service_id, @host_id)
        end

        cmd = "oneflow delete #{auth} #{service_id}"
        cli_action(cmd)
    end

    ############################################################################
    # SCALE
    ############################################################################

    it 'scale UP' do
        cli_action("oneflow scale #{@service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        states = wait_state(@service_id, 2)

        # service and roles should be RUNNING
        states.each do |state|
            expect(state).to eq(2)
        end

        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_master(service)['nodes'].size).to eq(2)

        wait_state(@service_id, 2)
    end

    it 'scale DOWN' do
        cli_action("oneflow scale #{@service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        wait_state(@service_id, 2)

        cli_action("oneflow scale #{@service_id} MASTER 1")

        states = wait_state(@service_id, 2)

        # all states (service and roles) should be RUNNING
        states.each do |state|
            expect(state).to eq(2)
        end

        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_master(service)['nodes'].size).to eq(1)
    end

    it 'scale UP and destroy VM' do
        cli_action("oneflow scale #{@service_id} MASTER 2")

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm recover --delete #{master['deploy_id']}")

        states = wait_state(@service_id, 2)

        # service and roles should be RUNNING
        states.each do |state|
            expect(state).to eq(2)
        end

        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(get_master(service)['nodes'].size).to eq(1)

        wait_state(@service_id, 2)
    end

    ############################################################################
    # SCALE FAILING OPERATIONS
    ############################################################################

    it 'scale same [FAIL]' do
        cli_action("oneflow scale #{@service_id} MASTER 1", false)
    end

    it 'scale in incorrect error [FAIL]' do
        cli_action("oneflow scale #{@service_id} MASTER 2")
        cli_action("oneflow scale #{@service_id} MASTER 2", false)

        service = cli_action_json("oneflow show -j #{@service_id}")
        master  = get_master(service)['nodes'].last

        cli_action("onevm deploy #{master['deploy_id']} #{@host_id}")

        wait_state(@service_id, 2)
    end

    it 'scale lower min_vms [FAIL]' do
        cli_action("oneflow scale #{@service_id} MASTER 0", false)
    end

    ############################################################################
    # DIRECT OPERATIONS
    ############################################################################

    it 'rename service' do
        cli_action("oneflow rename #{@service_id} new_name")

        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(service['DOCUMENT']['NAME']).to eq('new_name')
    end

    it 'chown service' do
        cli_action("oneflow chown #{@service_id} serveradmin")

        service = cli_action_json("oneflow show -j #{@service_id}")
        expect(service['DOCUMENT']['UNAME']).to eq('serveradmin')
    end

    it 'chgrp service' do
        cli_action("oneflow chgrp #{@service_id} users")

        service = cli_action_json("oneflow show -j #{@service_id}")

        # check that only the group changes
        expect(service['DOCUMENT']['GNAME']).to eq('users')
    end

    it 'chmod service' do
        cli_action("oneflow chmod #{@service_id} 700")

        service = cli_action_json("oneflow show -j #{@service_id}")

        # check that only permissions change
        expect(service['DOCUMENT']['PERMISSIONS']['OWNER_U']).to eq('1')
        expect(service['DOCUMENT']['PERMISSIONS']['OWNER_M']).to eq('1')
        expect(service['DOCUMENT']['PERMISSIONS']['OWNER_A']).to eq('1')
        expect(service['DOCUMENT']['PERMISSIONS']['GROUP_U']).to eq('0')
        expect(service['DOCUMENT']['PERMISSIONS']['GROUP_M']).to eq('0')
        expect(service['DOCUMENT']['PERMISSIONS']['GROUP_A']).to eq('0')
        expect(service['DOCUMENT']['PERMISSIONS']['OTHER_U']).to eq('0')
        expect(service['DOCUMENT']['PERMISSIONS']['OTHER_M']).to eq('0')
        expect(service['DOCUMENT']['PERMISSIONS']['OTHER_A']).to eq('0')
    end

    it 'service role action' do
        service   = cli_action_json("oneflow show -j #{@service_id}")
        deploy_id = get_deploy_id(get_slave(service))
        vm        = cli_action_xml("onevm show #{deploy_id} -x")

        expect(vm['/VM/TEMPLATE/SCHED_ACTION']).to be_nil

        cli_action("oneflow action #{@service_id} SLAVE poweroff-hard")

        service   = cli_action_json("oneflow show -j #{@service_id}")
        deploy_id = get_deploy_id(get_slave(service))
        vm        = cli_action_xml("onevm show #{deploy_id} -x")

        expect(vm['/VM/TEMPLATE/SCHED_ACTION']).not_to be_nil
    end

    it 'service action' do
        service    = cli_action_json("oneflow show -j #{@service_id}")
        deploy_ids = []
        deploy_ids << get_deploy_id(get_master(service))
        deploy_ids << get_deploy_id(get_slave(service))
        vms        = []

        deploy_ids.each do |deploy_id|
            vms << cli_action_xml("onevm show #{deploy_id} -x")
        end

        vms.each do |vm|
            expect(vm['/VM/TEMPLATE/SCHED_ACTION']).to be_nil
        end

        cli_action("oneflow service action #{@service_id} poweroff-hard")

        service    = cli_action_json("oneflow show -j #{@service_id}")
        deploy_ids = []
        deploy_ids << get_deploy_id(get_master(service))
        deploy_ids << get_deploy_id(get_slave(service))
        vms        = []

        deploy_ids.each do |deploy_id|
            vms << cli_action_xml("onevm show #{deploy_id} -x")
        end

        vms.each do |vm|
            expect(vm['/VM/TEMPLATE/SCHED_ACTION']).not_to be_nil
        end
    end

    ############################################################################
    # DIRECT FAILING OPERATIONS
    ############################################################################

    it 'rename service [FAIL]' do
        cli_action("oneflow rename #{@service_id}", false)
        cli_action('oneflow rename 123456789 new_name', false)
    end

    it 'chown service [FAIL]' do
        cli_action("oneflow chown #{@service_id}", false)
        cli_action("oneflow chown #{@service_id} fake_user", false)
        cli_action('oneflow chown 123456789 serveradmin', false)
    end

    it 'chgrp service [FAIL]' do
        cli_action("oneflow chgrp #{@service_id}", false)
        cli_action("oneflow chgrp #{@service_id} fake_group", false)
        cli_action('oneflow chgrp 123456789 oneadmin', false)
    end

    it 'chmod service [FAIL]' do
        cli_action("oneflow chmod #{@service_id}", false)
        cli_action("oneflow chmod #{@service_id} xxx", false)
        cli_action('oneflow chmod 123456789 700', false)
    end

    it 'service role action [FAIL]' do
        cli_action("oneflow action #{@service_id}", false)
        cli_action("oneflow action #{@service_id} MASTER", false)
        cli_action("oneflow action #{@service_id} MASTER fake_action", false)
        cli_action('oneflow action 123456789 MASTER poweroff', false)
    end

    it 'service action [FAIL]' do
        cli_action("oneflow service action #{@service_id}", false)
        cli_action("oneflow service action #{@service_id} fake_action", false)
        cli_action('oneflow service action 123456789 poweroff', false)
    end
end
