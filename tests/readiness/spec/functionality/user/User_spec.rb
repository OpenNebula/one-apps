#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "User operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @user_id  = cli_create_user("test_name2", 'passwordA')
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should check user access" do
        as_user("test_name2") {
            cli_action("oneuser show")
        }
    end

    it "should try to create an existing User and check the failure" do
        cli_create("oneuser create test_name2 pass", "", false)
    end

    it "should disable user" do
        cli_action("oneuser disable test_name2")

        as_user("test_name2") {
            cli_action("oneuser show", false)
        }
    end

    it "should enable user" do
        cli_action("oneuser enable test_name2")

        as_user("test_name2") {
            cli_action("oneuser show")
        }
    end

    it "should change an existing User's password" do
        cli_action("oneuser passwd #{@user_id} passwordB")

        xml = cli_action_xml("oneuser show -x #{@user_id}")
        expect(xml['PASSWORD']).to eq(Digest::SHA256.hexdigest("passwordB"))
    end

    it "should not create User with not allowed chars" do
        cli_action("oneuser create test:username passwd", false)
        cli_action("oneuser create username \"  passw  d\"", false)
    end

    it "should delete an existing User" do
        cli_action("oneuser delete #{@user_id}")
        expect(cli_action("oneuser list").stdout).to_not match(/test_name2/)
    end

    it "should fail deleting a non-existing user" do
        cli_action("oneuser delete test_name2", false)
    end
end
