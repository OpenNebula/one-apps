require 'init'

RSpec.describe "Security Groups" do

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Get the sg-1 Network ID
        vm_id = cli_create("onetemplate instantiate --hold '#{@defaults[:template_sg_1]}'")
        vm    = VM.new(vm_id)
        @info[:net_sg_1] = vm["TEMPLATE/NIC[2]/NETWORK_ID"]
        cli_action("onevm terminate --hard #{vm_id}")

        # Get the sg-2 Network ID
        vm_id = cli_create("onetemplate instantiate --hold '#{@defaults[:template_sg_2]}'")
        vm    = VM.new(vm_id)
        @info[:net_sg_2] = vm["TEMPLATE/NIC[2]/NETWORK_ID"]
        cli_action("onevm terminate --hard #{vm_id}")
    end

    it "create empty sg" do
        tpl = Tempfile.new("")
        tpl.puts "NAME=test-sg"
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
        @info[:vm1_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg_1]}'")
        @info[:vm1] = VM.new(@info[:vm1_id])

		@info[:vm1_ip] = @info[:vm1]["TEMPLATE/NIC[2]/IP"]

        @info[:vm1].running?
        @info[:vm1].reachable?
    end

    it "instantiate vm2 (sg-1) in same host as vm1" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS = #{@info[:vm1_id]}\"'"

        @info[:vm2_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg_1]}' #{reqs}")
        @info[:vm2] = VM.new(@info[:vm2_id])

		@info[:vm2_ip] = @info[:vm2]["TEMPLATE/NIC[2]/IP"]

        @info[:vm2].running?
        @info[:vm2].reachable?
    end

    it "instantiate vm3 (sg-1) in different host as vm1" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS != #{@info[:vm1_id]}\"'"

        @info[:vm3_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg_1]}' #{reqs}")
        @info[:vm3] = VM.new(@info[:vm3_id])

		@info[:vm3_ip] = @info[:vm3]["TEMPLATE/NIC[2]/IP"]

        @info[:vm3].running?
        @info[:vm3].reachable?
    end

    it 'starts test services on vm2 and vm3' do
        [@info[:vm2], @info[:vm3]].each do |vm|
            vm.reachable?
            vm.ssh('nc -lk -p 8000 -e echo ConnectOK >/dev/null 2>&1 &').expect_success
            vm.ssh('nc -lk -p 8001 -e echo ConnectOK >/dev/null 2>&1 &').expect_success
        end
    end

    ############################################################################
    # No connectivity VM2 and VM3 (empty SG)
    ############################################################################

    it "no connectivity vm1 -> vm2 and vm3" do
        [@info[:vm2_ip], @info[:vm3_ip]].each do |ip|
            @info[:vm1].ssh("ping -c1 -W5 #{ip}").expect{|c| c.fail?}
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
				     PROTOCOL="ICMP",
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
				     PROTOCOL="ICMP",
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
            @info[:vm1].ssh("ping -c1 -W5 #{ip}").expect_success

            cmd = @info[:vm1].ssh("nc -w 3 #{ip} 8000 </dev/null")
            cmd.expect_success
            expect(cmd.stdout.strip).to eq("ConnectOK")

            @info[:vm1].ssh("nc -w 3 #{ip} 8001 </dev/null").expect_fail
        end
    end

=begin

    # TODO!!!!!!!
    # ENABLE WHEN AUTOMATIC CONFIGURATION OF NICS IN GUEST IS AVAILABLE

    ############################################################################
    # Attach NIC while running
    ############################################################################

    it "detach nic 2 from vm2 while running" do
        last_nic_id = @info[:vm2].xml['TEMPLATE/NIC[last()]/NIC_ID']
        @info[:vm2_network_id] = @info[:vm2].xml['TEMPLATE/NIC[2]/NETWORK_ID']

        cli_action("onevm nic-detach #{@info[:vm2_id]} #{last_nic_id}")
        @info[:vm2].running?
    end

    it "attach nic to vm2 while running" do
        network_id = @info[:vm2].xml['TEMPLATE/NIC[2]/NETWORK_ID']
        cli_action("onevm nic-attach #{@info[:vm2_id]} --network #{@info[:vm2_network_id]}")
        @info[:vm2].running?

        @info[:vm2_ip_attach] = @info[:vm2]["TEMPLATE/NIC[last()]/IP"]
    end

    it "connectivity vm1 -> vm2 attached nic" do
        ip = @info[:vm2_ip_attach]

        @info[:vm1].ssh("ping -c1 -W5 #{ip}").expect_success
        @info[:vm1].ssh("curl --connect-timeout 3 --fail http://#{ip}:8000").expect_success
        @info[:vm1].ssh("curl --connect-timeout 3 --fail http://#{ip}:8001").expect_fail
    end
=end

    ############################################################################
    # Attach NIC while poff
    ############################################################################

    it "detach nic 2 from vm2 while running" do
        last_nic_id = @info[:vm2].xml['TEMPLATE/NIC[last()]/NIC_ID']
        @info[:vm2_network_id] = @info[:vm2].xml['TEMPLATE/NIC[2]/NETWORK_ID']

        cli_action("onevm nic-detach #{@info[:vm2_id]} #{last_nic_id}")
        @info[:vm2].running?
    end

    it "attach nic to vm2 while poff" do
        @info[:vm2].safe_poweroff

        network_id = @info[:vm2].xml['TEMPLATE/NIC[2]/NETWORK_ID']
        cli_action("onevm nic-attach #{@info[:vm2_id]} --network #{@info[:vm2_network_id]}")
        @info[:vm2].state?("POWEROFF")

        @info[:vm2_ip_attach] = @info[:vm2]["TEMPLATE/NIC[last()]/IP"]
    end

    it "start vm and launch servers" do
        cli_action("onevm resume #{@info[:vm2_id]}")

        @info[:vm2].running?
        @info[:vm2].reachable?

        @info[:vm2].ssh("nc -lk -p 8000 -e echo ConnectOK >/dev/null 2>&1 &")
        @info[:vm2].ssh("nc -lk -p 8001 -e echo ConnectOK >/dev/null 2>&1 &")
    end

    it "connectivity vm1 -> vm2 attached nic" do
        ip = @info[:vm2_ip_attach]

        @info[:vm1].ssh("ping -c1 -W5 #{ip}").expect_success

        cmd = @info[:vm1].ssh("nc -w 5 #{ip} 8000 </dev/null")
        cmd.expect_success
        expect(cmd.stdout.strip).to eq("ConnectOK")

        @info[:vm1].ssh("nc -w 5 #{ip} 8001 </dev/null").expect_fail
    end

    ############################################################################
    # Attach NIC ALIAS to VM2 while poff
    ############################################################################

    it "attach nic allias to vm2 while poff" do
        @info[:vm2].safe_poweroff

        network_id = @info[:vm2].xml['TEMPLATE/NIC[2]/NETWORK_ID']
        cli_action("onevm nic-attach #{@info[:vm2_id]}  " <<
                   "--network #{@info[:vm2_network_id]} " <<
                   "--alias NIC1")
        @info[:vm2].state?("POWEROFF")

        @info[:vm2_ip_alias] = @info[:vm2]["TEMPLATE/NIC[last()]/IP"]
    end

    it "start vm and launch servers" do
        cli_action("onevm resume #{@info[:vm2_id]}")

        @info[:vm2].running?
        @info[:vm2].reachable?

        @info[:vm2].ssh("nc -lk -p 8000 -e echo ConnectOK >/dev/null 2>&1 &")
        @info[:vm2].ssh("nc -lk -p 8001 -e echo ConnectOK >/dev/null 2>&1 &")
    end

    it "connectivity vm1 -> vm2 alias nic" do
        ip = @info[:vm2_ip_alias]

        @info[:vm1].ssh("ping -c1 -W5 #{ip}").expect_success

        cmd = @info[:vm1].ssh("nc -w 5 #{ip} 8000 </dev/null")
        cmd.expect_success
        expect(cmd.stdout.strip).to eq("ConnectOK")

        @info[:vm1].ssh("nc -w 5 #{ip} 8001 </dev/null").expect_fail
    end

    ############################################################################
    # Shutdown VM2 and VM3
    ############################################################################

    it "terminate vm1 and vm2" do
        cli_action("onevm terminate --hard #{@info[:vm1_id]}")
        @info[:vm1].done?

        cli_action("onevm terminate --hard #{@info[:vm2_id]}")
        @info[:vm2].done?
    end

    ############################################################################
    # Launch VMs
    ############################################################################

    it "instantiate vm4 (sg-2) in same host as vm3" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS = #{@info[:vm3_id]}\"'"

        @info[:vm4_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg_2]}' #{reqs}")
        @info[:vm4] = VM.new(@info[:vm4_id])

		@info[:vm4_ip] = @info[:vm4]["TEMPLATE/NIC[2]/IP"]

        @info[:vm4].running?
        @info[:vm4].reachable?
    end

    it "instantiate vm5 (sg-2) in different host as vm1" do
        reqs = "--raw 'SCHED_REQUIREMENTS = \"CURRENT_VMS != #{@info[:vm3_id]}\"'"

        @info[:vm5_id] = cli_create("onetemplate instantiate '#{@defaults[:template_sg_2]}' #{reqs}")
        @info[:vm5] = VM.new(@info[:vm5_id])

		@info[:vm5_ip] = @info[:vm5]["TEMPLATE/NIC[2]/IP"]

        @info[:vm5].running?
        @info[:vm5].reachable?
    end

	it "start servers vm4 and vm5" do
        [@info[:vm4], @info[:vm5]].each do |vm|
            vm.ssh("nc -lk -p 8000 -e echo ConnectOK >/dev/null 2>&1 &")
            vm.ssh("nc -lk -p 8001 -e echo ConnectOK >/dev/null 2>&1 &")
        end
	end

    ############################################################################
    # Connectivity VM4 and VM5 (deployed SG)
    ############################################################################

    it "connectivity vm4 and vm5 -> vm3" do
        [@info[:vm4], @info[:vm5]].each do |vm|
            vm.ssh("ping -c1 -W5 #{@info[:vm3_ip]}").expect_success
            vm.ssh("nc -w 5 #{@info[:vm3_ip]} 8000 </dev/null").expect_fail

            cmd = vm.ssh("nc -w 5 #{@info[:vm3_ip]} 8001 </dev/null")
            cmd.expect_success
            expect(cmd.stdout.strip).to eq("ConnectOK")
        end
    end

    ############################################################################
    # Shutdown VMs
    ############################################################################

    it "terminate vm3, vm4 and vm5" do
        cli_action("onevm terminate --hard #{@info[:vm3_id]}")
        @info[:vm3].done?

        cli_action("onevm terminate --hard #{@info[:vm4_id]}")
        @info[:vm4].done?

        cli_action("onevm terminate --hard #{@info[:vm5_id]}")
        @info[:vm5].done?
    end

    it "clean sec group" do
        cli_action("onesecgroup delete test-sg")

        tpl = Tempfile.new("")
        tpl.puts "SECURITY_GROUPS=\"0\""
        tpl.close

        cli_action("onevnet update #{@info[:net_sg_1]} -a #{tpl.path}")
        tpl.unlink
    end
end
