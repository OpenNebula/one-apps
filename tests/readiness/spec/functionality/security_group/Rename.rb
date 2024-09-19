
#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Security Group rename test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @template = "NAME = SG\nATT1 = VAL1\nATT2 = VAL2"

        cli_create_user("uA1", "abc")
        cli_create_user("uA2", "abc")

        cli_action("oneacl create '* SECGROUP/* CREATE'")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should rename a security group and check the list and show commands" do
        id = cli_create("onesecgroup create", "NAME = test_name")

        expect(cli_action("onesecgroup list").stdout).to match(/test_name/)
        expect(cli_action("onesecgroup show test_name").stdout).to match(
            /NAME *: *test_name/)

        cli_action("onesecgroup rename test_name new_name")

        expect(cli_action("onesecgroup list").stdout).not_to match(/test_name/)
        cli_action("onesecgroup show test_name", false)

        expect(cli_action("onesecgroup list").stdout).to match(/new_name/)
        expect(cli_action("onesecgroup show new_name").stdout).to match(
            /NAME *: *new_name/)

        cli_action("onesecgroup delete #{id}")
    end

    it "should not rename a security group to an existing name" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
            skip 'Does not work with mysql DB backend'
        end

        id1 = cli_create("onesecgroup create", "NAME = test_name")
        id2 = cli_create("onesecgroup create", "NAME = foo")

        cli_action("onesecgroup rename foo test_name", false)
        cli_action("onesecgroup rename foo FoO")

        expect(cli_action("onesecgroup list").stdout).to match(/test_name/)
        expect(cli_action("onesecgroup list").stdout).to match(/FoO/)

        expect(cli_action("onesecgroup show test_name").stdout).to match(
            /NAME *: *test_name/)
        expect(cli_action("onesecgroup show #{id2}").stdout).to match(
            /NAME *: *FoO/)

        cli_action("onesecgroup delete FoO")
        cli_action("onesecgroup delete #{id1}")
    end

    it "should rename a security group to an existing name & different owner" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
            skip 'Does not work with mysql DB backend'
        end

        id1 = cli_create("onesecgroup create", "NAME = test_name")
        id2 = cli_create("onesecgroup create", "NAME = foo")

        cli_action("oneuser create a a")

        cli_action("onesecgroup chown foo a users")

        cli_action("onesecgroup rename test_name foo")

        expect(cli_action("onesecgroup list").stdout).to match(/foo/)
        expect(cli_action("onesecgroup list").stdout).not_to match(/test_name/)

        cli_action("onesecgroup show test_name", false)

        cli_action("onesecgroup delete #{id1}")
        cli_action("onesecgroup delete #{id2}")
    end
end
