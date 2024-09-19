require 'init'

# Test host monitoring

# Description:
# - Verify that host monitoring is initialized in a timely fashion

#
# functions
#

def verify_onehosts_readiness(hosts)
    result = true

    # iterate over hosts and check their status
    hosts.each do |host|
        host_status = cli_action_xml("onehost show -x #{host[:name]}")
        state = host_status["/HOST/STATE"].to_i

        if state != 2
            result = false
            break
        end
    end

    result
end

#
# shared examples
#

shared_examples_for "host_monitor_test_init" do
    it "removing all hosts" do
        @info[:monitoring_hosts].each do |host|
            cmd = cli_action("onehost delete #{host[:name]}")
            expect(cmd.success?).to be(true), "Host '#{host[:name]}' could not be removed!\n" + cmd.stdout + cmd.stderr
        end
    end

    it "waiting and cleanup ssh connections" do
        sleep 10
        cmd = cli_action("pkill -u oneadmin -f 'ssh.*/run/one/ssh-socks/ctl-M-[^[:space:]]*[.]sock' || true")
        expect(cmd.success?).to be(true), "Failed to kill ssh master sockets!"
    end

    it "adding all hosts back" do
        @info[:monitoring_hosts].each do |host|
            cmd = cli_action("onehost create #{host[:name]} -i #{host[:im_mad]} -v #{host[:vm_mad]}")
            expect(cmd.success?).to be(true), "Host '#{host[:name]}' could not be added!\n" + cmd.stdout + cmd.stderr
        end
    end

    it "verifying that all hosts are re-initialized and ready" do
        wait_loop(:timeout => 30) do
            verify_onehosts_readiness(@info[:monitoring_hosts])
        end
    end
end

#
# Test is started here
#

RSpec.describe "Test examples for host monitoring to" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}
    end

    after(:all) do
        # bring all hosts up
        @info[:monitoring_hosts].each do |host|
            onehost_list = cli_action_xml("onehost list -x")
            found = false
            onehost_list.each("/HOST_POOL/HOST[CLUSTER_ID='#{@info[:cluster_id]}']") do |current_host|
                if current_host['NAME'] == host[:name]
                    found = true
                    break
                end
            end

            if !found
                cmd = cli_action("onehost create #{host[:name]} -i #{host[:im_mad]} -v #{host[:vm_mad]}")
                expect(cmd.success?).to be(true), "Host '#{host[:name]}' could not be added!\n" + cmd.stdout + cmd.stderr
            end
        end

        # wait for all hosts to be ready
        wait_loop do
            verify_onehosts_readiness(@info[:monitoring_hosts])
        end
    end

    #
    # Test for host monitoring initialization
    #
    context "validate initialization by" do

        it "deleting all remaining VMs" do
            # cleanup leftovers from previous tests

            # wait for all VMs to be removed...
            wait_loop do
                cmd = cli_action('onevm list -l ID --no-header', nil)
                vm_list = cmd.stdout.split

                if vm_list.length > 0
                    vm_list.each do |id|
                        _ = cli_action("onevm terminate --hard #{id}", nil)
                    end
                    sleep 1
                    false
                else
                    true
                end
            end
        end

        it "getting the hosts info" do
            # make the list of hosts and their drivers (hypervisors)

            @info[:monitoring_hosts] = []

            # pick one cluster
            cluster_list = cli_action_xml("onecluster list -x")
            @info[:cluster_id] = cluster_list["/CLUSTER_POOL/CLUSTER[last()]/ID"]

            # iterate over hosts in this one cluster
            onehost_list = cli_action_xml("onehost list -x")
            onehost_list.each("/HOST_POOL/HOST[CLUSTER_ID='#{@info[:cluster_id]}']") do |host|
                # gather relevant info
                new_host = {}
                new_host[:name] = host['NAME']
                new_host[:state] = host['STATE'].to_i
                new_host[:im_mad] = host['IM_MAD']
                new_host[:vm_mad] = host['VM_MAD']

                # store the new found host for further tests
                @info[:monitoring_hosts] << new_host
            end
        end

        # run few iterations of the verification tests...
        for i in 1..5
            context "running #{i}. test iteration:" do
                include_examples "host_monitor_test_init"
            end
        end
    end
end
