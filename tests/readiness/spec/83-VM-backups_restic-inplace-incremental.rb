require 'init'
require_relative '../lib/image'
require_relative '../lib/backup_restic'
require_relative '../lib/VMTemplate'
require_relative 'lib/backups'

RSpec.describe 'VM Backups: Restic' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        xml = cli_action_xml('onehost list -x')
        id  = xml.retrieve_elements('//HOST/ID')[0].to_i

        @host = CLITester::Host.new(id)

        begin
            xml = cli_action_xml('onevm list -x')
            xml.retrieve_elements('//VM/ID').each {|i| cli_action("onevm terminate --hard #{i}") }
        rescue StandardError
        end
    end

    context 'Incremental backups' do
        before(:all) do
            skip 'libvirt version' unless @host.incremental_backups?
        end

        BackupTests.inplace_vms.each do |i|
            it_should_behave_like 'inplace restore', i, ResticDS, 'INCREMENT'
        end
    end
end
