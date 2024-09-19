$LOAD_PATH.unshift File.dirname(__FILE__)

require 'init'
require 'host'
require 'pp'
require 'containerhost'

shared_examples_for 'LXC idmap checks' do |unprivileged, shift|
    it 'deploy VM' do
        cmd = 'onetemplate instantiate'

        if shift
            cmd << " #{@defaults[:template_shifted]}"
        else
            cmd << " #{@defaults[:template]}"

        end

        cmd << ' --raw LXC_UNPRIVILEGED=NO' if unprivileged == false

        @info[:vm] = VM.new(cli_create(cmd))
        @info[:vm].running?

        onehost = CLITester::Host.new(@info[:vm].host_id)
        @info[:host] = ContainerHost.new_host(onehost)
    end

    it 'has the correct shift' do
        expect(@info[:host].shift_okay?(@info[:vm].instance_name)).to be(true)
    end

    it "is unprivileged:#{unprivileged}" do
        expect(@info[:host].privileged?(@info[:vm].instance_name)).to be(!unprivileged)
    end

    it 'terminate VM' do
        @info[:vm].terminate_hard
    end
end
