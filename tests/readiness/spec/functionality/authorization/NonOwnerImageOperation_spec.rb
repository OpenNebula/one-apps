#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Non owned Image operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        as_user "userA" do
            @img_id = cli_create("oneimage create --name test_img " <<
                        "--size 100 --type datablock -d default")
        end

        @template_1 = <<-EOF
            NAME = testvm1
            CPU  = 1
            MEMORY = 128
            DISK = [ IMAGE_ID = #{@img_id} ]
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should try to perform actions on the non-owned Image and check the failure" do
        as_user "userB" do
            cli_action("oneimage show #{@img_id}", false)
            cli_action("oneimage delete #{@img_id}", false)
            cli_action("oneimage enable #{@img_id}", false)
            cli_action("oneimage rename #{@img_id} abcd", false)
        end
    end
    
    it "should try to allocate a VirtualMachine that uses an existing" <<
        " non-owned Image that is not shared and check the failure" do

        as_user "userB" do
            cli_create("onevm create", @template_1, false)
        end
    end
    
    it "should allocate a new VirtualMachine, as oneadmin, that uses an" <<
        " existing non-owned Image" do

        vmid = cli_create("onevm create", @template_1)
        cli_action("onevm show #{vmid}")
    end
end