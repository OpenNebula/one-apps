require 'init'

SUDOERS_DIRS = %w[
    /bin /usr/bin
    /sbin /usr/sbin
    /usr/local/bin /usr/local/sbin
]

describe 'Sudoers' do
    before(:all) do
        # read sudoers
        rtn = SafeExec.run('sudo -n cat /etc/sudoers.d/opennebula 2>/dev/null')
        expect(rtn.fail?).to be false

        # parse individual commands
        @sudo_commands = []
        rtn.stdout.each_line do |line|
            next unless line =~ /^Cmnd_Alias[^=]+=\s*(.*)/

            Regexp.last_match(1).split(',').each do |cmd|
                @sudo_commands << cmd.strip.split[0]
            end
        end

        @sudo_commands.uniq!
    end

    it 'has enough commands' do
        expect(@sudo_commands.size).to be > 10
    end

    it 'finds commands locally' do
        invalid = []

        @sudo_commands.each do |cmd|
            next if File.exist?(cmd)
            next if ['/snap/bin/lxc'].include?(cmd)

            # try to find command in other locations
            base_cmd = File.basename(cmd)
            SUDOERS_DIRS.each do |dir|
                if File.exist?("#{dir}/#{base_cmd}")
                    invalid << "#{cmd} found in #{dir}"
                    break
                end
            end
        end

        expect(invalid).to be_empty, invalid.sort.join("\n")
    end

    it 'finds commands on hosts' do
        if !@defaults[:hosts] || @defaults[:hosts].empty?
            skip('No hosts available')
        end

        invalid = []

        # TODO: validates sudo commands only based on sudoers found
        # on the frontend. Doesn't deal with heterogenous clusters
        # (different OS/versions on frontend/hosts).
        @sudo_commands.each do |cmd|
            next if ['/snap/bin/lxc'].include?(cmd)

            @defaults[:hosts].each do |host|
                rtn = SafeExec::run("ssh #{HOST_SSH_OPTS} #{host} " +
                                    "stat #{cmd} 2>/dev/null")
                next if rtn.success?

                # try to find command in other locations
                base_cmd = File.basename(cmd)
                SUDOERS_DIRS.each do |dir|
                    rtn = SafeExec::run("ssh #{HOST_SSH_OPTS} #{host} " +
                                        "stat #{dir}/#{base_cmd} 2>/dev/null")

                    if rtn.success?
                        invalid << "#{cmd} found in #{dir}"
                        break
                    end
                end
            end
        end

        expect(invalid).to be_empty, invalid.uniq.sort.join("\n")
    end
end
