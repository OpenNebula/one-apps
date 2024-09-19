#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Permissions test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        # Create 2 users (A, B) in the 'users' group, and one (C) in a new group
        @uidA = cli_create_user("userA", "passa")
        @uidB = cli_create_user("userB", "passb")
        @uidC = cli_create_user("userC", "passc")

        @gid = cli_create("onegroup create new_group")

        cli_action("oneuser chgrp userC new_group")

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update default", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end
    end

    before(:each) do
        as_user("userA") do
            @img_id = cli_create("oneimage create -d 1 --name test --path "\
                            "/etc/passwd --size 200")
            wait_loop() do
                xml = cli_action_xml("oneimage show -x #{@img_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
            end
        end
    end

    after(:each) do
      if @img_id != -1
        cli_action("oneimage delete #{@img_id}")

        wait_loop do
            cmd = cli_action("oneimage show #{@img_id}", nil)
            !cmd.success?
        end
      end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    # Owner user tests
    #---------------------------------------------------------------------------
    it "Owner user should check USE right is set" do
        cli_action("oneimage chmod #{@img_id} 400")

        as_user("userA") do
            expect(cli_action("oneimage list").stdout).to match(/test/)
        end
    end

    it "Owner user should check USE right is unset" do
        cli_action("oneimage chmod #{@img_id} 000")

        as_user("userA") do
            expect(cli_action("oneimage list").stdout).to match(/test/)
        end
    end

    it "Owner user should check MANAGE right is set" do
        cli_action("oneimage chmod #{@img_id} 200")

        as_user("userA") do
            cli_action("oneimage delete #{@img_id}")

            wait_loop do
                cmd = cli_action("oneimage show #{@img_id}", nil)
                !cmd.success?
            end

            @img_id = -1
        end
    end

    it "Owner user should check MANAGE right is unset" do
        cli_action("oneimage chmod #{@img_id} 000")

        as_user("userA") do
            cli_action("oneimage delete #{@img_id}", false)
        end
    end

    it "Owner user should check ADMIN right is set" do
        cli_action("oneimage chmod #{@img_id} 100")

        as_user("userA") do
            cli_action("oneimage chmod #{@img_id} 770")
        end
    end

    it "Owner user should check ADMIN right is unset" do
        cli_action("oneimage chmod #{@img_id} 000")

        as_user("userA") do
            cli_action("oneimage chmod #{@img_id} 770", false)
        end
    end

    #---------------------------------------------------------------------------
    # Group user tests
    #---------------------------------------------------------------------------
    it "Group user should check USE right is set" do
        cli_action("oneimage chmod #{@img_id} 040")

        as_user("userB") do
            expect(cli_action("oneimage list").stdout).to match(/test/)
        end
    end

    it "Group user should check USE right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userB") do
            expect(cli_action("oneimage list").stdout).to_not match(/test/)
        end
    end

    it "Group user should check MANAGE right is set" do
        cli_action("oneimage chmod #{@img_id} 020")

        as_user("userB") do
            cli_action("oneimage delete #{@img_id}")

            wait_loop do
                cmd = cli_action("oneimage show #{@img_id}", nil)
                !cmd.success?
            end

            @img_id = -1
        end
    end

    it "Group user should check MANAGE right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userB") do
            cli_action("oneimage delete #{@img_id}", false)
        end
    end

    it "Group user should check ADMIN right is set" do
        cli_action("oneimage chmod #{@img_id} 010")

        as_user("userB") do
            cli_action("oneimage chmod #{@img_id} 770")
        end
    end

    it "Group user should check ADMIN right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userB") do
            cli_action("oneimage chmod #{@img_id} 770", false)
        end
    end

    #---------------------------------------------------------------------------
    # User not in group tests
    #---------------------------------------------------------------------------
    it "User not in group should check USE right is set" do
        cli_action("oneimage chmod #{@img_id} 004")

        as_user("userC") do
            expect(cli_action("oneimage list").stdout).to match(/test/)
        end
    end

    it "User not in group should check USE right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userC") do
            expect(cli_action("oneimage list").stdout).to_not match(/test/)
        end
    end

    it "User not in group should check MANAGE right is set" do
        cli_action("oneimage chmod #{@img_id} 002")

        as_user("userC") do
            cli_action("oneimage delete #{@img_id}")

            wait_loop do
                cmd = cli_action("oneimage show #{@img_id}", nil)
                !cmd.success?
            end

            @img_id = -1
        end
    end

    it "User not in group should check MANAGE right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userC") do
            cli_action("oneimage delete #{@img_id}", false)
        end
    end

    it "User not in group should check ADMIN right is set" do
        cli_action("oneimage chmod #{@img_id} 001")

        as_user("userC") do
            cli_action("oneimage chmod #{@img_id} 770")
        end
    end

    it "User not in group should check ADMIN right is unset" do
        cli_action("oneimage chmod #{@img_id} 600")

        as_user("userC") do
            cli_action("oneimage chmod #{@img_id} 770", false)
        end
    end
end

