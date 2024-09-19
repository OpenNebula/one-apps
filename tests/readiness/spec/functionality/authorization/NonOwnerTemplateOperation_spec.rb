#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non owned Template operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
        EOF

        as_user "userA" do
            @tid = cli_create("onetemplate create", @template_1)
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to perform actions on the non-owned Template and check the failure" do
        as_user "userB" do
            cli_action("onetemplate show #{@tid}", false)
            cli_action("onetemplate delete #{@tid}", false)
            cli_action("onetemplate rename #{@tid} abcd", false)
        end
    end

    it "should try to instantiate an existing non-owned Template that is not "<<
        "shared and check the failure" do

        as_user "userB" do
            cli_action("onetemplate instantiate #{@tid}", false)
        end
    end

    it "should instantiate, as oneadmin, an existing non-owned Template" do
        vmid = cli_create("onetemplate instantiate #{@tid}")
        cli_action("onevm show #{vmid}")
    end
end