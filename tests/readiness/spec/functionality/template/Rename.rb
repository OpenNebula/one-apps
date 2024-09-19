#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Permissions test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:each) do
        template = <<-EOF
            NAME   = test_name
            CPU    = 2
            MEMORU = 128
            ATT1   = "VAL1"
            ATT2   = "VAL2"
        EOF

        @template_id = cli_create("onetemplate create", template)
    end

    after(:each) do
        cli_action("onetemplate delete #{@template_id}") if @template_id != -1
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should rename a template and check the list and show commands" do
        expect(cli_action("onetemplate list").stdout).to match(/test_name/)
        expect(cli_action("onetemplate show test_name").stdout).to match(/NAME *: *test_name/)

        cli_action("onetemplate rename test_name new_name")

        expect(cli_action("onetemplate list").stdout).to_not match(/test_name/)
        cli_action("onetemplate show test_name", false)

        expect(cli_action("onetemplate list").stdout).to match(/new_name/)
        expect(cli_action("onetemplate show new_name").stdout).to match(/NAME *: *new_name/)
    end

    it "should rename a template, restart opennebula and check its name" do
        expect(cli_action("onetemplate list").stdout).to match(/test_name/)
        expect(cli_action("onetemplate show test_name").stdout).to match(/NAME *: *test_name/)

        cli_action("onetemplate rename test_name new_name")

        @one_test.stop_one
        @one_test.start_one

        expect(cli_action("onetemplate list").stdout).to_not match(/test_name/)
        cli_action("onetemplate show test_name", false)

        expect(cli_action("onetemplate list").stdout).to match(/new_name/)
        expect(cli_action("onetemplate show new_name").stdout).to match(/NAME *: *new_name/)
    end

    it "should try to rename a template to an existing name, and fail" do
        cli_create("onetemplate create", "NAME=foo\nCPU=1\nMEMORY=128\n")
        cli_action("onetemplate rename foo test_name",false)

        expect(cli_action("onetemplate list").stdout).to match(/test_name/)
        expect(cli_action("onetemplate list").stdout).to match(/foo/)
        expect(cli_action("onetemplate show test_name").stdout).to match(/NAME *: *test_name/)
        expect(cli_action("onetemplate show foo").stdout).to match(/NAME *: *foo/)

        cli_action("onetemplate delete foo")
    end

    it "should rename a template to an existing name, but with different capitalization" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'Does not work with mysql DB backend'
        end

        cli_create("onetemplate create", "NAME=foo\nCPU=1\nMEMORY=128\n")
        cli_action("onetemplate rename foo TEST_name")

        expect(cli_action("onetemplate list").stdout).to match(/test_name/)
        expect(cli_action("onetemplate list").stdout).to match(/TEST_name/)
        expect(cli_action("onetemplate show test_name").stdout).to match(/NAME *: *test_name/)
        expect(cli_action("onetemplate show TEST_name").stdout).to match(/NAME *: *TEST_name/)

        cli_action("onetemplate delete TEST_name")
    end

    it "should rename a template to an existing name but with different owner" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'Does not work with mysql DB backend'
        end

        cli_action("oneuser create a a")

        id = cli_create("onetemplate create", "NAME=foo\nCPU=1\nMEMORY=128\n")

        cli_action("onetemplate chown foo a users")

        cli_action("onetemplate rename test_name foo")

        expect(cli_action("onetemplate list").stdout).to match(/foo/)
        expect(cli_action("onetemplate list").stdout).to_not match(/test_name/)

        cli_action("onetemplate show test_name", false)

        cli_action("onetemplate delete #{id}")
    end
end
