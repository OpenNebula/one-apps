#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Template operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        template = <<-EOF
            NAME   = test
            CPU    = 2
            MEMORU = 128
            ATT1   = "VAL1"
            ATT2   = "VAL2"
        EOF

        @template_id = cli_create("onetemplate create", template)

        @uid = cli_create_user("new_user", "abc")
        @gid = cli_create("onegroup create new_group")
        cli_action("oneuser chgrp new_user new_group")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should create a new Template as oneadmin and check group and owner" do
        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['UID']).to eq("0")
        expect(xml['GID']).to eq("0")
    end

    it "should change an existing Template group and check group and owner" do
        cli_action("onetemplate chgrp #{@template_id} new_group")

        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['UID']).to eq("0")
        expect(xml['GID']).to eq("#{@gid}")
        expect(xml['GNAME']).to eq("new_group")
    end

    it "should change an existing Template owner and check group and owner" do
        cli_action("onetemplate chown #{@template_id} new_user")

        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['UID']).to eq("#{@uid}")
        expect(xml['GID']).to eq("#{@gid}")
        expect(xml['UNAME']).to eq("new_user")
        expect(xml['GNAME']).to eq("new_group")
    end

    it "should change an existing Template owner & group" do
        cli_action("onetemplate chown #{@template_id} 0 0")

        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['UID']).to eq("0")
        expect(xml['GID']).to eq("0")
        expect(xml['GNAME']).to eq("oneadmin")
    end
end

