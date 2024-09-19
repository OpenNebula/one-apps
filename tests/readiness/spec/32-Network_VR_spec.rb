require 'init'

RSpec.describe "vRouter join networks" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        template1 = cli_action_xml("onetemplate show -x #{@defaults[:template_vr_isolated_1]}")
        template1_nets = template1.retrieve_elements('TEMPLATE/NIC/NETWORK')

        template2 = cli_action_xml("onetemplate show -x #{@defaults[:template_vr_isolated_2]}")
        template2_nets = template2.retrieve_elements('TEMPLATE/NIC/NETWORK')

        net_public    = template1_nets.first
        net_iso1_name = template1_nets.last
        net_iso2_name = template2_nets.last

        net_iso1 = cli_action_xml("onevnet show -x #{net_iso1_name}")
        net_iso2 = cli_action_xml("onevnet show -x #{net_iso2_name}")

        net_iso1_ip = net_iso1['AR_POOL/AR/IP']
        net_iso2_ip = net_iso2['AR_POOL/AR/IP']

        vr_name = "vr-#{$$}"
        vr_template = <<-EOF
            NAME=#{vr_name}

            NIC = [
                VROUTER_MANAGEMENT = "YES",
                NETWORK = "#{net_public}"
            ]
            NIC = [
                IP = "#{net_iso1_ip}",
                NETWORK = "#{net_iso1_name}"
            ]
            NIC = [
                IP = "#{net_iso2_ip}",
                NETWORK = "#{net_iso2_name}"
            ]
        EOF

        vr_id = cli_create("onevrouter create", vr_template)
        cli_action("onevrouter instantiate '#{vr_name}' '#{@defaults[:template_vr]}'")

        vr_xml = cli_action_xml("onevrouter show -x #{vr_id}")

        vm1 = cli_create("onetemplate instantiate '#{@defaults[:template_vr_isolated_1]}'")
        vm2 = cli_create("onetemplate instantiate '#{@defaults[:template_vr_isolated_2]}'")

        vr = vr_xml.retrieve_elements('VMS').map {|e| e.strip.to_i}.first

        @info[:vr_id] = vr_id
        @info[:vr]    = VM.new(vr)
        @info[:vm1]   = VM.new(vm1)
        @info[:vm2]   = VM.new(vm2)
    end

    it "deploys" do
        @info[:vr].running?
        @info[:vm1].running?
        @info[:vm2].running?
    end

    it "ssh and context" do
        @info[:vr].reachable?
        @info[:vm1].reachable?
        @info[:vm2].reachable?
    end

    it "install routes" do
        vr_ip_iso1 = @info[:vr]['TEMPLATE/NIC[2]/IP']
        vr_ip_iso2 = @info[:vr]['TEMPLATE/NIC[3]/IP']

        vr_net_iso1 = vr_ip_iso1.gsub(/\d+$/,"0/24")
        vr_net_iso2 = vr_ip_iso2.gsub(/\d+$/,"0/24")

        @info[:vm1].ssh("PATH=#{DEFAULT_PATH} ip r add #{vr_net_iso2} via #{vr_ip_iso1}").expect_success
        @info[:vm2].ssh("PATH=#{DEFAULT_PATH} ip r add #{vr_net_iso1} via #{vr_ip_iso2}").expect_success
    end

    it "ping vm1 -> vm2" do
        vm2_ip = @info[:vm2].get_vlan_ip
        @info[:vm1].ssh("ping -c1 -W1 #{vm2_ip}").expect_success
    end

    it "terminate vms" do
        cli_action("onevrouter delete #{@info[:vr_id]}")
        @info[:vr].done?

        cli_action("onevm terminate --hard #{@info[:vm1]['ID']}")
        @info[:vm1].done?

        cli_action("onevm terminate --hard #{@info[:vm2]['ID']}")
        @info[:vm2].done?
    end
end
