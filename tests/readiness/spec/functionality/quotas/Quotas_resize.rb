#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

TMP_FILENAME = '/tmp/quotas_resize_template.txt'

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Check quotas when resizing a VM' do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        system(`sed -ie 's/VM_RESTRICTED_ATTR= "TOPOLOGY\\/PIN_POLICY"/#VM_RESTRICTED_ATTR= "TOPOLOGY\\/PIN_POLICY"/' /etc/one/oned.conf`)

        @one_test.stop_one
        @one_test.start_one

        cli_create_user('uA', 'abc')
        cli_create_user('uB', 'abc')
        cli_create_user('uC', 'abc')

        gA_id = cli_create('onegroup create gA')
        gC_id = cli_create('onegroup create gC')

        cli_action('oneuser chgrp uA gA')
        cli_action('oneuser chgrp uB gA')
        cli_action('oneuser chgrp uC gC')

        cli_create('onehost create host0 --im dummy --vm dummy')
    end

    before(:each) do
        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 512
      CPU = 1
      VCPU = 1
            EOT

            @id = cli_create('onevm create', tmpl)
            cli_action("onevm chmod #{@id} 660")
        end
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])

        cli_action("onevm recover --delete #{@id}")

        vm = VM.new(@id)
        vm.done?
    end

    #---------------------------------------------------------------------------
    # HELPERS
    #---------------------------------------------------------------------------

    def check_initial_quotas
        uA_xml = cli_action_xml('oneuser show -x uA')

        expect(uA_xml['VM_QUOTA/VM/VMS_USED']).to eql('1')
        expect(uA_xml['VM_QUOTA/VM/CPU_USED']).to eql('1')
        expect(uA_xml['VM_QUOTA/VM/MEMORY_USED']).to eql('512')

        uB_xml = cli_action_xml('oneuser show -x uB')

        expect(uB_xml['VM_QUOTA/VM/VMS_USED']).to eql(nil)
        expect(uB_xml['VM_QUOTA/VM/CPU_USED']).to eql(nil)
        expect(uB_xml['VM_QUOTA/VM/MEMORY_USED']).to eql(nil)

        uC_xml = cli_action_xml('oneuser show -x uC')

        expect(uC_xml['VM_QUOTA/VM/VMS_USED']).to eql(nil)
        expect(uC_xml['VM_QUOTA/VM/CPU_USED']).to eql(nil)
        expect(uC_xml['VM_QUOTA/VM/MEMORY_USED']).to eql(nil)

        gA_xml = cli_action_xml('onegroup show -x gA')

        expect(gA_xml['VM_QUOTA/VM/VMS_USED']).to eql('1')
        expect(gA_xml['VM_QUOTA/VM/CPU_USED']).to eql('1')
        expect(gA_xml['VM_QUOTA/VM/MEMORY_USED']).to eql('512')
    end

    def check_resize_quotas
        uA_xml = cli_action_xml('oneuser show -x uA')

        expect(uA_xml['VM_QUOTA/VM/VMS_USED']).to eql('1')
        expect(uA_xml['VM_QUOTA/VM/CPU_USED']).to eql('1.50')
        expect(uA_xml['VM_QUOTA/VM/MEMORY_USED']).to eql('1024')

        uB_xml = cli_action_xml('oneuser show -x uB')

        expect(uB_xml['VM_QUOTA/VM/VMS_USED']).to eql(nil)
        expect(uB_xml['VM_QUOTA/VM/CPU_USED']).to eql(nil)
        expect(uB_xml['VM_QUOTA/VM/MEMORY_USED']).to eql(nil)

        uC_xml = cli_action_xml('oneuser show -x uC')

        expect(uC_xml['VM_QUOTA/VM/VMS_USED']).to eql(nil)
        expect(uC_xml['VM_QUOTA/VM/CPU_USED']).to eql(nil)
        expect(uC_xml['VM_QUOTA/VM/MEMORY_USED']).to eql(nil)

        gA_xml = cli_action_xml('onegroup show -x gA')

        expect(gA_xml['VM_QUOTA/VM/VMS_USED']).to eql('1')
        expect(gA_xml['VM_QUOTA/VM/CPU_USED']).to eql('1.50')
        expect(gA_xml['VM_QUOTA/VM/MEMORY_USED']).to eql('1024')
    end

    def wait_vm_state(state, id = @id)
        wait_loop do
            xml = cli_action_xml("onevm show #{id} -x")
            OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == state
        end
    end

    def wait_vm_lcm_state(state, id = @id)
        wait_loop do
            xml = cli_action_xml("onevm show #{id} -x")
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == state
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it 'should check initial quotas' do
        check_initial_quotas
    end

    it 'should resize a VM as oneadmin' do
        vmxml = cli_action_xml("onevm show -x #{@id}")

        expect(vmxml['TEMPLATE/CPU']).to eql('1')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

        cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\"")

        vmxml = cli_action_xml("onevm show -x #{@id}")

        expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')

        check_resize_quotas

        oneadmin_xml = cli_action_xml('oneuser show -x 0')

        expect(oneadmin_xml['VM_QUOTA/VM/VMS_USED']).to eql(nil)
        expect(oneadmin_xml['VM_QUOTA/VM/CPU_USED']).to eql(nil)
        expect(oneadmin_xml['VM_QUOTA/VM/MEMORY_USED']).to eql(nil)
    end

    it 'should fail to resize a VM if it exceeds user limits ' do
        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = 1024,
      CPU     = 3,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('oneuser quota uA', quota_file, false)

        as_user('uA') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action("onevm resize #{@id} --memory 1200 --cpu \"1.5\" --enforce", false)
        end

        check_initial_quotas

        as_user('uA') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\" --enforce")

            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')
        end

        check_resize_quotas
    end

    it "should fail to resize another user's VM if it exceeds owner limits " do
        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = 1024,
      CPU     = 3,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('oneuser quota uA', quota_file, false)

        as_user('uB') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action("onevm resize #{@id} --memory 1200 --cpu \"1.5\" --enforce", false)
        end

        check_initial_quotas

        as_user('uB') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\" --enforce")

            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')
        end

        check_resize_quotas
    end

    it 'should fail to resize a VM if it exceeds group limits ' do
        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = 1024,
      CPU     = 3,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('onegroup quota gA', quota_file, false)

        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('oneuser quota uA', quota_file, false)

        as_user('uA') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action("onevm resize #{@id} --memory 1200 --cpu \"1.5\" --enforce", false)
        end

        check_initial_quotas

        as_user('uA') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\" --enforce")

            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')
        end

        check_resize_quotas

        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('onegroup quota gA', quota_file, false)
    end

    it "should fail to resize another user's VM if it exceeds group limits " do
        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = 1024,
      CPU     = 3,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('onegroup quota gA', quota_file, false)

        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('oneuser quota uA', quota_file, false)

        as_user('uB') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action("onevm resize #{@id} --memory 1200 --cpu \"1.5\" --enforce", false)
        end

        check_initial_quotas

        as_user('uB') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\" --enforce")

            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')
        end

        check_resize_quotas

        quota_file = <<-EOT
    VM = [
      VMS     = -2,
      MEMORY  = -2,
      CPU     = -2,
      SYSTEM_DISK_SIZE = -2
    ]
        EOT

        cli_update('onegroup quota gA', quota_file, false)
    end

    it 'should resize a VM if it is running' do
        cli_action("onevm deploy #{@id} 0")

        vm = VM.new(@id)
        vm.running?

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

        cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\"")

        vm.running?

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')

        check_resize_quotas
    end

    it 'should revert quotas in case of driver resize failure' do
        cli_action("onevm deploy #{@id} 0")

        vm = VM.new(@id)
        vm.running?

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

        File.write('/tmp/opennebula_dummy_actions/resize', 'failure')

        cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\"")

        vm = VM.new(@id)
        vm.running?

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

        check_initial_quotas
    end

    it "should resize another user's VM if it is running" do
        cli_action("onevm deploy #{@id} 0")

        vm = VM.new(@id)
        vm.running?

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

        as_user('uB') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu \"1.5\"")
        end

        vmxml = vm.info

        expect(vmxml['TEMPLATE/CPU']).to eql('1.5')
        expect(vmxml['TEMPLATE/MEMORY']).to eql('1024')

        check_resize_quotas
    end

    it 'should fail to resize a VM if it exceeds host capacity' do
        vm = VM.new(@id)

        cli_action('oneacl create "* HOST/* USE"')

        hxml = cli_action_xml('onehost show -x 0')

        expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('0')

        cli_action("onevm deploy #{@id} 0")
        vm.running?

        as_user('uA') do
            cli_action("onevm poweroff #{@id}")

            vm.stopped?

            hxml = cli_action_xml('onehost show -x 0')

            expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('100')

            cli_action("onevm resize #{@id} --memory 1024 --cpu 10 --enforce", false)
        end

        check_initial_quotas

        as_user('uA') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu 1.5 --enforce")
        end

        check_resize_quotas

        hxml = cli_action_xml('onehost show -x 0')

        expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('150')
    end

    it "should fail to resize another user's VM if it exceeds host capacity" do
        `oneacl create \"* HOST/* USE\"`

        hxml = cli_action_xml('onehost show -x 0')

        expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('0')

        cli_action("onevm deploy #{@id} 0")
        wait_vm_lcm_state('RUNNING')

        as_user('uB') do
            cli_action("onevm poweroff #{@id}")

            wait_vm_state('POWEROFF')

            hxml = cli_action_xml('onehost show -x 0')

            expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('100')

            cli_action("onevm resize #{@id} --memory 1024 --cpu 10 --enforce", false)
        end

        check_initial_quotas

        as_user('uB') do
            cli_action("onevm resize #{@id} --memory 1024 --cpu 1.5 --enforce")
        end

        check_resize_quotas

        hxml = cli_action_xml('onehost show -x 0')

        expect(hxml['HOST_SHARE/CPU_USAGE']).to eql('150')
    end

    it 'should fail to resize a VM if it the new values are wrong using stdin template' do
        cmd = "onevm resize #{@id}"

        template = <<~EOT
            CPU = -4
            MEMORY = 1024
        EOT

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        as_user('uA') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action(stdin_cmd, false)
        end

        check_initial_quotas
    end

    it "should fail to resize another user's VM if it the new values are wrong" do
        `echo "CPU = -4" > #{TMP_FILENAME}`
        `echo "MEMORY = 1024" >> #{TMP_FILENAME}`

        as_user('uB') do
            vmxml = cli_action_xml("onevm show -x #{@id}")

            expect(vmxml['TEMPLATE/CPU']).to eql('1')
            expect(vmxml['TEMPLATE/MEMORY']).to eql('512')

            cli_action("onevm resize #{@id} --file #{TMP_FILENAME}", false)
        end

        check_initial_quotas
    end

    it 'Should check that number of cores is updated with VCPU in a pinned VM' do
        id = 0

        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 512
      CPU = 1
      VCPU = 2
      TOPOLOGY = [ CORES = 2, THREADS = 1, SOCKETS = 1]
            EOT

            id = cli_create('onevm create', tmpl)
            cli_action("onevm chmod #{id} 660")
        end

        vm_xml = cli_action_xml("onevm show #{id} -x")

        expect(vm_xml['TEMPLATE/TOPOLOGY/THREADS'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/TOPOLOGY/CORES'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/TOPOLOGY/SOCKETS'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/MEMORY'].to_i).to eql 512

        as_user('uA') do
            cli_action("onevm resize #{id} --memory 1024 --vcpu 4")
        end

        vm_xml = cli_action_xml("onevm show #{id} -x")

        expect(vm_xml['TEMPLATE/TOPOLOGY/THREADS'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/TOPOLOGY/CORES'].to_i).to eql 4
        expect(vm_xml['TEMPLATE/TOPOLOGY/SOCKETS'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 4
        expect(vm_xml['TEMPLATE/MEMORY'].to_i).to eql 1024

        cli_action("onevm recover --delete #{id}")
    end

    it 'Should check that number of cores is updated with VCPU in a non-pinned VM' do
        id = 0

        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      VCPU = 2
      TOPOLOGY = [PIN_POLICY = core, SOCKETS = 2]
            EOT

            id = cli_create('onevm create', tmpl)
            cli_action("onevm chmod #{id} 660")
        end

        vm_xml = cli_action_xml("onevm show #{id} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 2
        expect(nodes[0]['MEMORY'].to_i).to eql 512 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 1
        expect(nodes[1]['MEMORY'].to_i).to eql 512 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/MEMORY'].to_i).to eql 1024

        as_user('uA') do
            cli_action("onevm resize #{id} --memory 2048 --vcpu 4")
        end

        vm_xml = cli_action_xml("onevm show #{id} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 2
        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 2
        expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 4
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 4
        expect(vm_xml['TEMPLATE/MEMORY'].to_i).to eql 2048

        cli_action("onevm recover --delete #{id}")
    end

    it 'Should not resize a VM when cores/VCPU are not multiple' do
        id = 0

        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 512
      CPU = 1
      VCPU = 4
      TOPOLOGY = [ CORES = 2, THREADS = 2, SOCKETS = 1]
            EOT

            id = cli_create('onevm create', tmpl)
            cli_action("onevm chmod #{id} 660")

            cli_action("onevm resize #{id} --memory 1024 --vcpu 5", false)
        end

        cli_action("onevm recover --delete #{id}")
    end

    it 'Should generate a new homogenous topology for the VM' do
        cli_update('onehost update host0', 'PIN_POLICY = PINNED', true)

        id = 0

        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      VCPU = 2
      TOPOLOGY = [PIN_POLICY = core, SOCKETS = 2]
            EOT

            id = cli_create('onevm create', tmpl)
            cli_action("onevm chmod #{id} 660")
        end

        cli_action("onevm deploy #{id} 0")
        wait_vm_lcm_state('RUNNING', id)

        cli_action("onevm poweroff --hard #{id}")
        wait_vm_state('POWEROFF', id)

        as_user('uA') do
            cli_action("onevm resize #{id} --memory 2048 --vcpu 4")
        end

        vm_xml = cli_action_xml("onevm show #{id} -x")

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 2
        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 2
        expect(nodes[0]['CPUS']).to eql '8,9'
        expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 2
        expect(nodes[1]['CPUS']).to eql '0,1'

        host = cli_action_xml('onehost show host0 -x')

        cores = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE/CORE')

        expect(cores[0]['CPUS']).to eql "0:#{id},16:-1,32:-1,48:-1"
        expect(cores[0]['FREE'].to_i).to eql 0
        expect(cores[1]['CPUS']).to eql "1:#{id},17:-1,33:-1,49:-1"
        expect(cores[1]['FREE'].to_i).to eql 0
        expect(cores[8]['CPUS']).to eql "8:#{id},24:-1,40:-1,56:-1"
        expect(cores[8]['FREE'].to_i).to eql 0
        expect(cores[9]['CPUS']).to eql "9:#{id},25:-1,41:-1,57:-1"
        expect(cores[9]['FREE'].to_i).to eql 0

        nodes = host.retrieve_xmlelements('HOST_SHARE/NUMA_NODES/NODE')

        expect(nodes[0]['MEMORY/USAGE']).to eql '1048576'
        expect(nodes[1]['MEMORY/USAGE']).to eql '1048576'

        expect(host['HOST_SHARE/CPU_USAGE'].to_i).to eql 400
        expect(host['HOST_SHARE/MEM_USAGE'].to_i).to eql 2097152
    end

    it 'Should not resize a VM if there is no enough threads in the host' do
        cli_update('onehost update host0', 'PIN_POLICY = PINNED', true)
        cli_update('onehost update host0', 'RESERVED_CPU=-1600', true)

        id1 = id2 = 0

        as_user('uA') do
            tmpl = <<-EOT
      NAME = test_vm
      MEMORY = 1024
      CPU = 1
      TOPOLOGY = [PIN_POLICY = core, SOCKETS = 2]
            EOT

            id1 = cli_create('onevm create', tmpl+"\nVCPU = 4\n")
            id2 = cli_create('onevm create', tmpl+"\nVCPU = 4\n")
        end

        cli_action("onevm deploy #{id1} 0")
        cli_action("onevm deploy #{id2} 0")
        wait_vm_lcm_state('RUNNING', id1)
        wait_vm_lcm_state('RUNNING', id2)

        cli_action("onevm poweroff --hard #{id1}")
        wait_vm_state('POWEROFF', id1)

        as_user('uA') do
            cli_action("onevm resize #{id1} --memory 2048 --vcpu 10", false)
        end

        cli_action("onevm recover --delete #{id1},#{id2}")
    end

    it 'should run fsck' do
        run_fsck
    end
end
