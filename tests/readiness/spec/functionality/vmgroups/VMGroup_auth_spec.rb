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

        @admin_group = <<-EOF
          NAME = "admin group"

          ROLE = [ NAME = "web" ]
          ROLE = [ NAME = "db"  ]

          ANTI_AFFINED = "web, db"
        EOF

        @vmg_admin = cli_create("onevmgroup create", @admin_group)

        @uid =  cli_create_user("userA", "passwordA")

        @user_group = <<-EOF
          NAME = "user_group"

          ROLE = [ NAME = "web" ]
          ROLE = [ NAME = "db"  ]

          ANTI_AFFINED = "web, db"
        EOF

        as_user "userA" do
            @vmg_user = cli_create("onevmgroup create", @user_group)
        end

    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should perform actions on owned VM Groups" do
        as_user "userA" do
            vm = <<-EOF
                NAME = testvm1
                CPU  = 1
                MEMORY = 128

                VMGROUP = [
                  VMGROUP_NAME = "USER GROUP",
                  ROLE = "web"
                ]
            EOF

            cli_action("onevmgroup show #{@vmg_user}")
            cli_action("onevmgroup rename #{@vmg_user} \"USER GROUP\"")

            vmid  = cli_create("onevm create", vm)

            vmgxml= cli_action_xml("onevmgroup show -x #{@vmg_user}")

            rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
            expect(rids).to match_array(["0", "1"])

            expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
            expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to eq("#{vmid}")
        end
    end

    it "should not perform actions on not-owned VM Groups" do
        as_user "userA" do
            vm = <<-EOF
                NAME = testvm1
                CPU  = 1
                MEMORY = 128

                VMGROUP = [
                  VMGROUP_ID = "#{@vmg_admin}",
                  ROLE = "web"
                ]
            EOF

            cli_action("onevmgroup show #{@vmg_admin}", false)
            cli_action("onevmgroup rename #{@vmg_admin} \"USER GROUP\"", false)

            vmid  = cli_create("onevm create", vm, false)
        end
    end

    it "should  perform actions on acl-auth VM Groups" do
        cli_action("oneacl create \'\##{@uid} VMGROUP/\##{@vmg_admin} USE #0\'")

        as_user "userA" do
            vm = <<-EOF
                NAME = testvm1
                CPU  = 1
                MEMORY = 128

                VMGROUP = [
                  VMGROUP_NAME= "admin group",
                  VMGROUP_UID = "0",
                  ROLE = "web"
                ]
            EOF

            cli_action("onevmgroup show #{@vmg_admin}")
            cli_action("onevmgroup rename #{@vmg_admin} \"USER GROUP\"", false)

            vmid  = cli_create("onevm create", vm)

            vmgxml= cli_action_xml("onevmgroup show -x #{@vmg_admin}")

            rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
            expect(rids).to match_array(["0", "1"])

            expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
            expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to eq("#{vmid}")
        end
    end
end
