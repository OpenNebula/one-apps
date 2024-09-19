require 'init'
require 'flow_helper'

require 'json'

# Test OneGate tasks

# Description:
# - Verify that onegate tasks work properly

#
# functions
#

#
# Test is started here
#

RSpec.describe "Test examples for OneGate to" do
    include FlowHelper
    before(:all) do
        @defaults = RSpec.configuration.defaults

        template = service_template('straight', false, false)

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        puts template_file.path
        @template_id = cli_create("oneflow-template create #{template_file.path}")
        puts @template_id

        @service_id = cli_create("oneflow-template instantiate #{@template_id}")
        puts @service_id

        # Used to pass info accross tests
        @info = {}

        wait_state(@service_id, 2)
        service = cli_action_json("oneflow show -j #{@service_id}")
        @info[:vm_id] = get_deploy_id(get_master(service))
        @info[:vm_id2] = get_deploy_id(get_slave(service))
        @info[:vm]    = VM.new(@info[:vm_id])
        @info[:vm2]   = VM.new(@info[:vm_id2])
    end

    it "connection" do
        @info[:vm].reachable?
    end

    it "onegate show vm" do
        cmd = @info[:vm].ssh("onegate vm show #{@info[:vm_id2]} --json")
        expect(cmd.success?).to be(true), "onegate show doesn't work\n" + cmd.stdout + cmd.stderr
    end

    it "onegate update vm" do
        cmd = @info[:vm].ssh("onegate vm update #{@info[:vm_id2]} --data ACTIVE=YES")
        expect(cmd.success?).to be(true), "onegate update doesn't work\n" + cmd.stdout + cmd.stderr
    end

    it "onegate check info vm" do
        cmd = @info[:vm].ssh("onegate vm show #{@info[:vm_id2]} --json")
        json_text = JSON.parse(cmd.stdout)
        active_value = json_text["VM"]["USER_TEMPLATE"]["ACTIVE"]
        expect(active_value).to eq("YES"), "onegate check doesn't work\n" + cmd.stdout + cmd.stderr
    end
    it "onegate update --erase vm" do
        cmd = @info[:vm].ssh("onegate vm update #{@info[:vm_id2]} --erase ACTIVE")
        expect(cmd.success?).to be(true), "onegate update --erase doesn't work\n" + cmd.stdout + cmd.stderr
    end

    it "onegate unresched vm" do
        cmd = @info[:vm].ssh("onegate vm unresched #{@info[:vm_id2]}")
        expect(cmd.success?).to be(true), "onegate unresched doesn't work\n" + cmd.stdout + cmd.stderr
    end

    it "onegate resched vm" do
        cmd = @info[:vm].ssh("onegate vm resched #{@info[:vm_id2]}")
        expect(cmd.success?).to be(true), "onegate resched doesn't work\n" + cmd.stdout + cmd.stderr

        # wait until reschedule action is completed
        wait_loop do
            @info[:vm2].xml['RESCHED'] == '0'
        end

        @info[:vm2].running?
    end

    it "onegate stop vm" do
        cmd = @info[:vm].ssh("onegate vm stop #{@info[:vm_id2]} --json")
        @info[:vm2].state?('STOPPED')
    end

    it "onegate resume vm" do
        cmd = @info[:vm].ssh( "onegate vm resume #{@info[:vm_id2]}", true)

        expect(cmd.success?).to be(true), "onegate vm resume doesn't work\n" + cmd.stdout + cmd.stderr
        @info[:vm2].running?
    end

    it "onegate suspend vm" do
        @info[:vm2].running?
        cmd = @info[:vm].ssh("onegate vm suspend #{@info[:vm_id2]} --json")
        @info[:vm2].state?('SUSPENDED')
    end

    it "onegate resume vm" do
        cmd = @info[:vm].ssh("onegate vm resume #{@info[:vm_id2]}")
        @info[:vm2].running?
    end

    it "onegate poweroff vm" do
        cmd = @info[:vm].ssh("onegate vm poweroff #{@info[:vm_id2]}")
        @info[:vm2].stopped?
    end

    it "onegate terminate vm" do
        cmd = @info[:vm].ssh("onegate vm terminate #{@info[:vm_id2]}")
        @info[:vm2].done?
    end

    after(:all) do
        cli_action("oneflow delete '#{@service_id}'")
    end
end
