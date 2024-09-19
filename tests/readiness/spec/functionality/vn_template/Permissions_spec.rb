#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VN Permissions test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @uid = cli_create_user("new_user", "abc")

        # Create 2 users (A, B) in the 'users' group, and one (C) in a new group
        @uidA = cli_create_user("userA", "passa")
        @uidB = cli_create_user("userB", "passb")
        @uidC = cli_create_user("userC", "passc")
        @uidD = cli_create_user("userD", "passd")

        @gid = cli_create("onegroup create new_group")

        cli_action("oneuser chgrp userC new_group")
        cli_action("oneuser chgrp userD new_group")
        cli_action("oneuser addgroup userD users")

        #Grants create permissions for userA over VNTEMPLATEs
        cli_action("oneacl create '##{@uidA} VNTEMPLATE/* CREATE'")
    end

    before(:each) do
        @template_id = -1

        as_user("userA") do
            template = <<-EOF
                NAME   = test
                VN_MAD = bridge
                ATT1   = "VAL1"
                ATT2   = "VAL2"
            EOF

            @template_id = cli_create("onevntemplate create", template)
        end
    end

    after(:each) do
        cli_action("onevntemplate delete #{@template_id}") if @template_id != -1
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "Owner user should check USE right is set" do
        cli_action("onevntemplate chmod #{@template_id} 400")

        as_user("userA") do
            expect(cli_action("onevntemplate list").stdout).to match(/test/)
        end
    end

    it "Owner user should check USE right is unset" do
        cli_action("onevntemplate chmod #{@template_id} 000")

        # Owned objects are always returned, regardless of the USE right
        as_user("userA") do
            expect(cli_action("onevntemplate list").stdout).to match(/test/)
        end
    end

    it "Owner user should check MANAGE right is set" do
        cli_action("onevntemplate chmod #{@template_id} 200")

        as_user("userA") do
            cli_action("onevntemplate delete #{@template_id}")
        end

        @template_id = -1
    end

    it "Owner user should check MANAGE right is unset" do
        cli_action("onevntemplate chmod #{@template_id} 000")

        as_user("userA") do
            cli_action("onevntemplate delete #{@template_id}", false)
        end
    end

    it "Owner user should check ADMIN right is set" do
        cli_action("onevntemplate chmod #{@template_id} 100")

        as_user("userA") do
            cli_action("onevntemplate chmod #{@template_id} 777")
        end

        cli_action("onevntemplate chmod #{@template_id} 000")

        as_user("userA") do
            cli_action("onevntemplate chmod #{@template_id} 777", false)
        end
    end

    it "Group user should check USE right is set" do
        cli_action("onevntemplate chmod #{@template_id} 040")

        ["userB", "userD"].each { |u|
            as_user u do
                cli_action("onevntemplate show test")
                expect(cli_action("onevntemplate list").stdout).to match(/test/)
            end
        }

        cli_action("onevntemplate chmod #{@template_id} 600")

        ["userB", "userD"].each { |u|
            as_user u do
                cli_action("onevntemplate show test", false)
                expect(cli_action("onevntemplate list").stdout).to_not match(/test/)
            end
        }
    end

    it "Group user should check MANAGE right is set" do
        cli_action("onevntemplate chmod #{@template_id} 020")

        ["userB", "userD"].each { |u|
            as_user u do
                cli_action("onevntemplate chmod #{@template_id} 020")
            end
        }

        cli_action("onevntemplate chmod #{@template_id} 000")

        ["userB", "userD"].each { |u|
            as_user u do
                cli_action("onevntemplate chmod #{@template_id} 020", false)
            end
        }
    end

    it "User not in group should check USE right is unset" do
        cli_action("onevntemplate chmod #{@template_id} 600")

        as_user 'userC' do
            cli_action("onevntemplate show #{@template_id}", false)

            expect(cli_action("onevntemplate list").stdout).to_not match(/test/)

            cli_action("onevntemplate delete #{@template_id}", false)
        end
    end

    it "User not in group should check MANAGE right is set" do
        cli_action("onevntemplate chmod #{@template_id} 002")

        as_user 'userC' do
            cli_action("onevntemplate delete #{@template_id}")
        end

        @template_id = -1
    end

    it "User not in group should check ADMIN right is set" do
        cli_action("onevntemplate chmod #{@template_id} 001")

        as_user 'userC' do
            cli_action("onevntemplate chmod #{@template_id} 600")
            cli_action("onevntemplate chmod #{@template_id} 770", false)
        end
    end

    it "User distinct to oneadmin or userA should not be allowed to create VNTEMPLATES" do
        

        as_user 'userC' do
            template = <<-EOF
                NAME   = test-acl
                VN_MAD = bridge
                ATT1   = "VAL1"
                ATT2   = "VAL2"
            EOF

            cli_create("onevntemplate create", template, false)
        end
    end
end

