
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Virtual Machine hold test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    it "should create a VM on pending and then hold it" do
        id = cli_create("onevm create --name test --cpu 1 --memory 1")
        vm = VM.new(id)

        vm.state?("PENDING")

        cli_action("onevm hold #{id}")
        vm.state?("HOLD")

        cli_action("onevm recover --delete #{id}")
    end

    it "should create a VM on hold and then release it" do
        id = cli_create("onevm create --hold --name test --cpu 1 --memory 1")
        vm = VM.new(id)

        vm.state?("HOLD")

        cli_action("onevm release #{id}")
        vm.state?("PENDING")

        cli_action("onevm recover --delete #{id}")
    end

    it "should instantiate a template on pending and then hold it" do
        t_id = cli_create("onetemplate create --name test --cpu 1 --memory 1")

        id = cli_create("onetemplate instantiate #{t_id} --name vm")
        vm = VM.new(id)

        vm.state?("PENDING")

        cli_action("onevm hold vm")
        vm.state?("HOLD")

        cli_action("onevm recover --delete vm")
        cli_action("onetemplate delete #{t_id}")
    end

    it "should instantiate a template on hold and then release it" do
        t_id = cli_create("onetemplate create --name test --cpu 1 --memory 1")

        id = cli_create("onetemplate instantiate --hold #{t_id} --name vm")
        vm = VM.new(id)

        vm.state?("HOLD")

        cli_action("onevm release vm")
        vm.state?("PENDING")

        cli_action("onevm recover --delete vm")
        cli_action("onetemplate delete #{t_id}")
    end
end
