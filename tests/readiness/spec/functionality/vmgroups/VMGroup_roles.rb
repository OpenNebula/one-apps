#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VMGroup roles API test" do
    before(:each) do
        vmg = <<-EOT
            NAME = "Test group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db, POLICY = "AFFINED"  ]
            ROLE = [ NAME = app  ]
            ROLE = [ NAME = bck  ]
            ROLE = [ NAME = front  ]
            ROLE = [ NAME = other  ]

            AFFINED = "web, db"
            ANTI_AFFINED = "app, bck"
        EOT

        @vmgid = cli_create("onevmgroup create", vmg)
    end

    after(:each) do
        cli_action("onevmgroup delete #{@vmgid}")
    end

    it "should update role" do
        # Test initial state
        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="4"]/POLICY']).to be_nil

        # Update by role ID
        role_update = 'POLICY = "AFFINED"'

        cli_update("onevmgroup role-update #{@vmgid} 4", role_update, false)

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="4"]/POLICY']).to eq("AFFINED")

        # todo Update by role name
        role_update = 'POLICY = "ANTI_AFFINED"'
        cli_update("onevmgroup role-update #{@vmgid} front", role_update, false)

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="4"]/POLICY']).to eq("ANTI_AFFINED")
    end

    it "should add role" do
        role_templ = <<-EOT
            NAME = "new_role"
            POLICY = "AFFINED"
        EOT

        cli_update("onevmgroup role-add #{@vmgid}", role_templ, false)

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="6"]/NAME']).to eq("new_role")
        expect(xml['ROLES/ROLE[ID="6"]/POLICY']).to eq("AFFINED")
    end

    it "should delete role" do
        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml.retrieve_xmlelements('ROLES/ROLE').size()).to eq(6)
        expect(xml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(xml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(xml['ROLES/ROLE[ID="2"]/NAME']).to eq("app")
        expect(xml['ROLES/ROLE[ID="3"]/NAME']).to eq("bck")
        expect(xml['ROLES/ROLE[ID="4"]/NAME']).to eq("front")
        expect(xml['ROLES/ROLE[ID="5"]/NAME']).to eq("other")

        cli_action("onevmgroup role-delete #{@vmgid} 4") # delete by id
        cli_action("onevmgroup role-delete #{@vmgid} other") # delete by name

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml.retrieve_xmlelements('ROLES/ROLE').size()).to eq(4)
        expect(xml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(xml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(xml['ROLES/ROLE[ID="2"]/NAME']).to eq("app")
        expect(xml['ROLES/ROLE[ID="3"]/NAME']).to eq("bck")
        expect(xml['ROLES/ROLE[ID="4"]/NAME']).to be_nil
        expect(xml['ROLES/ROLE[ID="5"]/NAME']).to be_nil
    end

    it "should fail to update or delete role with inconsistencies" do
        cli_action("onevmgroup role-delete #{@vmgid} 1", false)

        role_update = 'POLICY = "ANTI_AFFINED"'

        cli_update("onevmgroup role-update #{@vmgid} 0", role_update, false, false)
    end

    it "should rename role" do
        role_update = 'NAME="renamed"'

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="5"]/NAME']).to eq("other")

        cli_update("onevmgroup role-update #{@vmgid} 5", role_update, false)

        xml = cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(xml['ROLES/ROLE[ID="5"]/NAME']).to eq("renamed")
    end

    it "should fail to rename to existing name" do
        role_update = 'NAME="web"'

        cli_update("onevmgroup role-update #{@vmgid} 5", role_update, false, false)
    end

    it "should fail to update or delete role with VMs" do
        template = <<-EOT
            NAME="test"
            CPU = 1
            MEMORY = 1024

            VMGROUP = [
                VMGROUP_NAME = "Test group",
                ROLE = "web"
            ]
        EOT

        vm_id = cli_create("onevm create", template)

        role_update = 'POLICY="AFFINED"'

        cli_update("onevmgroup role-update #{@vmgid} 0", role_update, false, false)
        cli_action("onevmgroup role-delete #{@vmgid} 0", false)
    end
end
