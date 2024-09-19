#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'pry'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Virtual Network Template operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("new_user", "abc")
        cli_create("onegroup create new_group")
        cli_action("oneuser chgrp new_user oneadmin")
        cli_create_user("abc", "abc")
    end

    before(:each) do
        template = <<-EOF
            NAME      = test
            VN_MAD    = bridge
        EOF

        @template_id = cli_create("onevntemplate create", template)
    end

    after(:each) do
        cli_action("onevntemplate delete test")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create a new VN Template" do
        expect(cli_action("onevntemplate list").stdout).to match(/test/)
        expect(cli_action("onevntemplate show test").stdout).to match(/VN_MAD *= *"bridge"/)
    end

    it "should create a new VN Template from XML" do
        xml_text =
            "<VNTEMPLATE>"<<
            "  <NAME>xml_test</NAME>"<<
            "  <VN_MAD>bridge</VN_MAD>"<<
            "</VNTEMPLATE>"

        id = cli_create("onevntemplate create", xml_text)
        expect(cli_action("onevntemplate list").stdout).to match(/xml_test/)
        expect(cli_action("onevntemplate show xml_test").stdout).to match(/VN_MAD *= *"bridge"/)
    end

    it "should try to create an existing VN Template and check the failure" do
        cli_create("onevntemplate create", "NAME=test\n", false)
    end

    it "should edit dynamically an existing VN Template (append)" do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
        EOF

        cli_update("onevntemplate update test", str, true)

        xml = cli_action_xml("onevntemplate show -x #{@template_id}")

        expect(xml['TEMPLATE/ATT2']).to eq("NEW_VAL")
        expect(xml['TEMPLATE/ATT3']).to eq("VAL3")
        expect(xml['TEMPLATE/ATT4']).to eq("A new value")
    end

    it "should fails when edit dynamically an existing VN Template with RA (append)" do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
            VN_MAD = ovswitch
        EOF

        cli_action("onevntemplate chmod #{@template_id} 666")

        as_user "abc" do
            cli_update("onevntemplate update #{@template_id}", str, true, false)
        end
    end

    it "should edit dynamically an existing VN Template (replace)" do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
        EOF

        cli_update("onevntemplate update test", str, false)

        xml = cli_action_xml("onevntemplate show -x #{@template_id}")

        expect(xml['TEMPLATE/ATT1']).to be_nil
        expect(xml['TEMPLATE/ATT2']).to eq("NEW_VAL")
        expect(xml['TEMPLATE/ATT3']).to eq("VAL3")
        expect(xml['TEMPLATE/ATT4']).to eq("A new value")
    end

    it "should fails to edit dynamically an existing VN Template with RA (replace)" do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
            VN_MAD = ovswitch
        EOF

        cli_action("onevntemplate chmod #{@template_id} 666")

        as_user "abc" do
            cli_update("onevntemplate update #{@template_id}", str, false, false)
        end
    end

    it "should chmod an existing VN Template" do
        cli_action("onevntemplate chmod test 640")

        xml = cli_action_xml("onevntemplate show -x test")

        expect(xml['PERMISSIONS/OWNER_U']).to eq("1")
        expect(xml['PERMISSIONS/OWNER_M']).to eq("1")
        expect(xml['PERMISSIONS/OWNER_A']).to eq("0")
        expect(xml['PERMISSIONS/GROUP_U']).to eq("1")
        expect(xml['PERMISSIONS/GROUP_M']).to eq("0")
        expect(xml['PERMISSIONS/GROUP_A']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_U']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_M']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_A']).to eq("0")

        cli_action("onevntemplate chmod test 400")

        xml = cli_action_xml("onevntemplate show -x test")

        expect(xml['PERMISSIONS/OWNER_U']).to eq("1")
        expect(xml['PERMISSIONS/OWNER_M']).to eq("0")
        expect(xml['PERMISSIONS/OWNER_A']).to eq("0")
        expect(xml['PERMISSIONS/GROUP_U']).to eq("0")
        expect(xml['PERMISSIONS/GROUP_M']).to eq("0")
        expect(xml['PERMISSIONS/GROUP_A']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_U']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_M']).to eq("0")
        expect(xml['PERMISSIONS/OTHER_A']).to eq("0")
    end

    it "should clone an existing VN Template" do
        cli_action("onevntemplate clone test new")

        expect(cli_action("onevntemplate list").stdout).to match(/test/)
        expect(cli_action("onevntemplate list").stdout).to match(/new/)

        xml = cli_action_xml("onevntemplate show -x new")

        expect(xml['TEMPLATE/VN_MAD']).to eq("bridge")
    end

    it "should clone an existing VN Template as other user" do
        cli_action("onevntemplate chmod test 644")

        as_user "new_user" do
            cli_action("onevntemplate clone test new2")

            expect(cli_action("onevntemplate list").stdout).to match(/test/)
            expect(cli_action("onevntemplate list").stdout).to match(/new2/)

            xml = cli_action_xml("onevntemplate show -x new2")

            expect(xml['TEMPLATE/VN_MAD']).to eq("bridge")
            expect(xml['UNAME']).to eq("new_user")
            expect(xml['GNAME']).to eq("oneadmin")
        end
    end

    it "should try to change the owner of Template repeating name, and fail" do
        id = -1

        as_user "new_user" do
            id = cli_create("onevntemplate create", "NAME=test\nVN_MAD=bridge\n")
        end

        cli_action("onevntemplate chown #{id} 0", false)

        as_user "new_user" do
            id = cli_action("onevntemplate delete #{id}")
        end
    end

    it "should change the owner of an existing Template" do
        cli_action("onevntemplate chown test new_user")
        xml = cli_action_xml("onevntemplate show -x test")

        expect(xml['UNAME']).to eq("new_user")
        expect(xml['GNAME']).to eq("oneadmin")
    end

    it "should rename a VN Template" do
        cli_action("onevntemplate rename test rename-test")

        expect(cli_action("onevntemplate list").stdout).to match(/rename-test/)

        cli_action("onevntemplate rename rename-test test")
    end

    it "should lock and unlock VN Template" do
        cli_action("onevntemplate lock test --use")

        expect(cli_action("onevntemplate show test").stdout).to match(/Use/)

        cli_action("onevntemplate unlock test")

        expect(cli_action("onevntemplate show test").stdout).not_to match(/Use/)

    end

end

