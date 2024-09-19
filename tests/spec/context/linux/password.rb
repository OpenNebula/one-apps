###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_password' do |image, hv, prefix, user, ctx_type, ctx_password, password|
    include_examples 'context', image, hv, prefix, <<EOT
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
  USERNAME="#{user}",
  #{ctx_type}="#{ctx_password}"
]
EOT

    it 'ssh (required)' do
        @info[:vm].wait_ping
        @info[:vm].reachable?(user)
    end

    it 'contextualized' do
        unless user == 'root'
            @info[:cmd_pre] = 'sudo -n'
        end

        # wait for variables for after-network contextualization to be ready
        wait_loop do
            cmd = @info[:vm].ssh("#{@info[:cmd_pre]} test -f /var/run/one-context/context.sh.network", false, {}, user)
            cmd.success?
        end

        # wait for any contextualization to finish
        wait_loop do
            cmd = @info[:vm].ssh("#{@info[:cmd_pre]} test -e /var/run/one-context/one-context.lock", false, {}, user)
            cmd.fail?
        end
    end

    it 'ssh fails for user with password' do
        ssh_opts = '-o StrictHostKeyChecking=no ' \
                   '-o UserKnownHostsFile=/dev/null ' \
                   '-o PasswordAuthentication=yes ' \
                   '-o PubkeyAuthentication=no'

        cmd = SafeExec.run("sshpass -p #{password} ssh #{ssh_opts} #{user}@#{@info[:vm].ip} \"echo\" 2>/dev/null")
        expect(cmd.success?).to be(false)
    end

    it 'reconfigures sshd for password authentication' do
        # detect sshd_config
        cmd = @info[:vm].ssh('ls -1 /etc/ssh/sshd_config /etc/openssh/sshd_config /etc/ssh/sshd_config.d/99-one.conf', false, {}, user)
        sshd_config = cmd.stdout.strip.split("\n")[0]
        expect(sshd_config).not_to be_nil
        expect(sshd_config).not_to be_empty

        @info[:vm].ssh("#{@info[:cmd_pre]} sed -i -e '/^PasswordAuthentication[[:space:]]/d' #{sshd_config}", false, {}, user)
        cmd = @info[:vm].ssh("echo 'PasswordAuthentication yes' | #{@info[:cmd_pre]} tee -a #{sshd_config}", false, {}, user)
        expect(cmd.success?).to be(true)

        @info[:vm].ssh("#{@info[:cmd_pre]} sed -i -e '/^PermitRootLogin[[:space:]]/d' #{sshd_config}", false, {}, user)
        cmd = @info[:vm].ssh("echo 'PermitRootLogin yes' | #{@info[:cmd_pre]} tee -a #{sshd_config}", false, {}, user)
        expect(cmd.success?).to be(true)

        cmd = @info[:vm].ssh("#{@info[:cmd_pre]} service sshd restart", false, {}, user)
        cmd = @info[:vm].ssh("#{@info[:cmd_pre]} service ssh  restart", false, {}, user) if cmd.fail?
        cmd = @info[:vm].ssh("#{@info[:cmd_pre]} systemctl restart sshd", false, {}, user) if cmd.fail?
        expect(cmd.success?).to be(true)

        @info[:vm].reachable?(user)
    end

    it 'ssh with password' do
        ssh_opts = '-o StrictHostKeyChecking=no ' \
                   '-o UserKnownHostsFile=/dev/null ' \
                   '-o PasswordAuthentication=yes ' \
                   '-o PubkeyAuthentication=no'

        cmd = SafeExec.run("sshpass -p #{password} ssh #{ssh_opts} #{user}@#{@info[:vm].ip} \"echo\"")
        expect(cmd.success?).to be(true)
    end
end
