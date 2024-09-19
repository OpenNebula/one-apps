require 'init'

# Test the hotplug resize operation

# Description:
# - VM is deployed
# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Hotplug Resize " do
    before(:all) do
        host = `hostname`
        if host.match('centos7|rhel7|ubuntu16') && !host.match('-ev-')
            @skip = true
            skip 'Hotplug not supported, old QEMU version'
        else
            @skip = false
        end

        @defaults = RSpec.configuration.defaults

        # Use the same VM for all the tests in this example
        @tmpl_id = cli_create("onetemplate clone '#{@defaults[:template]}' '#{@defaults[:template]}_resize'")

        tmpl = <<-EOF
            VCPU=1
            VCPU_MAX=4
            MEMORY=128
            MEMORY_MAX=512
        EOF

        cli_update("onetemplate update #{@tmpl_id}", tmpl, true)

        @vm_id = cli_create("onetemplate instantiate --hold #{@tmpl_id}")
        @vm    = VM.new(@vm_id)
    end

    after(:all) do
        unless @skip
            @vm.terminate_hard
            cli_action("onetemplate delete #{@tmpl_id}")
        end
    end

    it "update vcpu, mem and deploy" do
        cli_action("onevm release #{@vm_id}")
        @vm.running?

        vm_xml = @vm.info

        expect(vm_xml["TEMPLATE/VCPU"]).to eql("1")
        expect(vm_xml["TEMPLATE/MEMORY"]).to eql("128")
    end

    it "resize" do
        cli_action("onevm resize #{@vm_id} --vcpu 2  --memory 256")
        @vm.running?

        vm_xml = @vm.info

        expect(vm_xml["TEMPLATE/VCPU"]).to eql("2")
        expect(vm_xml["TEMPLATE/MEMORY"]).to eql("256")
    end
end
