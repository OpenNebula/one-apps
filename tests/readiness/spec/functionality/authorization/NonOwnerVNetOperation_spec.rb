#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non owned VirtualNetwork operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")

        cli_create("onegroup create newgroup")
        cli_action("onevdc delgroup 0 newgroup")

        cli_action("oneuser chgrp userA newgroup")
        cli_action("oneuser chgrp userB newgroup")

        cli_action("oneacl create '* NET/* CREATE'")
        cli_action("oneacl create '* CLUSTER/* ADMIN'")

        tmpl = <<-EOF
        NAME = testvnet
        BRIDGE = br0
        VN_MAD = dummy
        AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
        EOF

        as_user "userA" do
            @vnet_id = cli_create("onevnet create", tmpl)
        end

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
            NIC = [ NETWORK_ID = #{@vnet_id} ]
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to perform actions on the non-owned VirtualNetwork and check the failure" do
        as_user "userB" do
            cli_action("onevnet show #{@vnet_id}", false)
            cli_action("onevnet delete #{@vnet_id}", false)
            cli_action("onevnet rename #{@vnet_id} abcd", false)
        end
    end
    
    it "should try to allocate a VirtualMachine that uses an existing" <<
        " non-owned VirtualNetwork that is not shared and check the failure" do

        as_user "userB" do
            cli_create("onevm create", @template_1, false)
        end
    end
    
    it "should allocate a new VirtualMachine, as oneadmin, that uses an" <<
        " existing non-owned VirtualNetwork" do

        vmid = cli_create("onevm create", @template_1)
        cli_action("onevm show #{vmid}")
    end
end