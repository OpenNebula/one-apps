#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'VirtualRouter operations test' do
    before(:all) do
        net_public=<<-EOF
            NAME   = "vr_public"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        net_private=<<-EOF
            NAME   = "vr_private"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
        EOF

        vr_template=<<-EOF
         NAME   = "vr_template"
         CONTEXT = [
            NETWORK = "yes" ]
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

        @test = {}

        @test[:net_pub]  = cli_create('onevnet create', net_public)
        @test[:net_priv] = cli_create('onevnet create', net_private)
        @test[:vm_tmpl] = cli_create('onetemplate create', vr_template)
    end

    after(:all) do
        cli_action("onetemplate delete #{@test[:vm_tmpl]}")
        cli_action("onevnet delete #{@test[:net_pub]}")
        cli_action("onevnet delete #{@test[:net_priv]}")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should not allow a to create a VR with auto mode' do
        vr_template = <<-EOF
            NAME = "vr"
            NIC  = [ NETWORK_MODE = auto ]
            NIC  = [ NETWORK = vr_public ]
        EOF

        cli_create('onevrouter create', vr_template, false)

    end

    it 'should not allocate additional IPs when FLOATING_ONLY' do
        vr_template = <<-EOF
            NAME = "float_vr"
            NIC  = [ NETWORK  = vr_public, FLOATING_IP = YES, FLOATING_ONLY = YES ]
            NIC  = [ NETWORK  = vr_private ]
        EOF

        vr = cli_create('onevrouter create', vr_template)

        cli_action("onevrouter instantiate -m 3 #{vr} #{@test[:vm_tmpl]}")

        xml = cli_action_xml("onevrouter show -x #{vr}")

        vms = xml.retrieve_elements('VMS/ID')

        ips  = [ "10.0.0.1", "10.0.0.2", "10.0.0.3" ]
        vm_i = 0

        vms.each do |id|
            puts "VM_ID : #{id}"

            vm_xml = cli_action_xml("onevm show -x #{id}")

            expect(vm_xml["/VM/TEMPLATE/NIC[NIC_ID = 0]/IP"]).to eq nil
            expect(vm_xml["/VM/TEMPLATE/NIC[NIC_ID = 0]/VROUTER_IP"]).to eq "192.168.0.1"
            expect(vm_xml["/VM/TEMPLATE/NIC[NIC_ID = 0]/VROUTER_MAC"]).to_not eq nil
            expect(vm_xml["/VM/TEMPLATE/NIC[NIC_ID = 1]/IP"]).to eq ips[vm_i]

            vm_i = vm_i + 1
        end

        cli_action("onevrouter delete #{vr}")

        vms.each do |id|
            VM.new(id).done?
        end

    end
=begin
    it 'should attach nic to the vrouter with floating ip' do
        cli_action("onevrouter nic-attach #{@vr_id} -n #{@net_id} --float")

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '1'

        vr_xml = cli_action_xml("onevrouter show #{@vr_id} -x")
        nic_id = vr_xml['TEMPLATE/NIC[last()]/NIC_ID']

        cli_action("onevrouter nic-detach #{@vr_id} #{nic_id}")

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '0'
    end

    it 'should attach nic to the vrouter' do
        cli_action("onevrouter nic-attach #{@vr_id} -n #{@net_id}")

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '0'

        vr_xml = cli_action_xml("onevrouter show #{@vr_id} -x")
        nic_id = vr_xml['TEMPLATE/NIC[last()]/NIC_ID']

        cli_action("onevrouter nic-detach #{@vr_id} #{nic_id}")
    end

    it 'should instantiate new vm' do
        cli_action("onevrouter nic-attach #{@vr_id} -n #{@net_id}")

        cli_action("onevrouter instantiate #{@vr_id} #{@vr_tmpl_id}")
        vm_xml = cli_action_xml('onevm list -x')
        vm_id = vm_xml['VM[last()]/ID']

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '1'

        vm_xml = cli_action_xml("onevm show #{vm_id} -x")
        expect(vm_xml['//TEMPLATE/VROUTER_KEEPALIVED_ID']).to eq('1')

        cli_action("onevm recover --delete #{vm_id}")

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '0'
    end

    it 'should attach nic to the instantiated vrouter using stdin templates' do
        host_id = cli_create('onehost create localhost -i dummy -v dummy')

        cmd = 'onevrouter create'
        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{@vr_template}
            EOF
        BASH
        vri_id = cli_create(stdin_cmd)

        # TODO: Make sure instantiate with file path is tested
        cmd = "onevrouter instantiate #{vri_id} #{@vr_tmpl_id}"
        template = <<~EOT
            NAME = STDIN_APPENDED_TEMPLATE_VR
        EOT
        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH
        cli_action(stdin_cmd)

        vm_xml = cli_action_xml('onevm list -x')
        vri_id = vm_xml['VM[last()]/ID']

        cli_action("onevm deploy #{vri_id} #{host_id}")

        VM.new(vri_id).running?

        # TODO: Make sure nic-attach with file path is tested
        cmd = "onevrouter nic-attach #{vri_id}"
        template = <<~EOT
            NIC = [ NETWORK_ID = #{@net_id} ]
        EOT
        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH
        cli_action(stdin_cmd)

        vnet = cli_action_xml("onevnet show -x #{@net_id}")
        expect(vnet['AR_POOL/AR [ IP = "192.168.0.1" ]/USED_LEASES']).to eq '1'
    end

    it 'should fail attaching an alias' do
        vm_xml = cli_action_xml('onevm list -x')
        vm_id = vm_xml['VM[last()]/ID']

        cli_action("onevm nic-attach #{vm_id} -n #{@net_id} --alias NIC0", false)
    end

    it 'should detach nic from the instantiated vrouter' do
        vm_xml = cli_action_xml('onevm list -x')
        vm_id = vm_xml['VM[last()]/ID']

        vr_xml = cli_action_xml("onevm show #{vm_id} -x")
        nic_id = vr_xml['TEMPLATE/NIC[last()]/NIC_ID']

        cli_action("onevrouter nic-detach #{vm_id} #{nic_id}")
    end
=end
end
