require 'tempfile'

require_relative 'windows/basic'
require_relative 'windows/grow_fs'
require_relative 'windows/ip_method'
require_relative 'windows/network'

WINRM_PSWD='opennebula'

shared_examples_for 'context_windows' do |image, hv, prefix, context|
    include_examples 'context', image, hv, prefix, context

    it 'pings' do
        @info[:vm].wait_ping
    end

    it 'has SSH access' do
        @info[:vm].reachable?('oneadmin')
    end
end

shared_examples_for 'windows' do |name, hv|
    tests = RSpec.configuration.defaults[:tests]

    it 'prepare files (required)' do
        # files to create
        files = {
            'win-fail.bat'   => 'exit 1',
            'win-touch2.ps1' => 'New-Item -Path C:\ -Name "touch2.txt" -ItemType "file" -Value "ok"',
            'win-touch1.bat' => <<~EOT
                echo dummy
                sleep 1
                echo ok >>C:\\touch1.txt
            EOT
        }

        files.each do |name, content|
            next if cli_action("oneimage show '#{name}' >/dev/null", nil).success?

            Tempfile.open('rspec', '/var/tmp') do |tmp|
                tmp.write(content)
                tmp.close

                # create and wait until ready
                cli_create('oneimage create -d files --type CONTEXT' \
                           " --name '#{name}' --path '#{tmp.path}'")

                wait_loop(:success => /^(READY|USED)$/, :break => 'ERROR') do
                    xml = cli_action_xml("oneimage show -x '#{name}'")
                    Image::IMAGE_STATES[xml['STATE'].to_i]
                end
            end
        end
    end

    if tests[name][:enable_basic]
        1.upto(2).each do |n|
            context "bulk (#{n})" do
                include_examples "context_windows_basic#{n}", name, hv, 'hd'
            end
        end
    end

    if tests[name][:enable_growfs]
        context 'filesystem growing' do
            include_examples 'context_windows_grow_fs', name, hv, 'hd'
        end
    end

    if tests[name][:enable_netcfg_ip_methods]
        context 'IP configuration' do
            include_examples 'context_windows_ip_methods', name, hv, 'hd'
        end
    end
end
