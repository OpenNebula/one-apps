
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Secondary groups scheduling tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        hid  = cli_create("onehost create host00 --im dummy --vm dummy")
		host = Host.new(hid)

		host.monitored?

        gid = cli_create("onegroup create atope")
        uid = cli_create_user("vicentin", "5.0")
        cli_action("oneuser chgrp vicentin atope")

        acl_pool = OpenNebula::AclPool.new(@client)
		expect(acl_pool.info).to be_nil

		acl_str = "@#{gid} HOST/* MANAGE #0"

        hrule= acl_pool["/ACL_POOL/ACL[STRING=\"#{acl_str}\"]/ID"]
        cli_action("oneacl delete #{hrule}")

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should not allocate a VM, no permissions granted to primary group" do
        vmid = -1

        as_user("vicentin") {

            vmid = cli_create("onevm create --hold --name testvm "\
                              "--memory 1 --cpu 1")
            vm   = VM.new(vmid)

            expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

            cli_action("onevm release #{vmid}")

            wait_loop(:success => false, :timeout => 30) {
                vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
            }
        }

        cli_action("onevm terminate --hard #{vmid}")
    end

    it "should allocate a VM considering secondary groups " do
        vmid = -1
        vm   = nil

        as_user("vicentin") {

            vmid = cli_create("onevm create --hold --name testvm "\
                              "--memory 1 --cpu 1")
            vm   = VM.new(vmid)

            expect(vm.info['USER_TEMPLATE/SCHED_MESSAGE']).to be_nil

            cli_action("onevm release #{vmid}")

            wait_loop(:success => false, :timeout => 30) {
                vm.info['USER_TEMPLATE/SCHED_MESSAGE'].nil?
            }
        }

        cli_action("oneuser addgroup vicentin users")

        vm.running?

        vm.terminate_hard
    end
end
