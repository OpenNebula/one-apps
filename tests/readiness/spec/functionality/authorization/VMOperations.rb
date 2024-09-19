
require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VM operations test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_noOther.yaml')
    end

    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        cli_create("onehost create host01 --im dummy --vm dummy")

        cli_create_user("userA", "passwordA")

        @net = VN.create(<<-EOT)
            NAME = "test_vnet"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
        EOT
        @net.ready?

        cli_action("onevnet addar test_vnet --ip 10.0.0.1 --size 255")
        cli_action("onevnet chown test_vnet userA")

        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        as_user("userA") do
            @sg_id = cli_create("onesecgroup create", "NAME = test_sg")

            @img_id = cli_create("oneimage create -d 1", <<-EOT)
                NAME = "test_img"
                TYPE = "DATABLOCK"
                FSTYPE = "ext3"
                SIZE = 256
            EOT
        end
    end

    before(:each) do
        as_user("userA") do
            @vm_id = cli_create("onevm create --name test_vm " <<
                                "--memory 1 --cpu 1")
        end

        @vm = VM.new(@vm_id)
    end

    after(:each) do
        @vm.terminate_hard
    end

    it "User with MANAGE permissions executes MANAGE VM actions" do
        cli_action("onevm deploy #{@vm_id} host01")

        @vm.running?

        # Set Owner_UM
        cli_action("onevm chmod #{@vm_id} 600")

        as_user('userA') do
            cli_action("onevm snapshot-create #{@vm_id} snap1")
            @vm.running?
            cli_action("onevm snapshot-revert #{@vm_id} 0")
            @vm.running?
            cli_action("onevm snapshot-delete #{@vm_id} 0")
            @vm.running?

            cli_action("onevm poweroff #{@vm_id}")

            @vm.stopped?

            # Disk operations
            cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
            cli_action("onevm disk-resize #{@vm_id} 0 512")
            cli_action("onevm disk-snapshot-create #{@vm_id} 0 snapshot1")
            cli_action("onevm disk-snapshot-create #{@vm_id} 0 snapshot2")
            cli_action("onevm disk-snapshot-rename #{@vm_id} 0 0 snapshot_renamed")
            cli_action("onevm disk-snapshot-revert #{@vm_id} 0 0")
            cli_action("onevm disk-snapshot-delete #{@vm_id} 0 1")
            cli_action("onevm disk-detach #{@vm_id} 0")

            # Network operations
            cli_action("onevm nic-attach #{@vm_id} --network 0")
            cli_action("onevm sg-attach #{@vm_id} 0 #{@sg_id}")
            cli_action("onevm sg-detach #{@vm_id} 0 #{@sg_id}")
            # onevm nic-update: only for version 6.6+
            cli_action("onevm nic-detach #{@vm_id} 0")

            # Charts
            cli_action("onevm create-chart #{@vm_id}")
            cli_update("onevm update-chart #{@vm_id} 0", "A=a", false)
            cli_action("onevm delete-chart #{@vm_id} 0")

            # Others
            cli_action("onevm rename #{@vm_id} new_name")
            cli_action("onevm resize #{@vm_id} --memory 2")

            cli_update("onevm update #{@vm_id}", "A=a", true)
            cli_update("onevm updateconf #{@vm_id}", "A=a", true)

            cli_action("onevm lock #{@vm_id}")
            cli_action("onevm unlock #{@vm_id}")

            cli_action("onevm resume #{@vm_id}")
            @vm.running?
            cli_action("onevm reboot #{@vm_id}")
            @vm.running?
            cli_action("onevm suspend #{@vm_id}")
            @vm.state?('SUSPENDED')
            cli_action("onevm resume #{@vm_id}")
            @vm.running?
            cli_action("onevm undeploy #{@vm_id}")
            @vm.undeployed?
        end
    end

    # Test the action fails and the reason is not authorized to MANAGE
    def test_fail(action)
        rc = cli_action(action, false)
        expect(rc.stderr).to match(/Not authorized to perform MANAGE VM/)
    end

    def test_fail_update(action, template, append)
        rc = cli_update(action, template, append, false)
        expect(rc.stderr).to match(/Not authorized to perform MANAGE VM/)
    end

    it "User with USE permissions fails to execute MANAGE VM actions" do
        cli_action("onevm deploy #{@vm_id} host01")

        @vm.running?

        # As admin setup VM resources for update and delete operations
        cli_action("onevm snapshot-create #{@vm_id} snap1")
        @vm.running?
        cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
        @vm.running?
        cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
        @vm.running?
        cli_action("onevm disk-snapshot-create #{@vm_id} 0 snapshot1")
        @vm.running?
        cli_action("onevm nic-attach #{@vm_id} --network 0")
        @vm.running?
        cli_action("onevm create-chart #{@vm_id}")

        # Set Owner_M
        cli_action("onevm chmod #{@vm_id} 400")

        as_user("userA") do
            test_fail("onevm snapshot-create #{@vm_id} snap2")
            test_fail("onevm snapshot-revert #{@vm_id} 0")
            test_fail("onevm snapshot-delete #{@vm_id} 0")

            test_fail("onevm poweroff #{@vm_id}")
            test_fail("onevm reboot #{@vm_id}")
            test_fail("onevm suspend #{@vm_id}")
            test_fail("onevm undeploy #{@vm_id}")
            test_fail("onevm terminate #{@vm_id}")
        end

        cli_action("onevm poweroff #{@vm_id}")
        @vm.stopped?

        as_user("userA") do
            # Disk operations
            test_fail("onevm disk-attach #{@vm_id} -i #{@img_id}")
            test_fail("onevm disk-resize #{@vm_id} 1 512")
            test_fail("onevm disk-snapshot-create #{@vm_id} 0 snapshot2")
            test_fail("onevm disk-snapshot-create #{@vm_id} 0 snapshot3")
            test_fail("onevm disk-snapshot-rename #{@vm_id} 0 0 snapshot_renamed")
            test_fail("onevm disk-snapshot-revert #{@vm_id} 0 0")
            test_fail("onevm disk-snapshot-delete #{@vm_id} 0 1")
            test_fail("onevm disk-detach #{@vm_id} 0")

            # Network operations
            test_fail("onevm nic-attach #{@vm_id} --network 0")
            test_fail("onevm sg-attach #{@vm_id} 0 #{@sg_id}")
        end

        cli_action("onevm sg-attach #{@vm_id} 0 #{@sg_id}")

        as_user("userA") do
            test_fail("onevm sg-detach #{@vm_id} 0 #{@sg_id}")
            # onevm nic-update: only for version 6.6+
            test_fail("onevm nic-detach #{@vm_id} 0")

            # Charts
            test_fail("onevm create-chart #{@vm_id}")
            test_fail_update("onevm update-chart #{@vm_id} 2", "A=a", false)
            test_fail("onevm delete-chart #{@vm_id} 2")

            # Others
            test_fail("onevm rename #{@vm_id} new_name")
            test_fail("onevm resize #{@vm_id} --memory 2")

            test_fail_update("onevm update #{@vm_id}", "A=a", true)
            test_fail_update("onevm updateconf #{@vm_id}", "A=a", true)

            test_fail("onevm lock #{@vm_id}")
            test_fail("onevm unlock #{@vm_id}")

            test_fail("onevm resume #{@vm_id}")
        end
    end
end
