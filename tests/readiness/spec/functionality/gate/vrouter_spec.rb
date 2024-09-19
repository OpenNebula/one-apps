require 'init_functionality'
require 'gate_helper'
require 'json'
require 'json-schema'
require 'uri'
require 'pry'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'OneGate Virtual Router' do
    include GateHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        @info = {}
        server_config = start_gate

        vr_template=<<-EOF
         NAME   = "vr_template"
         CONTEXT = [
            NETWORK = "yes",
            TOKEN = "YES" ]
          CPU = "1.0"
          GRAPHICS = [
            LISTEN = "0.0.0.0",
            TYPE = "vnc" ]
          MEMORY = "128"
          NIC_DEFAULT = [
            MODEL = "virtio" ]
          VCPU = "1"
          VROUTER = "yes"
        EOF

        net_template=<<-EOF
            NAME   = "net"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        # Update datastores to dummy
        cli_update('onedatastore update system',
                   'TM_MAD=dummy',
                   false)
        cli_update('onedatastore update default',
                   "TM_MAD=dummy\nDS_MAD=dummy",
                   false)

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        # Create vrouter
        @info[:vr_tmpl_id] = cli_create('onetemplate create', vr_template)
        @info[:net] = VN.create(net_template)
        @info[:net_id] = @info[:net].id

        @info[:net].ready?

        cli_action("onevnet hold #{@info[:net_id]} 192.168.0.1") # make sure held IPs are managed
        @info[:vr_id] = cli_create('onevrouter create', vr_template)

        # Attach nic to vrouter
        cli_action("onevrouter nic-attach #{@info[:vr_id]} -n #{@info[:net_id]}")

        # Instantiate vrouter
        cli_action("onevrouter instantiate #{@info[:vr_id]} #{@info[:vr_tmpl_id]}")
        @info[:vm_id] =
            Integer(cli_action_xml("onevrouter show -x #{@info[:vr_id]}").retrieve_xmlelements('//VMS/ID')[0].text)

        wait_loop do
            xml = cli_action_xml("onevm show #{@info[:vm_id]} -x")
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'RUNNING'
        end

        # get user token
        user_xml = cli_action_xml('oneuser show -x')
        token_passwd = user_xml['TEMPLATE/TOKEN_PASSWORD']

        # Retrieve server config information
        @info[:host]  = server_config[:host]
        @info[:port]  = server_config[:port]
        @info[:url]   = "http://localhost:#{server_config[:port]}"

        # Generate token for vrouter
        @info[:token] = gen_token(cli_action_xml("onevm show -x #{@info[:vm_id]}"),
                                  token_passwd)

        # Create HTTP client
        @client = GateHelper::Client.new(@info)

        # Load JSON schemas
        @schemas = {}
        @schemas[:vrouter] = JSON.parse(File.read('spec/functionality/gate/schemas/vrouter.json'))
        @schemas[:vnet]    = JSON.parse(File.read('spec/functionality/gate/schemas/vnet.json'))
    end

    after(:all) do
        stop_gate
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it 'validate VROUTER schema whit one nic' do
        json_obj = JSON.parse(@client.get('/vrouter').body)
        expect(JSON::Validator.validate!(@schemas[:vrouter], json_obj)).to eq(true)
    end

    it 'validate VROUTER schema whit multiple nic' do
        # Attach nic to vrouter
        cli_action("onevrouter nic-attach #{@info[:vr_id]} -n #{@info[:net_id]}", nil)

        json_obj = JSON.parse(@client.get('/vrouter').body)
        expect(JSON::Validator.validate!(@schemas[:vrouter], json_obj)).to eq(true)
    end

    it 'validate VROUTER schema whit floating IP' do
        # Attach nic to vrouter
        cli_action("onevrouter nic-attach #{@info[:vr_id]} -n #{@info[:net_id]} --float")

        json_obj = JSON.parse(@client.get('/vrouter').body)
        expect(JSON::Validator.validate!(@schemas[:vrouter], json_obj)).to eq(true)
    end

    it 'validate VNET schema (VNET attached to VROUTER)' do
        extra = URI.encode_www_form({ 'extended' => true })
        json_obj = JSON.parse(@client.get("/vnet/#{@info[:net_id]}", extra).body)

        expect(JSON::Validator.validate!(@schemas[:vnet], json_obj)).to eq(true)
    end

    it 'validate VNET schema (VNET child of VNET attached to VROUTER)' do
        # create a reservation from the VNET attached to VROUTER
        reserve_id = cli_create("onevnet reserve #{@info[:net_id]} -n child -s 1")

        net = VN.new(reserve_id)
        net.ready?

        # Retrieve VNET information
        extra = URI.encode_www_form({ 'extended' => true })
        json_obj = JSON.parse(@client.get("/vnet/#{reserve_id}", extra).body)

        # clean reservation
        cli_action("onevnet delete #{reserve_id}")

        # Ensure reservation info can be retrieved
        expect(JSON::Validator.validate!(@schemas[:vnet], json_obj)).to eq(true)
    end

    it 'validate VNET schema (VNET parent of VNET attached to VROUTER)' do
        # Create parent vnet
        net_template=<<-EOF
            NAME   = "parent-net"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        parent_id = cli_create('onevnet create', net_template)

        net_parent = VN.new(parent_id)
        net_parent.ready?

        # Create reserve (child) vnet
        child_id = cli_create("onevnet reserve #{parent_id} -n child -s 1")

        # NOTE: Consider wait net child_id ready. (Not neeeded version 6.6)

        # Attach child to VROUTER
        cli_action("onevrouter nic-attach #{@info[:vr_id]} -n #{child_id}")

        # Retrieve VNET information
        extra = URI.encode_www_form({ 'extended' => true })
        json_obj = JSON.parse(@client.get("/vnet/#{parent_id}", extra).body)

        # clean
        vr_xml = cli_action_xml("onevrouter show -x #{@info[:vr_id]}")
        xpath = '//NIC[not(//NIC_ID > NIC_ID)]/NIC_ID'
        last_nic = Integer(vr_xml.retrieve_xmlelements(xpath)[0].text)
        cli_action("onevrouter nic-detach #{@info[:vr_id]} #{last_nic}")

        wait_loop do
            vr_xml = cli_action_xml("onevrouter show -x #{@info[:vr_id]}")
            xpath = '//NIC[not(//NIC_ID > NIC_ID)]/NIC_ID'

            Integer(vr_xml.retrieve_xmlelements(xpath)[0].text) < last_nic
        end

        net_child = VN.new(child_id)
        net_child.delete
        net_child.deleted?

        net_parent.delete
        net_parent.deleted?

        # Ensure VROUTER can retrieve parent information
        expect(JSON::Validator.validate!(@schemas[:vnet], json_obj)).to eq(true)
    end

    it 'validate VNET schema (VNET sibling of VNET attached to VROUTER)' do
        # Create parent vnet
        net_template=<<-EOF
            NAME   = "parent-net"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        net_parent = VN.create(net_template)
        net_parent.ready?

        # Create reserve (childs) vnet
        sibling1 = cli_create("onevnet reserve #{net_parent.id} -n sibling1 -s 1")
        sibling2 = cli_create("onevnet reserve #{net_parent.id} -n sibling2 -s 1")

        # NOTE: Consider wait siblings ready. (Not neeeded version 6.6)

        # Attach sibling1 to VROUTER
        cli_action("onevrouter nic-attach #{@info[:vr_id]} -n #{sibling1}")

        # Retrieve VNET sibling2 information
        extra = URI.encode_www_form({ 'extended' => true })
        json_obj = JSON.parse(@client.get("/vnet/#{sibling2}", extra).body)

        # clean
        vr_xml = cli_action_xml("onevrouter show -x #{@info[:vr_id]}")
        xpath = '//NIC[not(//NIC_ID > NIC_ID)]/NIC_ID'
        last_nic = Integer(vr_xml.retrieve_xmlelements(xpath)[0].text)
        cli_action("onevrouter nic-detach #{@info[:vr_id]} #{last_nic}")

        wait_loop do
            vr_xml = cli_action_xml("onevrouter show -x #{@info[:vr_id]}")
            xpath = '//NIC[not(//NIC_ID > NIC_ID)]/NIC_ID'

            Integer(vr_xml.retrieve_xmlelements(xpath)[0].text) < last_nic
        end

        net_sib1 = VN.new(sibling1)
        net_sib2 = VN.new(sibling2)
        net_sib1.delete
        net_sib2.delete
        net_sib1.deleted?
        net_sib2.deleted?
        net_parent.delete

        # Ensure VROUTER can retrieve parent information
        expect(JSON::Validator.validate!(@schemas[:vnet], json_obj)).to eq(true)
    end

    it 'validate VNET access error when VNET is not related with VROUTER' do
        # Create independent vnet
        net_template=<<-EOF
            NAME   = "independent-net"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        net = VN.create(net_template)
        net.ready?

        # Try to retrieve VNET information
        extra = URI.encode_www_form({ 'extended' => true })
        resp  = @client.get("/vnet/#{net.id}", extra).body

        # Clean
        net.delete

        # Check expected error
        err_msg = "Virtual Network #{net.id} cannot be retrieved"\
                    " from Virtual router #{@info[:vr_id]}."
        expect(resp).to eq(err_msg)
    end

    it 'validate VM access to VROUTER VMs' do
        # Instantiate another VROUTER VM
        cli_action("onevrouter instantiate #{@info[:vr_id]} #{@info[:vr_tmpl_id]}")

        # Retrieve VMs IDs
        vms = cli_action_xml("onevrouter show -x #{@info[:vr_id]}").retrieve_xmlelements('//VMS/ID').map do |vm|
            Integer(vm.text)
        end

        # Check the VROUTER can access every VM
        vms.each do |vm|
            # Parse will fail parsing the error message
            JSON.parse(@client.get("/vms/#{vm}").body)
        end
    end

    it 'validate VM access error when VM is not part of the VROUTER' do
        # Crate an independent VM
        vm_id = cli_create('onevm create --name no-access --cpu 1 --memory 128')

        # Check expected error msg
        resp = @client.get("/vms/#{vm_id}").body

        err_msg = "Virtual Router #{@info[:vr_id]} does "\
        "not contain VM #{vm_id}."
        expect(resp).to eq(err_msg)
    end
end
