require 'init'

RSpec.describe 'Nic Alias attach/detach tests' do
    before(:all) do
        @info = {}
        @defaults = RSpec.configuration.defaults
        @info[:alias_tmpl] = cli_create("onetemplate clone '#{@defaults[:template]}' \
                                        '#{@defaults[:template]}_alias'")

        tmpl = <<-EOF
            NIC_ALIAS = [
                NETWORK = "public",
                PARENT  = "NIC0",
                FILTER_IP_SPOOFING = "YES",
                FILTER_MAC_SPOOFING = "YES"
            ]
        EOF

        cli_update("onetemplate update #{@info[:alias_tmpl]}", tmpl, true)
    end

    after(:all) do
        @info[:vm].terminate_hard
        @info[:vm].done?

        cli_action("onetemplate delete #{@info[:alias_tmpl]}")
    end

    def alias_ip(vm)
        vm.info
        @info[:vm].xml['TEMPLATE/NIC_ALIAS/IP']
    end

    ############################################################################
    # TESTS
    ############################################################################

    it 'should create a VM with a NIC alias' do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@info[:alias_tmpl]}")

        @info[:vm] = VM.new(@info[:vm_id])

        @info[:vm].running?
        @info[:vm].wait_ping

        @info[:vm].wait_ping(alias_ip(@info[:vm]))
    end

    it 'should remove the alias and keep connectivity' do
        cli_action("onevm nic-detach #{@info[:vm_id]} 1")

        @info[:vm].running?
        @info[:vm].wait_ping
    end

    it 'should keep connectivity in a attach/detach cycle' do
        file = Tempfile.new('nic_alias')

        tmpl = <<-EOF
            NIC_ALIAS = [
                NETWORK = "public",
                PARENT  = "NIC0",
                FILTER_IP_SPOOFING = "YES",
                FILTER_MAC_SPOOFING = "YES"
            ]
        EOF

        file.write(tmpl)

        file.close

        cli_action("onevm nic-attach #{@info[:vm_id]} --file #{file.path}")

        @info[:vm].running?

        @info[:vm].wait_ping
        @info[:vm].wait_ping(alias_ip(@info[:vm]))

        cli_action("onevm nic-detach #{@info[:vm_id]} 1")

        @info[:vm].running?
        @info[:vm].wait_ping
    end
end
