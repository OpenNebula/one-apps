require 'init'

RSpec.describe 'Upgraded host' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        hostname = `hostname`
        if match = hostname.match(/.*-upgrade-v([0-9]+)-(?:onecfg-)?([0-9]+)-([0-9]+).*/)
            from, to_maj, to_min = match.captures
            if from == to_maj + to_min
                @info[:minor_upgrade] = true
            end
        end

    end
    it 'has opennebula in package logs' do
        # Centos7/RedHat7
        if File.file?('/var/log/yum.log')
            @info[:os_family] = 'centos7'
            expect(File.open('/var/log/yum.log')
                   .grep(/Installed: opennebula-common/)).not_to be_empty
            expect(File.open('/var/log/yum.log')
                   .grep(/Updated: opennebula-common/)).not_to be_empty

        # Centos8/RedHat8
        elsif File.file?('/var/log/dnf.log')
            @info[:os_family] = 'centos8'
            cmd = SafeExec.run('sudo dnf history info opennebula-common '\
                               '| grep "Install[[:space:]]*opennebula"')
            expect(cmd.success?).to be(true)
            cmd = SafeExec.run('sudo dnf history info opennebula '\
                               '| grep "Upgraded[[:space:]]*opennebula"')
            expect(cmd.success?).to be(true)

        # Debian/Ubuntu
        elsif File.file?('/var/log/apt/history.log')
            @info[:os_family] = 'debian'
            expect(File.open('/var/log/apt/history.log')
                   .grep(/Install: .* opennebula:/)).not_to be_empty
            expect(File.open('/var/log/apt/history.log')
                   .grep(/Upgrade: .* opennebula:/)).not_to be_empty
        else
            raise 'yum or apt log file not found'
        end
    end

    it 'has all opennebula packages on same version' do
        if @info[:os_family] =~ /centos/
            cmd = SafeExec.run('rpm -qa | grep opennebula- | grep -v rubygem ' \
                         "| egrep -o '[0-9].*-[0-9]' | uniq")
            expect(cmd.stdout.split("\n").length).to eq(1)

        # Debian/Ubuntu
        elsif @info[:os_family] == 'debian'
            cmd = SafeExec.run('dpkg -l | grep opennebula- | grep -v rubygem ' \
                               "| egrep -o '[0-9].*-[0-9]' | uniq")
            expect(cmd.stdout.split("\n").length).to eq(1)
        end
    end

    it 'has upgrade records in the db_versioning' do
        skip "Minor upgrade" if @info[:minor_upgrade]

        cmd = SafeExec.run("sqlite3 /var/lib/one/one.db " \
                           "'select comment from db_versioning'", 10, 10)
        output = cmd.stdout.split("\n")

        regex = '^OpenNebula \d+\.\d+\.\d+(\.\d+)? (\(\w+\) )?daemon bootstrap'
        expect(output.select {|i| i[/#{regex}/] }).not_to be_empty

        regex = '^Database migrated from \d+\.\d+\.\d+(\.d+)? to \d+\.\d+\.\d+(\.d+)?'
        expect(output.select {|i| i[/#{regex}/] }).not_to be_empty
    end

    it 'has upgrade records in the local_db_versioning' do
        skip "Minor upgrade" if @info[:minor_upgrade]

        cmd = SafeExec.run("sqlite3 /var/lib/one/one.db " \
                           "'select comment from local_db_versioning'", 10, 10)
        output = cmd.stdout.split("\n")

        regex = '^OpenNebula \d+\.\d+\.\d+(\.\d+)? (\(\w+\) )?daemon bootstrap'
        expect(output.select {|i| i[/#{regex}/] }).not_to be_empty

        regex = '^Database migrated from \d+\.\d+\.\d+(.\d+)? to \d+\.\d+\.\d+(\.d+)?'
        expect(output.select {|i| i[/#{regex}/] }).not_to be_empty
    end

    it 'has opennebula in package logs on nodes' do
        @info[:target_hosts] = []
        onehost_list = cli_action_xml('onehost list -x')
        onehost_list.each("/HOST_POOL/HOST[CLUSTER_ID='0']") do |h|
            @info[:target_hosts] << h['NAME']
        end
        @info[:target_hosts].each do |h|
            if @info[:os_family] == 'centos7'
                cmd = "grep 'Installed: opennebula' /var/log/yum.log"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)

                cmd = "grep 'Updated: opennebula' /var/log/yum.log"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)

            elsif @info[:os_family] == 'centos8'
                cmd = "dnf history info opennebula-node-kvm | grep 'Install[[:space:]]*opennebula'"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)

                cmd = "dnf history info opennebula-node-kvm | grep 'Upgraded[[:space:]]*opennebula'"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)

            elsif @info[:os_family] == 'debian'
                log_file = '/var/log/apt/history.log'
                cmd = "grep 'Install:.* opennebula-node' #{log_file}"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)

                cmd = "grep 'Upgrade:.* opennebula-' #{log_file}"
                ret = SafeExec.run("ssh root@#{h} \"#{cmd}\"")
                expect(ret.success?).to be(true)
            end
        end
    end

    # TODO: Cover
    # it 'has all opennebula packages on same version on nodes' do ...

    it 'has no rpm/dpkg old/new files' do
        skip 'not OneScape' unless @defaults[:microenv] =~ /onescape/

        # Centos/RedHat
        if File.file?('/var/log/yum.log') || File.file?('/var/log/dnf.log')
            cmd = SafeExec.run('find /etc/one /var/lib/one/remotes/etc/ ' \
                               '-regex \'.*\.rpm\(new\|old\)\'')

            expect(cmd.stdout).to be_empty

        # Debian/Ubuntu
        elsif File.file?('/var/log/apt/history.log')
            cmd = SafeExec.run('find /etc/one /var/lib/one/remotes/etc/ ' \
                               '-regex \'.*\.dpkg-\(new\|old\|dist\)\'')

            expect(cmd.stdout).to be_empty

        else
            raise 'yum or apt log file not found'
        end
    end
end
