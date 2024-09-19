#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non owned VirtualMachine operations test" do
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
        cli_create_user("userA", "passwordA")

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
        EOF

        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        as_user "userA" do
            @tid = cli_create("onetemplate create", @template_1)
            @vmid = cli_create("onetemplate instantiate #{@tid}")
            cli_action("onevm chmod #{@vmid} 640")
            @sg_id = cli_create("onesecgroup create", "NAME = test_sg")

            @img_id = cli_create("oneimage create -d 1", <<-EOT)
                NAME = "test_img"
                TYPE = "DATABLOCK"
                FSTYPE = "ext3"
                SIZE = 256
            EOT
        end

        cli_create("onehost create host01 --im dummy --vm dummy")

        @net = VN.create(<<-EOT)
            NAME = "test_vnet"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
            AR = [ TYPE = IP4, IP = 192.168.0.0, SIZE = 32 ]
        EOT
        @net.ready?

        @template_update = <<-EOF
            CPU=2
        EOF

        @template_use_operations = <<-EOF
            VM_USE_OPERATIONS = "rename, update, terminate"
        EOF
    end

    before(:each) do
        cli_create_user("userB", "passwordB")
    end

    after(:each) do
        cli_action("oneuser delete userB")
    end

    # Test the action fails and the reason is 'Not authorized to perform ...'
    def test_fail(action)
        rc = cli_action(action, false)
        expect(rc.stderr).to match(/Not authorized to perform/)
    end

    def test_fail_update(action, template, append)
        rc = cli_update(action, template, append, false)
        expect(rc.stderr).to match(/Not authorized to perform/)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should perform an ADMIN operation with USE rigths" do
        # See the oned.extra.yaml for VM_*_OPERATIONS settings
        as_user "userB" do
            cli_action("onevm recover --delete #{@vmid}")
        end
    end

    it "should not perform an ADMIN operation with USE rigths" do
        as_user "userA" do
            @vmid = cli_create("onetemplate instantiate #{@tid}")
            cli_action("onevm chmod #{@vmid} 640")
        end

        as_user "userB" do
            cli_action("onevm rename #{@vmid} new_name", false)
            cli_update("onevm update #{@vmid}", @template_update, false, false)
            cli_action("onevm terminate #{@vmid}", false)
        end
    end

    it "should not perform operation altered to ADMIN in oned.conf" do
        as_user 'userA' do
            @vmid = cli_create("onetemplate instantiate #{@tid}")
            cli_action("onevm chmod #{@vmid} 640")

            test_fail("onevm undeploy #{@vmid}")
            test_fail("onevm hold #{@vmid}")
            test_fail("onevm release #{@vmid}")
            test_fail("onevm stop #{@vmid}")
            test_fail("onevm suspend #{@vmid}")
            test_fail("onevm resume #{@vmid}")
            test_fail("onevm reboot #{@vmid}")
            test_fail("onevm poweroff #{@vmid}")
            test_fail("onevm terminate #{@vmid}")
            test_fail("onevm rename #{@vmid} new_name")
            test_fail("onevm resize #{@vmid} --memory 2")
            test_fail("onevm poweroff #{@vmid} --schedule now")
            test_fail_update("onevm update #{@vmid}", "A=a", true)
            test_fail_update("onevm updateconf #{@vmid}", "A=a", true)
        end

        cli_action("onevm deploy #{@vmid} host01")

        vm = VM.new(@vmid)
        vm.running?

        cli_action("onevm disk-attach #{@vmid} -i #{@img_id}")

        vm.running?

        cli_action("onevm nic-attach #{@vmid} --network 0")

        vm.running?

        as_user 'userA' do
            test_fail("onevm disk-attach #{@vmid} -i #{@img_id}")
            test_fail("onevm disk-detach #{@vmid} 0")
            test_fail("onevm disk-resize #{@vmid} 0 512")
            test_fail("onevm disk-saveas #{@vmid} 0 img_name")

            test_fail("onevm disk-snapshot-create #{@vmid} 0 snapshot1")
            test_fail("onevm disk-snapshot-rename #{@vmid} 0 0 snapshot_renamed")
            test_fail("onevm disk-snapshot-revert #{@vmid} 0 0")
            test_fail("onevm disk-snapshot-delete #{@vmid} 0 0")

            test_fail("onevm nic-attach #{@vmid} --network 0")
            test_fail("onevm nic-detach #{@vmid} 0")
            test_fail_update("onevm nic-update #{@vmid} 0", 'NEW_ATTRIBUTE="555"', true)

            test_fail("onevm sg-attach #{@vmid} 0 0")
            test_fail("onevm sg-detach #{@vmid} 0 0")

            test_fail("onevm snapshot-create #{@vmid} snap1")
            test_fail("onevm snapshot-revert #{@vmid} 0")
            test_fail("onevm snapshot-delete #{@vmid} 0")
        end
    end

    it "should not allow user to change his permmissions" do
        as_user "userA" do
            cli_update("oneuser update userA", @template_use_operations, false, false)
        end
    end

    it "should not allow user to change group permissions" do
        as_user "userA" do
            cli_update("onegroup update users", @template_use_operations, false, false)
        end
        # not even as group admin
        cli_action("onegroup addadmin users userA")
        as_user "userA" do
            cli_update("onegroup update users", @template_use_operations, false, false)
        end
    end

    it "should perform an USE operation with user modified rights" do
        cli_update("oneuser update userB", @template_use_operations, false, true)

        as_user "userB" do
            cli_action("onevm rename #{@vmid} new_name")
            cli_update("onevm update #{@vmid}", @template_update, false, true)
            cli_action("onevm terminate #{@vmid}")
            cli_action("onevm recover --delete #{@vmid}")
        end
    end

    it "should perform an USE operation with group modified rights" do
        as_user "userA" do
            @vmid = cli_create("onetemplate instantiate #{@tid}")
            cli_action("onevm chmod #{@vmid} 640")
        end
        cli_update("onegroup update users", @template_use_operations, false, true)

        as_user "userB" do
            cli_action("onevm rename #{@vmid} new_name")
            cli_update("onevm update #{@vmid}", @template_update, false, true)
            cli_action("onevm terminate #{@vmid}")
        end
    end

    it "should not allow nonsense in VM_*_OPERATION" do
        template_wrong = <<-EOF
            VM_USE_OPERATIONS = "non-existiong-operation"
        EOF

        cli_update("oneuser update userA", template_wrong, false, false)
        cli_update("onegroup update users", template_wrong, false, false)
    end
end
