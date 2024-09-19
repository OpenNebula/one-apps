require 'init_functionality'
require 'flow_helper'
require 'VN'

require 'tempfile'

RSpec.describe 'OneFlow networks' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        %w[vnet_create vnet_delete].each do |vnet|
            FileUtils.cp(
                "/var/lib/one/remotes/vnm/dummy/#{vnet}",
                "/var/lib/one/remotes/vnm/dummy/#{vnet}_bck"
            )

            FileUtils.cp(
                File.join(File.dirname(__FILE__), 'dummy.sh'),
                "/var/lib/one/remotes/vnm/dummy/#{vnet}"
            )
        end

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

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

        @template_id = cli_create("oneflow-template create #{template_file.path}")

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
    end

    it 'instantiate service with normal network' do
        tempfile = Tempfile.new('flow-net')

        # create extra template
        tempfile << "{\"networks_values\":[{\"Public\":{\"id\":\"0\"}}]}"
        tempfile.close

        service_id = cli_create("oneflow-template instantiate #{@template_id} #{tempfile.path}")
        service    = cli_action_json("oneflow show -j #{service_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1)

        service = cli_action_json("oneflow show -j #{service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(service_id, 2)

        # check that VNET has one lease
        vnet = cli_action_xml("onevnet show -x #{@vnet}")
        expect(vnet['/VNET/USED_LEASES']).to eq('1')
        expect(vnet['/VNET/AR_POOL/AR/LEASES/LEASE/IP']).to eq('1.1.1.1')

        # check that master VM has the lease
        master = get_deploy_id(get_master(service))
        master = cli_action_xml("onevm show -x #{master}")
        expect(master['/VM/TEMPLATE/NIC/IP']).to eq('1.1.1.1')

        # undeploy the service
        cli_action("oneflow delete #{service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        # check that VNET has zero leases
        vnet = cli_action_xml("onevnet show -x #{@vnet}")
        expect(vnet['/VNET/USED_LEASES']).to eq('0')
        expect(vnet['/VNET/AR_POOL/AR/LEASES/LEASE/IP']).to eq(nil)
    end

    it 'instantiate service with network from reservetation' do
        tempfile = Tempfile.new('flow-net')

        # create extra template
        tempfile << "{\"networks_values\":[{\"Public\":"
        tempfile << "{\"reserve_from\": \"0\", \"extra\":\"NAME=RESERVATION\\nSIZE=5\"}}]}"
        tempfile.close

        service_id = cli_create("oneflow-template instantiate #{@template_id} #{tempfile.path}")
        service    = cli_action_json("oneflow show -j #{service_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1)

        service = cli_action_json("oneflow show -j #{service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(service_id, 2)

        # check that VNET has five lease
        vnet = cli_action_xml("onevnet show -x #{@vnet}")
        expect(vnet['/VNET/USED_LEASES']).to eq('5')

        # check that reservation exists
        vnet = cli_action_xml('onevnet show -x RESERVATION')
        expect(vnet['/VNET/USED_LEASES']).to eq('1')
        expect(vnet['/VNET/AR_POOL/AR/LEASES/LEASE/IP']).to eq('1.1.1.1')

        # check that master VM has the lease
        master = get_deploy_id(get_master(service))
        master = cli_action_xml("onevm show -x #{master}")
        expect(master['/VM/TEMPLATE/NIC/IP']).to eq('1.1.1.1')

        # undeploy the service
        cli_action("oneflow delete #{service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        # wait until the network is deleted
        wait_loop do
            !system("onevnet show RESERVATION > /dev/null")
        end

        # check that RESERVATION has been deleted
        cli_action('onevnet show RESERVATION', false)

        # check that VNET has zero leases
        vnet = cli_action_xml("onevnet show -x #{@vnet}")
        expect(vnet['/VNET/USED_LEASES']).to eq('0')
        expect(vnet['/VNET/AR_POOL/AR/LEASES/LEASE/IP']).to eq(nil)
    end

    it 'delete network' do
        cli_action("onevnet delete #{@vnet}")
    end

    it 'instantiate service with network from VNETemplate' do
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

        vnet_template = cli_create("onevntemplate create #{template_file.path}")

        tempfile = Tempfile.new('flow-net')

        # create extra template
        tempfile << "{\"networks_values\":[{\"Public\":"
        tempfile << "{\"template_id\": \"0\", \"extra\":\"AR=[ IP=1.1.1.1,SIZE=10,TYPE=IP4]\"}}]}"
        tempfile.close

        service_id = cli_create("oneflow-template instantiate #{@template_id} #{tempfile.path}")
        service    = cli_action_json("oneflow show -j #{service_id}")

        # wait until the service is DEPLOYING
        wait_state(service_id, 1)

        service = cli_action_json("oneflow show -j #{service_id}")

        # deploy all roles
        get_roles(service).each do |role|
            cli_action("onevm deploy #{get_deploy_id(role)} #{@host_id}")
        end

        # wait until the service is RUNNING
        wait_state(service_id, 2)

        # check that VNET exists and has one lease
        vnet = cli_action_xml('onevnet show -x 2')
        expect(vnet['/VNET/USED_LEASES']).to eq('1')
        expect(vnet['/VNET/AR_POOL/AR/LEASES/LEASE/IP']).to eq('1.1.1.1')

        # check that master VM has the lease
        master = get_deploy_id(get_master(service))
        master = cli_action_xml("onevm show -x #{master}")
        expect(master['/VM/TEMPLATE/NIC/IP']).to eq('1.1.1.1')

        # undeploy the service
        cli_action("oneflow delete #{service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end

        # check that PUBLIC has been deleted
        vnet = VN.new(2)
        vnet.deleted?
    end

    ############################################################################
    # Failing actions
    ############################################################################

    it 'instantiate/delete VNETemplate [FAIL]' do
        %w[vnet_create vnet_delete].each do |vnet|
            FileUtils.cp(
                File.join(File.dirname(__FILE__), 'fail.sh'),
                "/var/lib/one/remotes/vnm/dummy/#{vnet}"
            )
        end

        tempfile = Tempfile.new('flow-net')

        # create extra template
        tempfile << "{\"networks_values\":[{\"Public\":"
        tempfile << "{\"template_id\": \"0\", \"extra\":\"AR=[ IP=1.1.1.1,SIZE=10,TYPE=IP4]\"}}]}"
        tempfile.close

        service_id = cli_create("oneflow-template instantiate #{@template_id} #{tempfile.path}")
        service    = cli_action_json("oneflow show -j #{service_id}")

        # wait until the service is FAILED_DEPLOYING_NETS
        wait_state(service_id, 13)

        cli_action('onevnet recover 3 --success')
        cli_action("oneflow recover #{service_id}")

        # wait until the service is FAILED_DEPLOYING
        wait_state(service_id, 7)

        # undeploy the service
        cli_action("oneflow recover --delete #{service_id}")

        # wait until the service is DONE
        wait_loop do
            !system("oneflow show #{service_id} > /dev/null")
        end
    end

    after(:all) do
        stop_flow

        %w[vnet_create vnet_delete].each do |vnet|
            FileUtils.cp(
                "/var/lib/one/remotes/vnm/dummy/#{vnet}_bck",
                "/var/lib/one/remotes/vnm/dummy/#{vnet}"
            )
        end
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
