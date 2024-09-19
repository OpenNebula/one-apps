#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non owned VirtualMachine operations test" do
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
            @vmid = cli_create("onetemplate instantiate #{@tid}")

            cli_action("onevm chmod #{@vmid} 640")
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should perform an ADMIN operation with USE rigths" do
        as_user "userB" do
            cli_action("onevm recover --delete #{@vmid}", false)
        end
    end
end
