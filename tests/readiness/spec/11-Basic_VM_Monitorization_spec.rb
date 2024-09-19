require 'init'

# Test the Basic VM monitorization

# Description:
# - VM is deployed & running
# - Wait for CPU MEMORY NETRX NETTX STATE values
# - [TODO] Test DISK_SIZE[ID=0]/SIZE and TOTAL_DISK_SIZE
# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Test" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    # after(:all) do
    #     cli_action("onevm delete #{@info[:vm_id]}")
    # end

    it "deploys" do
        @info[:vm].running?
    end

    it "Get monitoring data" do
        wait_loop(:timeout => 300) do
            @info[:vm].info

            fields = %w(MONITORING/CPU MONITORING/MEMORY MONITORING/NETRX
                        MONITORING/NETTX STATE)

            monitoring = true
            fields.each do |field|
                if @info[:vm][field].nil?
                    monitoring = false
                    break
                end
            end

            monitoring
        end
    end

    # TODO: check for DISK_SIZE[ID=0]/SIZE and TOTAL_DISK_SIZE

    it "terminate vm " do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end
end
