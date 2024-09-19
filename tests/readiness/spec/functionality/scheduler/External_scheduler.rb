
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'External Scheduler tests' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults_external.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula initialization:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @host_ids = []
        @vms = []
        3.times do |i|
            @host_ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
        end

        @host_ids.each do |i|
            host = Host.new(i)
            host.monitored?
        end

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        # Spawn external scheduler process
        Dir.chdir("./spec/functionality/scheduler") do
            @child_id = Process.spawn('./external_scheduler_server.rb',
                                      [:out, :err]=>'external_scheduler.log')
        end
    end

    after(:all) do
        # Cleanup VMs and Hosts
        @vms.each {|vm| vm.terminate_hard }
        @host_ids.each {|hid| cli_action("onehost delete #{hid}") }

        # Terminate external scheduler
        Process.kill('SIGKILL', @child_id)
    end

    def create_vm
        template = <<-EOF
            CPU  = 0.1
            MEMORY = 128
        EOF

        vmid = cli_create('onevm create', template)

        VM.new(vmid)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should deploy VMs based on external scheduler' do
        # Create 6 VMs
        6.times { @vms << create_vm }

        # Wait all VMs deployed, check their host id
        @vms.each do |vm|
            vm.running?

            xml = vm.xml

            expect(xml['HISTORY_RECORDS/HISTORY/HID'].to_i).to eq(vm.id % 3)
        end
    end

end

