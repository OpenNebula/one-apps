###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_nosudo' do |image, hv, prefix, user|
    include_examples 'context', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          USERNAME="#{user}",
          USERNAME_SHELL="/bin/sh",
          USERNAME_SUDO="NO"
        ]
    EOT

    it 'ssh (required)' do
        @info[:vm].wait_ping
        @info[:vm].reachable?(user)
    end

    it 'sets custom shell to the user' do
        cmd = @info[:vm].ssh("getent passwd '#{user}'", false, {}, user)
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip.split(':')[-1]).to eq('/bin/sh')
    end

    it 'denies sudo commands' do
        cmd = @info[:vm].ssh('sudo -n id -un', false, {}, user)
        expect(cmd.success?).to be(false)
    end
end

shared_examples_for 'context_linux_sudo' do |image, hv, prefix, user|
    include_examples 'context', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          USERNAME="#{user}"
        ]
    EOT

    it 'ssh (required)' do
        @info[:vm].wait_ping
        @info[:vm].reachable?(user)
    end

    it 'allows sudo commands' do
        cmd = @info[:vm].ssh('sudo -n id -un', true, {}, user)
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip).to eq('root')
    end
end
