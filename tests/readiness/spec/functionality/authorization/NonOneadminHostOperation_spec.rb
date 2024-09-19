#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non oneadmin Host operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")

        @hid = cli_create("onehost create host02 --im dummy --vm dummy")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to create a new Host and check the failure" do
        as_user "userA" do
            cli_action("onehost create host02 --im dummy --vm dummy", false)
        end
    end
       
    it "should try to perform actions on a existing Host as a user and check the failure" do
        as_user "userA" do
            cli_action("onehost show #{@hid}", false)
            cli_action("onehost enable #{@hid}", false)
            cli_action("onehost delete #{@hid}", false)
        end
    end
end