require 'init'

RSpec.shared_examples_for "LXD-Scalability" do |defaults|
    it "Deploy VMs" do
        for i in 1..defaults[:vms_per_chunk]
            vm_id = cli_create("onetemplate instantiate #{defaults[:template]}")
            #puts "Created VM #{i} from #{info[:vms_per_chunk]}"
        end
        vm = VM.new(vm_id)
        vm.state?("RUNNING")
    end

    it "Run probes on containers" do
        time1=Time.now
        `/var/lib/one/remotes/im/run_probes #{defaults[:hypervisor]}`
        puts "Monitoring #{defaults[:current_chunk]*defaults[:vms_per_chunk]} VMs  took #{Time.now - time1} seconds"
        defaults[:current_chunk] = defaults[:current_chunk] + 1
    end
end

RSpec.describe "Scalability tests" do
    @defaults = RSpec.configuration.defaults
    for i in 1..@defaults[:chunks] do
        include_examples "LXD-Scalability", @defaults
    end
end


