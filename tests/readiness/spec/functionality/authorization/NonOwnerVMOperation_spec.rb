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
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to perform actions on the non-owned VirtualMachine and check the failure" do
        as_user "userB" do
            cli_action("onevm show #{@vmid}", false)
            cli_action("onevm hold #{@vmid}", false)
            cli_action("onevm terminate #{@vmid}", false)
            cli_action("onevm rename #{@vmid} abcd", false)
        end
    end
end