#!/usr/bin/ruby

require 'init'
require 'tempfile'

RSpec.describe 'Operations with volatile disks' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'deploys' do
        cmd = "onetemplate instantiate #{@defaults[:template]}"

        @info[:vm] = VM.new(cli_create(cmd))
        @info[:vm].running?

        @info[:vm].poweroff
    end

    it 'deploys with volatile disks' do
        %w[fs swap].each do |disk|
            attach_volatile(disk, 'raw')
            @info[:vm].stopped?
        end

        @info[:vm].resume
        # TODO, check disk attached
    end

    it 'hotplugs volatile fs' do
        skip "Hotplug not supported for LXC yet"

        attach_volatile('fs', 'qcow2')
        @info[:vm].running?

        expect(1).to eq(2) # TODO, check disk attached after implementing
    end

    it 'deletes VM' do
        @info[:vm].terminate
    end

    def attach_volatile(type, driver, success = true)
        xml = { :disk => { :size => 100, :type => type, :driver => driver, :fs => 'ext4' } }
        xml = TemplateParser.template_like_str(xml)

        file = Tempfile.new('file')
        file.write(xml)
        file.close

        cmd = "onevm disk-attach #{@info[:vm].id} --file #{file.path}"
        cli_action(cmd, success)

        file.unlink
    end
end
