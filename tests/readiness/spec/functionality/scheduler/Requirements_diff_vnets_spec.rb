
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling requirements tests with DIFFERENT_VNETS flag activated" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_vnets.yaml')
    end

    def build_vnet_template(name, size, extra_attributes)
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        ids = []
        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
            ids << cli_create("onehost create host#{i}.one.org --im dummy --vm dummy")
        }

        ids.each { |i|
            host = Host.new(i)
            host.monitored?
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @net_id_1 = cli_create("onevnet create", build_vnet_template("test_vnet", 3, "INBOUND_AVG_BW=1500"))
        @net_id_2 = cli_create("onevnet create", build_vnet_template("test_vnet_2", 1, "INBOUND_AVG_BW=1200"))
        @net_id_3 = cli_create("onevnet create", build_vnet_template("test_vnet_3", 4, "INBOUND_AVG_BW=1600"))
    end

    after(:all) do
        5.times { |i|
            cli_action("onehost delete host#{i}")
            cli_action("onehost delete host#{i}.one.org")
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create a vm that can not be picked with only 3 vnets" do

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_MODE = "auto"
            ]
        EOF

        vmid = cli_create("onevm create", template)
        vm   = VM.new(vmid)

        wait_loop(:success => false, :timeout => 30) {
            vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
        }

        expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to match(/Cannot dispatch VM/)

        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_MODE = "auto"
            ]
            NIC = [
                NETWORK_MODE = "auto"
            ]
        EOF

        vmid2 = cli_create("onevm create", template)
        vm2   = VM.new(vmid2)

        vm2.running?

        vm.terminate_hard

        vm2.terminate_hard
    end
end

