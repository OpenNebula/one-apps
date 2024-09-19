require 'init_functionality'
require 'flow_helper'

require 'tempfile'

RSpec.describe 'OneFlow General State' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        # Update datastores to dummy
        cli_update('onedatastore update system',
                   'TM_MAD=dummy',
                   false)
        cli_update('onedatastore update default',
                   "TM_MAD=dummy\nDS_MAD=dummy",
                   false)

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        # Create VM template
        template = vm_template

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        cli_action("onetemplate create #{template_file.path}")

        # Create Service template
        template = service_template('none', false)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @template_id = cli_create("oneflow-template create #{template_file.path}")
    end

    before(:each) do
        # Instantiate the service template
        @service_id = cli_create("oneflow-template instantiate #{@template_id}")

        # flow state must be DEPLOYING
        wait_state(@service_id, flow_state['DEPLOYING'])

        @service    = cli_action_json("oneflow show -j #{@service_id}")
    end

    let(:flow_state) {
        {
            'PENDING'            => 0,
            'DEPLOYING'          => 1,
            'RUNNING'            => 2,
            'UNDEPLOYING'        => 3,
            'WARNING'            => 4,
            'DONE'               => 5,
            'FAILED_UNDEPLOYING' => 6,
            'FAILED_DEPLOYING'   => 7,
            'SCALING'            => 8,
            'FAILED_SCALING'     => 9,
            'COOLDOWN'           => 10
        }
    }

    it 'check DEPLOYING and RUNNING states on instantiate service' do
        #
        # Once the service template has been created, the state
        # of the flow must be DEPLOYING upon instantiate:
        #  +------+                     -----------                 ---------
        #  | User +----instantiate---->( DEPLOYING )-------------->( RUNNING )
        #  +------+                     -----------  (after vms     ---------
        #                                             vms deployed)

        # it is not allowed to undeploy a flow service while it is
        # in DEPLOYING state
        cmd = cli_action("oneflow delete #{@service_id}", false)
        expect(cmd.stdout).to eq("Service cannot be undeployed in state: DEPLOYING\n")
        wait_state(@service_id, flow_state['DEPLOYING'])

        # it is not allowed to scale a flow service while it is
        # in DEPLOYING state
        cmd = cli_action("oneflow scale #{@service_id} MASTER 2", false)
        expect(cmd.stdout).to eq("Service cannot be scaled in state: DEPLOYING\n")
        wait_state(@service_id, flow_state['DEPLOYING'])

        # deploy all roles
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(@service_id, flow_state['RUNNING'])

        # undeploy the service
        cli_action("oneflow delete #{@service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    it 'check WARNING state' do
        #
        # Once a OneFlow is RUNNING, the state must transit to WARNING upon
        # VM transition to POWEROFF or UNKNOWN
        #
        #  ---------                   ---------                 ------
        # ( RUNNING )---------------->( WARNING )----delete---->( DONE )
        #  ---------  (after VM in     --------                  ------
        #              state UNKNOWN/   | ^ recover/scale
        #              POWEROFF)        +-+

        # Deploy all roles to reach the RUNNING state
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end
        wait_state(@service_id, flow_state['RUNNING'])

        # Poweroff a VM
        vm_id = get_deploy_id(get_roles(@service)[0])
        cli_action("onevm poweroff #{vm_id}")

        # Wait until the service is WARNING
        wait_state(@service_id, flow_state['WARNING'])

        # Recover from WARNING state is not allowed
        cmd = cli_action("oneflow recover #{@service_id}", false)
        expect(cmd.stdout).to eq("Service cannot be recovered in state: WARNING\n")
        wait_state(@service_id, flow_state['WARNING'])

        # Scale from WARINING state is not allowed
        cmd = cli_action("oneflow scale #{@service_id} MASTER 2", false)
        expect(cmd.stdout).to eq("Service cannot be scaled in state: WARNING\n")
        wait_state(@service_id, flow_state['WARNING'])

        # Undeploy the service (allowed from WARNING state)
        cli_action("oneflow delete #{@service_id}")

        # Wait until the service is DONE
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    it 'check FAILED_DEPLOYING state' do
        #
        # After an error on flow instantiation the state of the flow
        # must be FAILED_DEPLOYING:
        #                              +-+
        #                              |  \scale/recover/delete
        #   -----------                ---->-------------
        #  ( DEPLOYING )------------->( FAILED_DEPLOYING )
        #   ----------- (after deploy  --+---------------
        #                failure)        |
        #                                |recover
        #                              --+------
        #                             ( RUNNING )
        #                              ---------
        #

        # Make first VM deploy sucess, second deploy fails, third fails,
        # and fourth success
        %x( printf "%s\n%s\n%s\n%s\n" "success" "failure" "failure" "success" \
            > /tmp/opennebula_dummy_actions/deploy )

        # Deploy roles
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # State must be FAILED_DEPLOYING after a VM deploy failure
        wait_state(@service_id, flow_state['FAILED_DEPLOYING'])

        # Scale from FAILED_DEPLOYING state is not allowed
        cmd = cli_action("oneflow scale #{@service_id} MASTER 2", false)
        expect(cmd.stdout).to eq("Service cannot be scaled in state: FAILED_DEPLOYING\n")
        wait_state(@service_id, flow_state['FAILED_DEPLOYING'])

        # Undeploy from FAILED_DEPLOYING state is not allowed
        cmd = cli_action("oneflow delete #{@service_id}", false)
        expect(cmd.stdout).to eq("Service cannot be undeployed in state: FAILED_DEPLOYING\n")
        wait_state(@service_id, flow_state['FAILED_DEPLOYING'])

        # Recover from FAILED_DEPLOYING without failed VM recovered keeps
        # FAILED_DEPLOYING state
        cmd = cli_action("oneflow recover #{@service_id}")
        # Wait some time to check if the state changes
        # TODO: Add a separate test for "false" recover actions - sleep(15)
        wait_state(@service_id, flow_state['FAILED_DEPLOYING'])

        # State must be RUNNING after recovering the VM successfully
        cmd = cli_action("oneflow recover #{@service_id}")
        wait_state(@service_id, flow_state['RUNNING'])

        # Undeploy the service (allowed from WARNING state)
        cli_action("oneflow delete #{@service_id}")

        # Wait until the service is DONE
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end

        %x( rm -f /tmp/opennebula_dummy_actions/deploy )
    end

    it 'check UNDEPLOYING state' do
        #
        # The state of the flow transit from RUNNING to UNDEPLOYING after
        # delete (undeploy) execution:
        #
        #
        #   ---------             -------------              ------
        #  ( RUNNING )--delete-->( UNDEPLOYING )----------->( DONE )
        #   ---------             -------------              ------
        #

        # Cause timeouts on VMs shutdown
        %x( > /tmp/opennebula_dummy_actions/shutdown )

        # Deploy roles
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        wait_state(@service_id, flow_state['RUNNING'])

        # Undeploy flow
        cli_action("oneflow delete #{@service_id}")

        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end

        %x( rm -f /tmp/opennebula_dummy_actions/shutdown )
    end

    it 'check SCALING state' do
        #
        # The state of the flow transit from RUNNING to SCALING upon a 'scale'
        # execution:
        #                         +-+
        #                         |  \scale/delete/recover
        #   ---------            ----->---          ----------          ------
        #  ( RUNNING )--scale-->( SCALING )------->( COOLDOwN )------->( DONE )
        #   ---------            ---------          ----------          ------
        #

        # Deploy roles
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end
        # Flow state must be RUNNING
        wait_state(@service_id, flow_state['RUNNING'])

        # Scale from RUNING state must transit to SCALING state
        cli_action("oneflow scale #{@service_id} MASTER 2")
        wait_state(@service_id, flow_state['SCALING'])

        # Scale again from SCALING state is not allowed
        cmd = cli_action("oneflow scale #{@service_id} MASTER 3", false)
        expect(cmd.stdout).to eq("Service cannot be scaled in state: SCALING\n")
        wait_state(@service_id, flow_state['SCALING'])

        # Delete from SCALING state is not allowed
        cmd = cli_action("oneflow delete #{@service_id}", false)
        expect(cmd.stdout).to eq("Service cannot be undeployed in state: SCALING\n")
        wait_state(@service_id, flow_state['SCALING'])

        # Recover from SCALING state does nothing (not even error message?)
        cli_action("oneflow recover #{@service_id}")
        wait_state(@service_id, flow_state['SCALING'])

        # Deploy the new VM
        @service = cli_action_json("oneflow show -j #{@service_id}")
        vm_id = get_roles(@service)[0]["nodes"][1]["deploy_id"]
        cli_action("onevm deploy #{vm_id}, #{@host_id}")
        # COOLDOWN state after new VM deployed
        wait_state(@service_id, flow_state['COOLDOWN'])

        # Delete flow
        wait_state(@service_id, flow_state['RUNNING'])
        cli_action("oneflow delete #{@service_id}")
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end
    end

    it 'check FAILED_SCALING state' do
        #
        # The state of the flow transit from RUNNING to SCALING upon a 'scale'
        # execution:
        #                          +-+
        #                          |  \scale/delete
        #   ---------             ----->----------
        #  ( SCALING )---------->( FAILED_SCALING )
        #   --------- (VM deploy  ------+---------
        #              failure)         |             ----------      ---------
        #                               +--recover-->( COOLDOWN ) -> ( RUNNING )
        #                                             ----------      ---------

        # Deploy roles
        get_roles(@service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end
        # Flow state must be RUNNING
        wait_state(@service_id, flow_state['RUNNING'])


        # Scale from RUNING state must transit to SCALING state
        cli_action("oneflow scale #{@service_id} MASTER 2")
        wait_state(@service_id, flow_state['SCALING'])

        # Cause failure on next deploy
        %x( printf "%s\n" "failure" > /tmp/opennebula_dummy_actions/deploy )

        # Deploy the scaled VM
        @service = cli_action_json("oneflow show -j #{@service_id}")
        vm_id = get_roles(@service)[0]["nodes"][1]["deploy_id"]
        cli_action("onevm deploy #{vm_id}, #{@host_id}")
        # After VM deploy failure state must transit from SCALING to FAILED_SCALING
        wait_state(@service_id, flow_state['FAILED_SCALING'])

        # Scale from FAILED_SCALING state is not allowed
        cmd = cli_action("oneflow scale #{@service_id} MASTER 3", false)
        expect(cmd.stdout).to eq("Service cannot be scaled in state: FAILED_SCALING\n")
        wait_state(@service_id, flow_state['FAILED_SCALING'])

        # Delete from FAILED_SCALING state is not allowed
        cmd = cli_action("oneflow delete #{@service_id}", false)
        expect(cmd.stdout).to eq("Service cannot be undeployed in state: FAILED_SCALING\n")
        wait_state(@service_id, flow_state['FAILED_SCALING'])

        # Cause failure on next deploy
        %x( printf "%s\n" "success" > /tmp/opennebula_dummy_actions/deploy )

        # State must be RUNNING after recovering the VM successfully
        cmd = cli_action("oneflow recover #{@service_id}")
        wait_state(@service_id, flow_state['RUNNING'])

        # Delete flow
        cli_action("oneflow delete #{@service_id}")
        wait_loop do
            !system("oneflow show #{@service_id} > /dev/null")
        end

        %x( rm -f /tmp/opennebula_dummy_actions/deploy )
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
