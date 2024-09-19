require 'init'

def host_ssh(vm, cmd)
    cmd = "ssh #{vm.hostname} \"PATH=\\$PATH:/sbin:/usr/sbin #{cmd}\""

    SafeExec.run(cmd)
end

RSpec.describe "Bridge networking" do

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {
            :vnet_name => "test-bridge-vnet",
            :br_name   => "test-bridge",
            :phydev    => "test-phydev"
        }

        # create "fake" phydev in the hosts
        @defaults[:hosts].each do |host|
            `ssh #{host} "sudo ip tuntap add #{@info[:phydev]} mode tap"`
        end

        # create vnet
        template=<<-EOF
         NAME   = "#{@info[:vnet_name]}"
         BRIDGE = "#{@info[:br_name]}"
         VN_MAD = bridge
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
         PHYDEV = "#{@info[:phydev]}"
        EOF

        @info[:vnet_id] = cli_create("onevnet create", template)
    end

    after(:all) do
         # create "fake" phydev in the hosts
         @defaults[:hosts].each do |host|
            `ssh #{host} "sudo ip tuntap del #{@info[:phydev]} mode tap"`
        end

        cli_action("onevnet delete #{@info[:vnet_id]}")
    end

    it "bridge and phydev are configure when a VM is deployed in the node" do
        # Deploy VM
        @info[:vm_id] = cli_create("onetemplate instantiate #{@defaults[:template]} --nic #{@info[:vnet_id]}")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:vm].running?

        # Check that the bridge have been created
        rc = host_ssh(@info[:vm], "ip link show master #{@info[:br_name]}")
        rc.expect_success

        # Check phydev have been attached to the bridge
        expect(rc.stdout).to match(/.*#{@info[:phydev]}:.*/)
    end

    it "bridge is not cleanned when there are more VMs in the node" do
        # Deploy another VM
        vm_id = cli_create("onetemplate instantiate #{@defaults[:template]} --nic #{@info[:vnet_id]} --hold")
        cli_action("onevm deploy #{vm_id} #{@info[:vm].host_id}")

        vm = VM.new(vm_id)
        vm.running?

        # Terminate the new VM
        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?

        # Check that the bridge is still there
        rc = host_ssh(@info[:vm], "ip link show master #{@info[:br_name]}")
        rc.expect_success

        # Check phydev is still there
        expect(rc.stdout).to match(/.*#{@info[:phydev]}:.*/)
    end

    it "bridge is cleanned when there are no more VMs in the node" do
        # Deploy VM
        cli_action("onevm terminate --hard #{@info[:vm_id]}")

        @info[:vm].done?

        # Check that the bridge have been created
        rc = host_ssh(@info[:vm], "ip link show master #{@info[:br_name]}")
        rc.expect_fail
    end
end
