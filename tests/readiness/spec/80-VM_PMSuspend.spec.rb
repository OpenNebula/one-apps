require 'init'

# Tests VM snapshot and revert

# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe 'VM PM Suspend' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        tmpl = <<-EOF
        RAW = [
            DATA = "<pm>
  <suspend-to-disk enabled='yes'/>
  <suspend-to-mem enabled='yes'/>
</pm>",
            TYPE = "kvm",
            VALIDATE = "NO" ]
        FEATURES = [
            ACPI = "yes",
            APIC = "yes",
            GUEST_AGENT = "yes",
            PAE = "yes" ]
        EOF

        cli_update('onetemplate update -a '\
                    "'#{@defaults[:template_pm]}'", tmpl, true)

        @info[:vm_id]   = cli_create('onetemplate instantiate '\
                                        "'#{@defaults[:template_pm]}'")
        @info[:vm]      = VM.new(@info[:vm_id])
    end

    it 'deploys and can be reached' do
        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm_host] = Host.new(@info[:vm].host_id)
    end

    it 'suspend to memory using dompmsuspend' do
        ret = @info[:vm_host].ssh(
            "virsh --connect qemu:///system dompmsuspend one-#{@info[:vm_id]} mem",
            true, {}, 'oneadmin')

        ret.expect_success

        @info[:vm].state?('SUSPENDED')
    end

    it 'resumes the vm with remote resume script' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end
end

