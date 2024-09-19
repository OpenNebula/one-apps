
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine lock operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_create_user("userA", "passwordA")
        cli_create("onehost create host01 --im dummy --vm dummy")

        @id = cli_create("onevm create --name testvm_lock --cpu 1 --memory 1 ")
        template = <<-EOF
            NAME   = generic_source
            TYPE   = OS
            SOURCE = /this/is/a/path
            SIZE   = 128
            FORMAT = raw
        EOF

        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        @id_img = cli_create("oneimage create -d default", template)
        cli_action("oneimage chown #{@id_img} userA")
        cli_action("onevm chown #{@id} userA")

        @vm = VM.new(@id)
        cli_action("onevm deploy #{@id} host01")
    end

    after(:all) do
        cli_action("onevm terminate --hard #{@id}")
    end

    it "should lock a VirtualMachine on USE level and Image with a lock on USE level" do
        as_user("userA") do
            cli_action("oneimage lock #{@id_img} --use")
            cli_action("onevm lock #{@id} --use")
            cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
            cli_action("oneimage unlock #{@id_img}")
            cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
        end
        cli_action("oneimage lock #{@id_img} --use")
        cli_action("onevm lock #{@id} --use")
        cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
        cli_action("oneimage unlock #{@id_img}")
        cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
        cli_action("onevm unlock #{@id}")
    end

    it "should lock a VirtualMachine on MANAGE level" do
        as_user("userA") do
            cli_action("onevm lock #{@id} --manage")
            cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
            cli_action("onevm reboot #{@id}", false)
        end
        cli_action("onevm lock #{@id} --manage")
        cli_action("onevm disk-attach #{@id} -i #{@id_img}", false)
        cli_action("onevm reboot #{@id}", false)
        cli_action("onevm unlock #{@id}")
    end

    it "should lock a VirtualMachine on ADMIN level" do
        as_user("userA") do
            cli_action("onevm lock #{@id} --admin")
            cli_action("onevm reboot #{@id}")
        end
    end

    it "should unlock a VirtualMachine" do
        cli_action("onevm unlock #{@id}")
    end

    it "should not override admin lock by user" do
        cli_action("onevm lock #{@id}")

        as_user('userA') do
            cli_action("onevm unlock #{@id}", false)
            cli_action("onevm lock #{@id}", false)
            cli_action("onevm unlock #{@id}", false)
        end
    end

    it "should override/unlock user lock by admin" do
        cli_action("onevm unlock #{@id}")

        as_user('userA') do
            cli_action("onevm lock #{@id}")
        end

        # Admin unlocks user lock
        cli_action("onevm unlock #{@id}")
        cli_action("onevm reboot #{@id}")

        as_user('userA') do
            cli_action("onevm lock #{@id}")
        end

        # Admin overrides user lock
        cli_action("onevm lock #{@id} --admin")
        cli_action("onevm reboot #{@id}")
    end
end

