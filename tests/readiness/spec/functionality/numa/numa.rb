
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

require 'tempfile'

describe 'VirtualMachine NUMA and virtual topologies test' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    # prepend_before(:all) do
    #    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    # end

    before(:all) do
        cli_update('onedatastore update system', 'TM_MAD=dummy', false)
        cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy\n",
                   false)
        wait_loop do
            xml = cli_action_xml('onedatastore show -x default')
            xml['FREE_MB'].to_i > 0
        end
    end

    after(:each) do
        system('onevm recover --delete test_vm')
    end

    it 'should not create a pinned VM with NODE_AFFINITY' do
        template = <<-EOF
          NAME = test_vm
          MEMORY = 128
          CPU = 1

          TOPOLOGY = [ PIN_POLICY = thread, NODE_AFFINITY = 2 ]
        EOF

        cli_create('onevm create', template, false)
    end

    it 'should not create a VM with wrong vCPU to NUMA_NODE relationship' do
        template = <<-EOF
          NAME = test_vm
          MEMORY = 128
          CPU = 1

          TOPOLOGY = [ PIN_POLICY = thread, SOCKETS = 2 ]
        EOF

        cli_create('onevm create', template, false)
    end

    it 'should not create a VM with wrong MEMORY to NUMA_NODE relationship' do
        template2 = <<-EOF
          NAME = test_vm
          MEMORY = 129
          CPU  = 2
          VCPU = 2

          TOPOLOGY = [ PIN_POLICY = core, SOCKETS = 2 ]
        EOF

        cli_create('onevm create', template2, false)
    end

    it 'should not create a VM with vCPU not multiple of total cores' do
        template3 = <<-EOF
          NAME = test_vm
          MEMORY = 128
          CPU  = 2
          VCPU = 2

          TOPOLOGY = [ PIN_POLICY = core, SOCKETS = "2", CORES = "4"]
        EOF

        cli_create('onevm create', template3, false)
    end

    it 'should not create a VM with threads not power of 2' do
        template4 = <<-EOF
          NAME = test_vm
          MEMORY = 128
          CPU  = 9
          VCPU = 9

          TOPOLOGY = [ PIN_POLICY = shared, SOCKETS = "1", CORES = "3"]
        EOF

        cli_create('onevm create', template4, false)
    end

    it 'should not create a VM with not matching VCPU and topology' do
        template5 = <<-EOF
          NAME = test_vm
          MEMORY = 128
          CPU  = 16
          VCPU = 16

          TOPOLOGY = [ SOCKETS = "2", CORES = "4", THREADS ="4" ]
        EOF

        cli_create('onevm create', template5, false)
    end

    it 'should not generate vtopol with a inconsistent asymmetric specs' do
        template = <<-EOF
            NAME=test_vm
            MEMORY=2048
            CPU=4
            VCPU=4

            NUMA_NODE = [ MEMORY = 1024 , TOTAL_CPUS = 2 ]
            NUMA_NODE = [ MEMORY = 2048 , TOTAL_CPUS = 2 ]

            TOPOLOGY = [ PIN_POLICY = "thread" ]
        EOF

        template1 = <<-EOF
            NAME=test_vm
            MEMORY=2048
            CPU=4
            VCPU=4

            TOPOLOGY = [ PIN_POLICY = "core" ]

            NUMA_NODE = [ MEMORY = 1024 , TOTAL_CPUS = 2 ]
            NUMA_NODE = [ MEMORY = 1024 , TOTAL_CPUS = 1 ]
        EOF

        cli_create('onevm create', template, false)
        cli_create('onevm create', template1, false)
    end

    it 'should generate vtopol with a symmetric NUMA_NODES' do
        template = <<-EOF
          NAME=test_vm
          MEMORY=2048
          CPU=1
          VCPU=4

          TOPOLOGY = [ PIN_POLICY = thread, SOCKETS = 2 ]
        EOF

        cli_create('onevm create', template)

        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 2
        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024 
        expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024 
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 2
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 2

        system('onevm recover --delete test_vm')

        template = <<-EOF
          NAME=test_vm
          MEMORY=2048
          CPU=1
          VCPU=4

          TOPOLOGY = [ SOCKETS = 1 , PIN_POLICY = thread]
        EOF

        cli_create('onevm create', template)

        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1
        expect(nodes[0]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4
    end

    it 'should generate vtopol setting threads from cores & sockets' do
        template = <<-EOF
          NAME=test_vm
          MEMORY=2048
          CPU=8
          VCPU=8

          TOPOLOGY = [ PIN_POLICY = thread, SOCKETS = 1 , CORES=2]
        EOF

        cli_create('onevm create', template)

        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1
        expect(nodes[0]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8
        expect(vm_xml['TEMPLATE/TOPOLOGY/THREADS'].to_i).to eql 4
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 8
    end

    it 'should update CPU based on VCPU for a pinned VM' do
        template = <<-EOF
          NAME=test_vm
          MEMORY=2048
          CPU=1
          VCPU=8

          TOPOLOGY = [ PIN_POLICY = thread]
        EOF

        cli_create('onevm create', template)

        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 1

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 2048
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 8

        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 8
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 8
    end

    it 'should generate an asymmetric topology' do
        template = <<-EOF
            NAME=test_vm
            MEMORY=2048
            CPU=1
            VCPU=8

            TOPOLOGY = [ PIN_POLICY = thread ]

            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 512 ]
            NUMA_NODE = [ TOTAL_CPUS = 4 , MEMORY = 1024 ]
            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 512 ]
        EOF

        cli_create('onevm create', template)

        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 3
        expect(nodes[0]['MEMORY'].to_i).to eql 512 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 2
        expect(nodes[1]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 4
        expect(nodes[2]['MEMORY'].to_i).to eql 512 * 1024
        expect(nodes[2]['TOTAL_CPUS'].to_i).to eql 2
        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 8
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 8
        expect(vm_xml['TEMPLATE/TOPOLOGY/SOCKETS'].to_i).to eql 3
    end

    it 'should generate an asymmetric topology with a node without CPU' do
        template = <<-EOF
            NAME=test_vm
            MEMORY=6144
            CPU=1
            VCPU=8

            TOPOLOGY = [ PIN_POLICY = core ]

            NUMA_NODE = [ TOTAL_CPUS = 4 , MEMORY = 1024 ]
            NUMA_NODE = [ TOTAL_CPUS = 0 , MEMORY = 2048 ]
            NUMA_NODE = [ TOTAL_CPUS = 4 , MEMORY = 1024 ]
            NUMA_NODE = [ TOTAL_CPUS = 0 , MEMORY = 2048 ]
        EOF

        cli_create('onevm create', template, false)

        #
        # Disabled as not supported by libvirt
        #
=begin
        cli_create('onevm create', template)
        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 4

        expect(nodes[0]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4

        expect(nodes[1]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 0

        expect(nodes[2]['MEMORY'].to_i).to eql 1024 * 1024
        expect(nodes[2]['TOTAL_CPUS'].to_i).to eql 4

        expect(nodes[3]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[3]['TOTAL_CPUS'].to_i).to eql 0

        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 8
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 8

        expect(vm_xml['TEMPLATE/TOPOLOGY/SOCKETS'].to_i).to eql 4
=end
    end

    it 'should generate an asymmetric topology with a node without memory' do
        template = <<-EOF
            NAME=test_vm
            MEMORY=4096
            CPU=1
            VCPU=8

            TOPOLOGY = [ PIN_POLICY = shared ]

            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 0 ]
            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 2048 ]
            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 0 ]
            NUMA_NODE = [ TOTAL_CPUS = 2 , MEMORY = 2048 ]
        EOF

        cli_create('onevm create', template, false)

        #
        # Disabled as not supported by quemu
        #
=begin
        vm_xml = cli_action_xml('onevm show test_vm -x')

        nodes = vm_xml.retrieve_xmlelements('TEMPLATE/NUMA_NODE')

        expect(nodes.size).to eql 4

        expect(nodes[0]['MEMORY'].to_i).to eql 0
        expect(nodes[0]['TOTAL_CPUS'].to_i).to eql 4

        expect(nodes[1]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[1]['TOTAL_CPUS'].to_i).to eql 0

        expect(nodes[2]['MEMORY'].to_i).to eql 0
        expect(nodes[2]['TOTAL_CPUS'].to_i).to eql 4

        expect(nodes[3]['MEMORY'].to_i).to eql 2048 * 1024
        expect(nodes[3]['TOTAL_CPUS'].to_i).to eql 0

        expect(vm_xml['TEMPLATE/CPU'].to_i).to eql 1
        expect(vm_xml['TEMPLATE/VCPU'].to_i).to eql 8

        expect(vm_xml['TEMPLATE/TOPOLOGY/SOCKETS'].to_i).to eql 4
=end
    end
end
