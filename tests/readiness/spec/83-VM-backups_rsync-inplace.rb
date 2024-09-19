require 'init'
require_relative '../lib/image'
require_relative '../lib/backup_rsync'
require_relative '../lib/VMTemplate'
require_relative 'lib/backups'

RSpec.describe 'VM Backups: RSync' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        xml = cli_action_xml('onehost list -x')
        id  = xml.retrieve_elements('//HOST/ID')[0].to_i

        @host = CLITester::Host.new(id)

        # Destroy all wild VMs
        system(<<~EOF)
            onehost list --no-header --csv | awk -F, '{print $2}' | xargs -I{} ssh {} 'export LIBVIRT_DEFAULT_URI=qemu:///system; virsh list --name | xargs -rn1 virsh destroy'
        EOF

        begin
            xml = cli_action_xml('onevm list -x')
            xml.retrieve_elements('//VM/ID').each {|i| cli_action("onevm terminate --hard #{i}") }
        rescue StandardError
        end
    end

    context 'Full backups' do
        before(:all) do
            skip 'libvirt version' unless @host.full_backups?
        end

        BackupTests.inplace_vms.each do |i|
            it_should_behave_like 'inplace restore', i, RSyncDS, 'FULL'
        end
    end
end
