#!/usr/bin/ruby

require 'init'

RSpec.describe 'fog-opennebula gem integration testing' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        # TODO: Move to defaults.yaml
        @info[:gem] = {
            :name     => 'fog-opennebula',
            :repo     => 'https://github.com/fog/fog-opennebula',
            :branch   => 'master', # TODO: Change to test branch
            :buildir  => '/tmp' # TODO: Install gem and deps to custom dir
        }
    end

    it 'removes installed fog gem if needed' do
        gem = @info[:gem]
        cmd = "gem list -i #{gem[:name]} || gem uninstall #{gem[:name]}"

        expect(SafeExec.run(cmd).success?).to be(true)
    end

    # On debian git and zlib are missing and the gem fails to be built.
    it 'builds and installs fog gem' do
        gem = @info[:gem]
        cmds = ''

        # Download
        cmds << "cd #{gem[:buildir]} && "
        cmds << "git clone https://github.com/fog/#{gem[:name]}.git && "

        # Build
        cmds << "cd #{gem[:name]} && git checkout #{gem[:branch]} && "
        cmds << "gem build #{gem[:name]}.gemspec && "
        cmds << "gem install --user #{gem[:name]} && "

        # Clean
        cmds << "cd #{gem[:buildir]} && "
        cmds << "rm -r #{gem[:name]}"

        expect(SafeExec.run(cmds).success?).to be(true)
    end
end
