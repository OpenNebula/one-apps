require 'init'

RSpec.describe "Security Groups IPv6" do

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Get the sg-1 Network ID
        vm_id = cli_create("onetemplate instantiate --hold '#{@defaults[:template_sg6_1]}'")
        vm    = VM.new(vm_id)
        @info[:net_sg_1] = vm["TEMPLATE/NIC[2]/NETWORK_ID"]
        cli_action("onevm terminate --hard #{vm_id}")

        # Get the sg-2 Network ID
        vm_id = cli_create("onetemplate instantiate --hold '#{@defaults[:template_sg6_2]}'")
        vm    = VM.new(vm_id)
        @info[:net_sg_2] = vm["TEMPLATE/NIC[2]/NETWORK_ID"]
        cli_action("onevm terminate --hard #{vm_id}")
    end

    it "create empty sg" do
        tpl = Tempfile.new("")
        tpl.puts "NAME=test-sg6"
        tpl.close

        @info[:test_sg] = cli_create("onesecgroup create #{tpl.path}")
        tpl.unlink
    end

    it "update private net to use new sg" do
        tpl = Tempfile.new("")
        tpl.puts "SECURITY_GROUPS=\"#{@info[:test_sg]}\""
        tpl.close

        cli_action("onevnet update #{@info[:net_sg_1]} -a #{tpl.path}")
        tpl.unlink
    end

    ############################################################################
    # Launch VMs
    ############################################################################

    it "instantiate vm1" do
        @info[:vm1_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg6_1]}'")
        @info[:vm1] = VM.new(@info[:vm1_id])

		@info[:vm1_ip] = @info[:vm1]["TEMPLATE/NIC[2]/IP6_GLOBAL"]

        @info[:vm1].running?
        @info[:vm1].reachable?
    end

    it "instantiate vm2 (sg-1) in same host as vm1" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS = #{@info[:vm1_id]}\"'"

        @info[:vm2_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg6_1]}' #{reqs}")
        @info[:vm2] = VM.new(@info[:vm2_id])

		@info[:vm2_ip] = @info[:vm2]["TEMPLATE/NIC[2]/IP6_GLOBAL"]

        @info[:vm2].running?
        @info[:vm2].reachable?
    end

    it "instantiate vm3 (sg-1) in different host as vm1" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS != #{@info[:vm1_id]}\"'"

        @info[:vm3_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg6_1]}' #{reqs}")
        @info[:vm3] = VM.new(@info[:vm3_id])

		@info[:vm3_ip] = @info[:vm3]["TEMPLATE/NIC[2]/IP6_GLOBAL"]

        @info[:vm3].running?
        @info[:vm3].reachable?
    end

	it "start servers vm2 and vm3" do
        [@info[:vm2], @info[:vm3]].each do |vm|
            vm.ssh("nc -lk -p 8000 -e echo ConnectOK >/dev/null 2>&1 &").expect_success
            vm.ssh("nc -lk -p 8001 -e echo ConnectOK >/dev/null 2>&1 &").expect_success
        end
	end

    ############################################################################
    # No connectivity VM2 and VM3 (empty SG)
    ############################################################################

    it "no connectivity vm1 -> vm2 and vm3" do
        [@info[:vm2_ip], @info[:vm3_ip]].each do |ip|
            @info[:vm1].ssh("ping6 -c1 -W5 #{ip}").expect{|c| c.fail?}
            @info[:vm1].ssh("nc -w 5 #{ip} 8000 </dev/null").expect_fail
        end
    end

    ############################################################################
    # Update SG
    ############################################################################

    it "add rules to sg" do
		# * tcp/any outbound => OK
		# * icmp outbound => OK
		# * icmp inbound => OK
		# * tcp/22 is allowed from anywhere => OK
		#
		# * tcp/8000 is only allowed from sg_1 => OK
		# * tcp/8001 is only allowed from sg_2 => NOT OK

		rules = %Q{DESCRIPTION=""
				   RULE=[
				     PROTOCOL="TCP",
				     RULE_TYPE="outbound" ]
				   RULE=[
				     PROTOCOL="ICMPV6",
				     RULE_TYPE="outbound" ]
				   RULE=[
				     PROTOCOL="TCP",
				     RANGE="22",
				     RULE_TYPE="inbound" ]
				   RULE=[
				     NETWORK_ID="#{@info[:net_sg_1]}",
				     PROTOCOL="TCP",
				     RANGE="8000",
				     RULE_TYPE="inbound" ]
				   RULE=[
				     NETWORK_ID="#{@info[:net_sg_2]}",
				     PROTOCOL="TCP",
				     RANGE="8001",
				     RULE_TYPE="inbound" ]
				   RULE=[
				     PROTOCOL="ICMPV6",
				     RULE_TYPE="inbound" ]}

        tpl = Tempfile.new("")
        tpl.puts rules
        tpl.close

		cli_action("onesecgroup update #{@info[:test_sg]} #{tpl.path}")
        tpl.unlink

        wait_loop {
			sg = cli_action_xml("onesecgroup show -x #{@info[:test_sg]}")
			sg["OUTDATED_VMS"].empty?
        }
    end

    ############################################################################
    # Connectivity (deployed SG)
    ############################################################################

    it "connectivity vm1 -> vm2 and vm3" do
        [@info[:vm2_ip], @info[:vm3_ip]].each do |ip|
            @info[:vm1].ssh("ping6 -c1 -W5 #{ip}").expect_success

            cmd = @info[:vm1].ssh("nc -w 3 #{ip} 8000 </dev/null")
            cmd.expect_success
            expect(cmd.stdout.strip).to eq("ConnectOK")

            @info[:vm1].ssh("nc -w 3 #{ip} 8001").expect_fail
        end
    end

    ############################################################################
    # Shutdown VM2 and VM3
    ############################################################################

    it "terminate vm1, vm2 and vm3" do
        cli_action("onevm terminate --hard #{@info[:vm1_id]}")
        @info[:vm1].done?

        cli_action("onevm terminate --hard #{@info[:vm2_id]}")
        @info[:vm2].done?

        cli_action("onevm terminate --hard #{@info[:vm3_id]}")
        @info[:vm3].done?
    end

    it "clean sec group" do
        cli_action("onesecgroup delete test-sg6")

        tpl = Tempfile.new("")
        tpl.puts "SECURITY_GROUPS=\"0\""
        tpl.close

        cli_action("onevnet update #{@info[:net_sg_1]} -a #{tpl.path}")
        tpl.unlink
    end
end
