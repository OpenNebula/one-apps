#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Rename VirtualNetwork test" do
    def match_cli(action, regexp)
        expect(cli_action(action).stdout).to match(regexp)
    end

    def not_match_cli(action, regexp)
        expect(cli_action(action).stdout).to_not match(regexp)
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:each) do
        @vnet_id = cli_create("onevnet create",
                              "NAME=test_name\nVN_MAD=dummy\nBRIDGE=br0\n")
    end

    after(:each) do
        vn = VN.new(@vnet_id)
        vn.delete
        vn.deleted?
    end

    it "should rename a vnet and check the list and show commands" do
        match_cli("onevnet list", /test_name/)
        match_cli("onevnet show test_name", /NAME *: *test_name/)

        cli_action("onevnet rename test_name new_name")

        not_match_cli("onevnet list", /test_name/)
        cli_action("onevnet show test_name", false)

        match_cli("onevnet list", /new_name/)
        match_cli("onevnet show new_name", /NAME *: *new_name/)
    end

    it "should rename a vnet, restart opennebula and check its name" do
        match_cli("onevnet list",/test_name/)
        match_cli("onevnet show test_name", /NAME *: *test_name/)

        cli_action("onevnet rename test_name new_name")

        @one_test.stop_one
        @one_test.start_one

        not_match_cli("onevnet list", /test_name/)
        cli_action("onevnet show test_name", false)

        match_cli("onevnet list", /new_name/)
        match_cli("onevnet show new_name", /NAME *: *new_name/)
    end

    it "should try to rename a vnet to an existing name, and fail" do
        net = VN.create("NAME=foo\nVN_MAD=dummy\nBRIDGE=br0\n")

        cli_action("onevnet rename foo test_name", false)

        match_cli("onevnet list",/test_name/)
        match_cli("onevnet list",/foo/)
        match_cli("onevnet show test_name",/NAME *: *test_name/)
        match_cli("onevnet show foo",/NAME *: *foo/)

        net.ready?

        net.delete
    end

    it "should rename a vnet to an existing name, case sensitive" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'Does not work withy mysql DB backend'
        end

        net = VN.create("NAME=foo\nVN_MAD=dummy\nBRIDGE=br0\n")

        cli_action("onevnet rename foo TEST_name")

        match_cli("onevnet list",/test_name/)
        match_cli("onevnet list",/TEST_name/)
        match_cli("onevnet show test_name",/NAME *: *test_name/)
        match_cli("onevnet show TEST_name",/NAME *: *TEST_name/)

        net.ready?

        net.delete
    end

    it "should rename a vnet to an existing name but with different owner" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'Does not work withy mysql DB backend'
        end

        cli_action("oneuser create a a")

        net = VN.create("NAME=foo\nVN_MAD=dummy\nBRIDGE=br0\n")

        cli_action("onevnet chown foo a users")

        cli_action("onevnet rename test_name foo")

        not_match_cli("onevnet list",/test_name/)
        match_cli("onevnet list",/foo/)

        cli_action("onevnet show test_name", false)

        net.ready?

        net.delete
    end
end
