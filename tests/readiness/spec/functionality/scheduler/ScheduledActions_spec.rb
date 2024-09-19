
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduled actions tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:each) do
        @vmid = cli_create("onevm create --hold --name testvm --cpu 1 --memory 128")
        @vm   = VM.new(@vmid)
    end

    after(:each) do
        cli_action("onevm terminate #{@vmid}")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should schedule an action at a future absolute time" do
        expect(@vm.state).to eq('HOLD')

        cli_action("onevm release #{@vmid} --schedule '#{Time.now + 6}'")

        sleep 2 # Make sure the action is not executed immediately

        expect(@vm.state).to eq('HOLD')

        wait_loop(:success => 'PENDING', :timeout => 30) {
            @vm.state
        }
    end

    it "should schedule an action at a future relative time" do
        expect(@vm.state).to eq('HOLD')

        cli_action("onevm release #{@vmid} --schedule '+6'")

        sleep 2 # Make sure the action is not executed immediately

        expect(@vm.state).to eq('HOLD')

        wait_loop(:success => 'PENDING', :timeout => 30) {
            @vm.state
        }
    end

    it "should schedule two actions at a future time" do
        expect(@vm.state).to eq('HOLD')

        cli_action("onevm release #{@vmid} --schedule '#{Time.now + 3}'")
        cli_action("onevm hold #{@vmid} --schedule '#{Time.now + 6}'")

        sleep 2 # Make sure the action is not executed immediately

        wait_loop(:success => 'PENDING', :timeout => 30) {
            @vm.state
        }

        wait_loop(:success => 'HOLD', :timeout => 30) {
            @vm.state
        }
    end
end
