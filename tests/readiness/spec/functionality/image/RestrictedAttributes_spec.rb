#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Restricted attributes test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("uA", "abc")

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update default", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should not create an Image with a default restricted attribute" do
        as_user "uA" do
            cli_create("oneimage create -d 1 --source /etc/hosts --name test"\
                       " --size 100 --format raw", "", false)
        end
    end

    it "should create an Image with a default restricted attribute as oneadmin" do
        cli_create("oneimage create -d 1 --source /etc/hosts --name test"\
                   " --size 100 --format raw")
    end
end