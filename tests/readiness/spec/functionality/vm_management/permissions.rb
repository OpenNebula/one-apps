
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Permissions test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        # Create 2 users (A, B) in the 'users' group, and one (C) in a new group
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")
        cli_create_user("userC", "passwordC")

        cli_create("onegroup create new_group")
        cli_action("oneuser chgrp userC new_group")
    end

    before(:each) do
        @object_name = "test"
        as_user("userA") do
            @vm_id = cli_create("onevm create --name #{@object_name} " <<
                                "--memory 1 --cpu 1")
        end

        @vm = VM.new(@vm_id)
    end

    after(:each) do
        @vm.terminate_hard
    end

    ############################################################################
    # Owner user tests
    ############################################################################

    it "Owner user should check USE right is set" do
        # Set Owner_U
        cli_action("onevm chmod #{@vm_id} 400")

        as_user("userA") do
            cli_action("onevm show #{@vm_id}")
            expect(cli_action("onevm list").stdout).to match(/#{@object_name}/)
        end
    end

    it "Owner user should check USE right is unset" do
        # Set Owner_U
        cli_action("onevm chmod #{@vm_id} 000")

        # Owned objects are always returned, regardless of the USE right
        as_user("userA") do
            cli_action("onevm show #{@vm_id}", false)
            expect(cli_action("onevm list").stdout).to match(/#{@object_name}/)
        end
    end

    it "Owner user should check MANAGE right is set" do
        # Set Owner_M
        cli_action("onevm chmod #{@vm_id} 200")

        as_user("userA") do
            cli_action("onevm terminate #{@vm_id}")
        end
    end

    it "Owner user should check MANAGE right is unset" do
        # Unset Owner_M
        cli_action("onevm chmod #{@vm_id} 000")

        as_user("userA") do
            cli_action("onevm terminate #{@vm_id}", false)
        end
    end

    it "Owner user should check ADMIN right is set" do
        # Set Owner_A
        cli_action("onevm chmod #{@vm_id} 100")

        as_user("userA") do
            cli_action("onevm chmod #{@vm_id} 770")
        end
    end

    it "Owner user should check ADMIN right is unset" do
        # Unset Owner_A
        cli_action("onevm chmod #{@vm_id} 000")

        as_user("userA") do
            cli_action("onevm chmod #{@vm_id} 770", false)
        end
    end

    ############################################################################
    # Group user tests
    ############################################################################

    it "Group user should check USE right is set" do
        # Set Group_U
        cli_action("onevm chmod #{@vm_id} 040")

        as_user("userB") do
            cli_action("onevm show #{@vm_id}")
            expect(cli_action("onevm list all").stdout).to match(/#{@object_name}/)
        end
    end

    it "Group user should check USE right is unset" do
        # Set Group_U
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userB") do
            cli_action("onevm show #{@vm_id}", false)
            expect(cli_action("onevm list all").stdout).not_to match(/#{@object_name}/)
        end
    end

    it "Group user should check MANAGE right is set" do
        # Set Group_M
        cli_action("onevm chmod #{@vm_id} 020")

        as_user("userB") do
            cli_action("onevm terminate #{@vm_id}")
        end
    end

    it "Group user should check MANAGE right is unset" do
        # Unset Group_M
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userB") do
            cli_action("onevm terminate #{@vm_id}", false)
        end
    end

    it "Group user should check ADMIN right is set" do
        # Set Group_A
        cli_action("onevm chmod #{@vm_id} 010")

        as_user("userB") do
            cli_action("onevm chmod #{@vm_id} 770")
        end
    end

    it "Group user should check ADMIN right is unset" do
        # Unset Group_A
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userB") do
            cli_action("onevm chmod #{@vm_id} 770", false)
        end
    end

    ############################################################################
    # User not in group tests
    ############################################################################

    it "User not in group should check USE right is set" do
        # Set Other_U
        cli_action("onevm chmod #{@vm_id} 004")

        as_user("userC") do
            cli_action("onevm show #{@vm_id}")
            expect(cli_action("onevm list all").stdout).to match(/#{@object_name}/)
        end
    end

    it "User not in group should check USE right is unset" do
        # Set Other_U
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userC") do
            cli_action("onevm show #{@vm_id}", false)
            expect(cli_action("onevm list all").stdout).not_to match(/#{@object_name}/)
        end
    end

    it "User not in group should check MANAGE right is set" do
        # Set Other_M
        cli_action("onevm chmod #{@vm_id} 002")

        as_user("userC") do
            cli_action("onevm terminate #{@vm_id}")
        end
    end

    it "User not in group should check MANAGE right is unset" do
        # Unset Other_M
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userC") do
            cli_action("onevm terminate #{@vm_id}", false)
        end
    end

    it "User not in group should check ADMIN right is set" do
        # Set Other_A
        cli_action("onevm chmod #{@vm_id} 001")

        as_user("userC") do
            cli_action("onevm chmod #{@vm_id} 770")
        end
    end

    it "User not in group should check ADMIN right is unset" do
        # Unset Other_A
        cli_action("onevm chmod #{@vm_id} 600")

        as_user("userC") do
            cli_action("onevm chmod #{@vm_id} 770", false)
        end
    end
end
