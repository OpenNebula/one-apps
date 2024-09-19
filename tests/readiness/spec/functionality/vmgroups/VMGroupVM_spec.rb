#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VMGroup and VM management" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        vmg =<<-EOT
            NAME = "Test group"
            ROLE = [ NAME = web ]
            ROLE = [ NAME = db  ]
            ROLE = [ NAME = app  ]

            AFFINED = "web, db"
            ANTI_AFFINED = "app"
        EOT

        @vmgid = cli_create("onevmgroup create", vmg)
    end

    #---------------------------------------------------------------------------
    # TESTS general operations
    #---------------------------------------------------------------------------
    it "should create a VM and associate it to a role" do
        vm =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_NAME = "Test group",
            ROLE    = "web"
          ]
        EOT

        @vm1 = cli_create("onevm create", vm)
        @vm2 = cli_create("onevm create", vm)
        @vm3 = cli_create("onevm create", vm)

        vmgxml= cli_action_xml("onevmgroup show -x #{@vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1", "2"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to eq("#{@vm1},#{@vm2},#{@vm3}")
        expect(vmgxml['ROLES/ROLE[ID="1"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="2"]/VMS']).to be_nil

        cli_action("onevm terminate #{@vm1}")
        cli_action("onevm terminate #{@vm2}")
        cli_action("onevm terminate #{@vm3}")

        vmgxml= cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="1"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="2"]/VMS']).to be_nil
    end

    it "should create a VM and associate it to a role by id" do
        vm =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_ID = "#{@vmgid}",
            ROLE    = "web"
          ]
        EOT

        vm1 =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_ID = "#{@vmgid}",
            ROLE    = "db"
          ]
        EOT

        @vm1 = cli_create("onevm create", vm)
        @vm2 = cli_create("onevm create", vm1)

        vmgxml= cli_action_xml("onevmgroup show -x #{@vmgid}")

        rids = vmgxml.retrieve_elements('ROLES/ROLE/ID')
        expect(rids).to match_array(["0", "1", "2"])

        expect(vmgxml['ROLES/ROLE[ID="0"]/NAME']).to eq("web")
        expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to eq("#{@vm1}")
        expect(vmgxml['ROLES/ROLE[ID="1"]/NAME']).to eq("db")
        expect(vmgxml['ROLES/ROLE[ID="1"]/VMS']).to eq("#{@vm2}")
        expect(vmgxml['ROLES/ROLE[ID="2"]/VMS']).to be_nil

        cli_action("onevm terminate #{@vm1}")
        cli_action("onevm terminate #{@vm2}")

        vmgxml= cli_action_xml("onevmgroup show -x #{@vmgid}")

        expect(vmgxml['ROLES/ROLE[ID="0"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="1"]/VMS']).to be_nil
        expect(vmgxml['ROLES/ROLE[ID="2"]/VMS']).to be_nil
    end

    it "should not create a VM with a wrong VMGroup" do
        vm =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_NAME = "None",
            ROLE    = "web"
          ]
        EOT

        vm1 =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_ID =23 ,
            ROLE    = "web"
          ]
        EOT

        @vm1 = cli_create("onevm create", vm, false)
        @vm1 = cli_create("onevm create", vm1, false)
   end

    it "should not create a VM with a wrong role name" do
        vm =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = [
            VMGROUP_NAME = "Test group",
            ROLE    = "wrong"
          ]
        EOT

        @vm1 = cli_create("onevm create", vm, false)
   end

    it "should not create a VM and ignore VMGRoups" do
        vm =<<-EOT
          NAME="test"
          CPU = 1
          MEMORY = 1024

          VMGROUP = "Test"
        EOT

        @vm1 = cli_create("onevm create", vm)

        vmgxml= cli_action_xml("onevm show -x #{@vm1}")

        expect(vmgxml['TEMPLATE/VMGROUP']).to be_nil
        expect(vmgxml['USER_TEMPLATE/VMGROUP']).to be_nil

        cli_action("onevm terminate #{@vm1}")
   end

end
