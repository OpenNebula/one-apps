#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VMGroup operations test" do
    #---------------------------------------------------------------------------
    # TESTS general operations
    #---------------------------------------------------------------------------
    it "should create a empty VM Group" do
        vmg =<<-EOT
          NAME="Empty VMGroup"
        EOT

        vmgid = cli_create("onevmgroup create", vmg)
        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        expect(vmgxml['NAME']).to eq('Empty VMGroup')

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create a VM Group without name" do
        vmg =<<-EOT
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db ]

            AFFINED = "web, db"
        EOT

        cmd = cli_create("onevmgroup create", vmg, false)

        expect(cmd.stderr).to match(/NAME, it cannot be empty/)
    end

    it "should create a VM Group with roles and AFFINED/ANTI_AFFINED refs" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db, POLICY = "AFFINED"  ]
            ROLE = [ NAME = app  ]
            ROLE = [ NAME = bck  ]

            AFFINED = "web, bck"
            ANTI_AFFINED = "app, db"
        EOT

        vmgid = cli_create("onevmgroup create", vmg)
        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1", "2", "3"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(vmgxml['ROLES/ROLE[ID="2"]/NAME']).to eq("app")
        expect(vmgxml['ROLES/ROLE[ID="3"]/NAME']).to eq("bck")

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create a VM Group with wrong role format" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = "This is not a role"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db ]

            AFFINED = "web, db"
        EOT

        vmgid = cli_create("onevmgroup create", vmg)
        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create two VM Group with the same name" do
        vmg =<<-EOT
          NAME="Empty VMGroup"
        EOT

        vmgid = cli_create("onevmgroup create", vmg)
        cli_create("onevmgroup create", vmg, false)

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create VM Group with a role without name" do
        vmg =<<-EOT
          NAME="Empty VMGroup"

          ROLE = [ VMS="1,2,3,2" ]
        EOT

        vmgid = cli_create("onevmgroup create", vmg, false)
    end


    it "should create a VM Group and not consider internal variable" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web, ID="23", VMS="1,2,3,4" ]
        EOT

        vmgid = cli_create("onevmgroup create", vmg)
        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="23"]/NAME']).to be_nil

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create a VM Group with wrong AFFINED refs" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db ]

            AFFINED = "web, db"
            AFFINED = "db, none"
        EOT

        vmgid = cli_create("onevmgroup create", vmg, false)
    end

    it "should not create a VM Group with wrong ANTI_AFFINED refs" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db ]

            AFFINED = "web, db"
            ANTI_AFFINED = "db, none"
        EOT

        vmgid = cli_create("onevmgroup create", vmg, false)
    end

    it "should update a VM Group without VMs" do
        vmg_update =<<-EOT
          ANTI_AFFINED = "web,db"
          ROLE = [ NAME="not updated"]
        EOT

        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db ]

            AFFINED = "web, db"
        EOT

        vmgid = cli_create("onevmgroup create", vmg)

        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(vmgxml['TEMPLATE/AFFINED']).to eq("web, db")
        expect(vmgxml['TEMPLATE/ANTI_AFFINED']).to be_nil

        cli_update("onevmgroup update #{vmgid}", vmg_update, false)

        vmgxml= cli_action_xml("onevmgroup show -x #{vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(vmgxml['TEMPLATE/ANTI_AFFINED']).to eq("web,db")

        vmg_update =<<-EOT
          ANTI_AFFINED = "web, none"
        EOT

        cli_update("onevmgroup update #{vmgid}", vmg_update, false, false)

        cli_action("onevmgroup delete #{vmgid}")
    end

    it "should not create a VM Group with roles in AFFINED/ANTI_AFFINED refs" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db  ]
            ROLE = [ NAME = app  ]
            ROLE = [ NAME = bck  ]
            ROLE = [ NAME = other  ]

            AFFINED = "web, bck, db"
            AFFINED = "web, app"
            AFFINED = "other, app"
            ANTI_AFFINED = "app, db"
            ANTI_AFFINED = "app, other"
        EOT

        vmg = cli_create("onevmgroup create", vmg, false)
        expect(vmg.stderr).to match(/db app other/)
    end

    it "should not create a VM Group with ANTI_AFFINED roles in an AFFINED rule" do
        vmg =<<-EOT
            NAME = "A group"
            ROLE = [ NAME = web, POLICY = ANTI_AFFINED ]
            ROLE = [ NAME = db, POLICY = AFFINED  ]
            ROLE = [ NAME = app  ]
            ROLE = [ NAME = other  ]

            AFFINED = "web, db"
            ANTI_AFFINED = "app, other"
        EOT

        vmg = cli_create("onevmgroup create", vmg, false)
        expect(vmg.stderr).to match(/web is in an AFFINED/)
    end
end
