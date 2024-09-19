###########################################################
#
# Test Snippets
#

shared_examples_for 'onesysprep_reboot' do |image, hv|
    it 'powers off (required)' do
        skip 'VM not running' if @info[:vm].state != 'RUNNING'

        # === LXD bug workaround ===
        # LXD driver sucks when poweroff operation timeouts, leaves container
        # running, but with alternating VM state in OpenNebula. We better issue
        # hard power off https://github.com/OpenNebula/one/issues/5580
        if hv == 'LXD'
            @info[:vm].poweroff_hard
        else
            case image
            when /^alt/
                @info[:vm].poweroff_hard
            else
                @info[:vm].safe_poweroff
            end
        end
    end

    it 'resumes (required)' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].wait_ping
        @info[:vm].reachable?
    end

    it 'contextualized' do
        # wait for variables for after-network contextualization to be ready
        wait_loop({:timeout => 180}) do
            cmd = @info[:vm].ssh('test -f /var/run/one-context/context.sh.network')
            cmd.success?
        end

        # wait for any contextualization to finish
        wait_loop({:timeout => 180}) do
            cmd = @info[:vm].ssh('test -e /var/run/one-context/one-context.lock')
            cmd.fail?
        end
    end
end

shared_examples_for 'onesysprep_login' do |expect_success = true|
    if expect_success
        it 'is reachable' do
            @info[:vm].ssh_stop_control_master

            wait_loop({:timeout => 30}) do
                cmd = @info[:vm].ssh('echo', false, {:timeout => 10})
                cmd.success?
            end
        end
    else
        it 'is not reachable' do
            @info[:vm].ssh_stop_control_master

            wait_loop({:timeout => 30}) do
                cmd = @info[:vm].ssh('echo', false, {:timeout => 10})
                cmd.fail?
            end
        end
    end
end

###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_onesysprep' do |image, hv, prefix, context|
    include_examples 'context_linux', image, hv, prefix, <<EOT
#{context}
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]"
]
EOT

    context 'run interactively' do
        it "doesn't generalize without user approval" do
            cmd = @info[:vm].ssh('echo N | /usr/sbin/onesysprep')
            expect(cmd.success?).to be(true)
        end

        include_examples 'onesysprep_login'

        it 'generalizes upon user approval' do
            cmd = @info[:vm].ssh('echo yes | /usr/sbin/onesysprep')
            expect(cmd.success?).to be(true)
        end

        include_examples 'onesysprep_login', false
        include_examples 'onesysprep_reboot', image, hv
    end

    context 'run non-interactively' do
        context 'simple apply' do
            it 'generalizes' do
                cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes')
                expect(cmd.success?).to be(true)
            end

            include_examples 'onesysprep_login', false
            include_examples 'onesysprep_reboot', image, hv
        end

        context 'simple apply and power off' do
            it 'generalizes' do
                cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes --poweroff')
                expect(cmd.status).to eq(0).or eq(255)
                expect(cmd.stdout).to include('try to turn off the machine...')
            end

            it 'is powered off' do
                @info[:vm].stopped?
            end

            include_examples 'onesysprep_login', false
            include_examples 'onesysprep_reboot', image, hv
        end

        context 'apply all operations, except zerofill' do
            it 'generalizes' do
                @info[:all_ops] = 6666

                # on CentOS 6 it really blocks booting and interactively
                # asks for initial root password
                c = '/usr/sbin/onesysprep --yes --operations all,-one-zerofill'
                c += ' && unlink /.unconfigured' if image =~ /^centos6/i

                cmd = @info[:vm].ssh(c)
                expect(cmd.success?).to be(true)

                # check number of applied operations
                @info[:all_ops] = cmd.stdout.lines.grep(/Run operation/).size
                expect(@info[:all_ops]).to be >= 45
            end

            include_examples 'onesysprep_login', false
            include_examples 'onesysprep_reboot', image, hv
        end

        context 'apply default operations' do
            it 'generalizes' do
                cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes --operations default')
                expect(cmd.success?).to be(true)

                # check number of applied operations
                default_ops = cmd.stdout.lines.grep(/Run operation/).size
                expect(default_ops).to be >= 35
                expect(default_ops).to be < @info[:all_ops]
            end

            include_examples 'onesysprep_login', false
            include_examples 'onesysprep_reboot', image, hv
        end

        context 'apply only specific operation' do
            it 'creates backup file' do
                @info[:test_file] = "/root/test-#{rand(36**8).to_s(36)}.bak"
                cmd = @info[:vm].ssh("touch #{@info[:test_file]}")
                expect(cmd.success?).to be(true)
            end

            it 'generalizes' do
                # generalize only with operation which removes backup files
                cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes --operations backup-files')
                expect(cmd.success?).to be(true)
                expect(cmd.stdout.lines.grep(/Run operation/).size).to eq(1)
            end

            it "doesn't find backup file" do
                cmd = @info[:vm].ssh("test -f #{@info[:test_file]}")
                expect(cmd.success?).to be(false)
            end

            include_examples 'onesysprep_login'
        end

        context 'apply excluding specific operation' do
            it 'creates backup file' do
                @info[:test_file] = "/root/test-#{rand(36**8).to_s(36)}.bak"
                cmd = @info[:vm].ssh("touch #{@info[:test_file]}")
                expect(cmd.success?).to be(true)
            end

            it 'generalize' do
                # generalize WIWHOUT operation which removes backup files
                cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes --operations default,-backup-files')
                expect(cmd.success?).to be(true)
            end

            include_examples 'onesysprep_login', false
            include_examples 'onesysprep_reboot', image, hv

            it 'finds backup file' do
                cmd = @info[:vm].ssh("test -f #{@info[:test_file]}")
                expect(cmd.success?).to be(true)
            end
        end

        unless image =~ /(^ol|alma|rocky)/i
            context 'simple apply in strict mode' do
                it 'generalizes' do
                    cmd = @info[:vm].ssh('/usr/sbin/onesysprep --yes --strict')
                    expect(cmd.success?).to be(true)
                end

                include_examples 'onesysprep_login', false
                include_examples 'onesysprep_reboot', image, hv
            end
        end
    end
end
