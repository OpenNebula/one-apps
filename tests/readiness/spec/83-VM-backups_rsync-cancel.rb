require 'init'
require_relative '../lib/image'
require_relative '../lib/backup_rsync'
require_relative '../lib/VMTemplate'
require_relative './lib/backups'

RSpec.describe 'VM Backups: RSync - Cancel' do
    #################
    # rsync config #
    #################

    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        xml = cli_action_xml('onehost list -x')
        id  = xml.retrieve_elements('//HOST/ID')[0].to_i

        host = CLITester::Host.new(id)
        skip 'libvirt version' unless host.full_backups?

        begin
            xml = cli_action_xml('onevm list -x')
            xml.retrieve_elements('//VM/ID').each {|i| cli_action("onevm terminate --hard #{i}") }
        rescue StandardError
        end
    end

    it_should_behave_like 'backup cancel', RSyncDS
end
