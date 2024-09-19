
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Non existing VirtualMachine operations test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    it "should try to get the information from a non existing VirtualMachine" <<
        " and check the failure" do
        cli_action("onevm show 0", false)
        cli_action("onevm show test", false)
    end

    it "should try to deploy a non existing VirtualMachine and check the" <<
        " failure" do
        cli_action("onehost show 0", false)
        cli_action("onehost show blue", false)
    end

    it "should try to cancel a non existing VirtualMachine and check the" <<
        " failure" do
        cli_action("onevm terminate --hard 0", false)
        cli_action("onevm terminate --hard test", false)
    end

    it "should try to migrate a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm migrate 0 0", false)
    end

    it "should try to live_migrate a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm migrate --live 0 0", false)
    end

    it "should try to shutdown a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm terminate 0", false)
        cli_action("onevm terminate test", false)
    end

    it "should try to suspend a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm suspend 0", false)
        cli_action("onevm suspend test", false)
    end

    it "should try to resume a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm resume 0", false)
        cli_action("onevm resume test", false)
    end

    it "should try to stop a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm stop 0", false)
        cli_action("onevm stop test", false)
    end

    it "should try to finalize a non existing VirtualMachine and check" <<
        " the failure" do
        cli_action("onevm recover --delete 0", false)
        cli_action("onevm recover --delete test", false)
    end
end