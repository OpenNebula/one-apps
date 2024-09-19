require 'init'
require_relative '../lib/image'
require_relative '../lib/backup_restic'
require_relative '../lib/VMTemplate'
require_relative './lib/backups'

RSpec.describe 'VM Backups: Restic - Incremental backups' do
    before(:all) do
        skip 'libvirt bug https://gitlab.com/libvirt/libvirt/-/issues/622' \
            if `hostname`.match('debian12')

        @defaults = RSpec.configuration.defaults
        @info = {}

        # TODO: Ideally validate the images on the VM Templae not the image 0 in the image_pool
        base_image = CLIImage.new(0)
        skip 'image 0 is not qcow2 format' if base_image.format != 'qcow2'

        xml = cli_action_xml('onehost list -x')
        id  = xml.retrieve_elements('//HOST/ID')[0].to_i

        host = CLITester::Host.new(id)
        skip 'libvirt version' unless host.incremental_backups?

        begin
            xml = cli_action_xml('onevm list -x')
            xml.retrieve_elements('//VM/ID').each {|i| cli_action("onevm terminate --hard #{i}") }
        rescue StandardError
        end
    end

    BackupTests.incremental_vms.each do |i|
        it_should_behave_like 'incremental backups', i, ResticDS, 'CBT'

        it_should_behave_like 'incremental backups', i, ResticDS, 'SNAPSHOT'
    end
end
