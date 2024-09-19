require 'init'

RSpec.describe "VLAN connectivity same VLAN" do

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_1]}'")

        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    ############################################################################
    # Launch Second and Third VM same vlan ID
    ############################################################################

    it "launch a second vm on same host" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS = #{@info[:vm_id]}\"'"

        @info[:vm2_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_1]}' #{reqs}")
        @info[:vm2] = VM.new(@info[:vm2_id])

        @info[:vm2].running?
        @info[:vm2].reachable?
    end

    it "launch a third vm on a different host" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS != #{@info[:vm2_id]}\"'"

        @info[:vm3_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_1]}' #{reqs}")
        @info[:vm3]  = VM.new(@info[:vm3_id])

        @info[:vm3].running?
        @info[:vm3].reachable?
    end

    it "ping vm1 -> vm2" do
        vm2_ip = @info[:vm2].get_vlan_ip
        expect(@info[:vm].ssh("ping -c1 -W1 #{vm2_ip}").success?).to be(true)

        @defaults[:mtus].each do |packetsize|
            cmd = @info[:vm].ssh("ping -s #{packetsize} -c1 -W1 #{vm2_ip}")
            expect(cmd.success?).to be(true)
        end
    end

    it "ping vm1 -> vm3" do
        vm3_ip = @info[:vm3].get_vlan_ip
        @info[:vm].ssh("ping -c1 -W1 #{vm3_ip}")

        @defaults[:mtus].each do |packetsize|
            cmd = @info[:vm].ssh("ping -s #{packetsize} -c1 -W1 #{vm3_ip}")
            expect(cmd.success?).to be(true)
        end
    end

    it "terminate vms" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        cli_action("onevm terminate --hard #{@info[:vm2_id]}")
        @info[:vm2].done?

        cli_action("onevm terminate --hard #{@info[:vm3_id]}")
        @info[:vm3].done?
    end
end

RSpec.describe "VLAN connectivity different VLAN" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_1]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    ############################################################################
    # Launch Second and Third VM a different VLAN
    ############################################################################

    it "launch a second vm on same host" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS = #{@info[:vm_id]}\"'"

        @info[:vm2_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_2]}' #{reqs}")
        @info[:vm2] = VM.new(@info[:vm2_id])

        @info[:vm2].running?
        @info[:vm2].reachable?
    end

    it "launch a third vm on a different host" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS != #{@info[:vm2_id]}\"'"

        @info[:vm3_id] = cli_create("onetemplate instantiate '#{@defaults[:template_isolated_2]}' #{reqs}")
        @info[:vm3]  = VM.new(@info[:vm3_id])

        @info[:vm3].running?
        @info[:vm3].reachable?
    end

    it "no ping vm1 -> vm2" do
        vm2_ip = @info[:vm2].get_vlan_ip
        cmd = @info[:vm].ssh("ping -c1 -W1 #{vm2_ip}")
        expect(cmd.success?).to be(false)
    end

    it "no ping vm1 -> vm3" do
        vm3_ip = @info[:vm3].get_vlan_ip
        cmd = @info[:vm].ssh("ping -c1 -W1 #{vm3_ip}")
        expect(cmd.success?).to be(false)
    end

    it "terminate vms" do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        cli_action("onevm terminate --hard #{@info[:vm2_id]}")
        @info[:vm2].done?

        cli_action("onevm terminate --hard #{@info[:vm3_id]}")
        @info[:vm3].done?
    end
end
