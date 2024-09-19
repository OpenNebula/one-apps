require 'init'
require 'resolv'

RSpec.describe "VM failure + resched" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate #{@defaults[:template]}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "null route host" do
        @info[:current_host] = @info[:vm]["HISTORY_RECORDS/HISTORY[last()]/HOSTNAME"]
        @info[:ip] = Resolv.getaddress(@info[:current_host])

        # kill monitord-client
        SafeExec::run("ssh #{@info[:ip]} 'pkill ruby'")

        cmd = "sudo ip route add #{@info[:ip]} via 127.0.0.1 "
        SafeExec::run(cmd).expect_success
    end

    it "waits until VM is unknown" do
        @info[:vm].state?("UNKNOWN", /FAIL/, :timeout => 1200)
    end

    it "resched" do
        @info[:vm].resched_running
    end

    after(:all) do
        cmd = "sudo ip route del #{@info[:ip]} via 127.0.0.1 "
        SafeExec::run(cmd).expect_success

        @info[:vm].terminate_hard
    end
end
