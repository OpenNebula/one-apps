###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_context_target' do |image, hv, prefix, target|
    include_examples 'context_linux', image, hv, prefix, <<EOT
CONTEXT=[
  TARGET="#{target}",
  NETWORK="YES",
  SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\",
  START_SCRIPT="echo ok >>/tmp/start_script"
]
EOT

    it 'ran contextualization 1x' do
        out = @info[:vm].ssh('cat /tmp/start_script').stdout.strip
        expect(out.lines.length).to eq(1)
    end

    it 'attach NIC' do
        skip 'Unsupported on this platform' if image =~ /(freebsd)/i
        skip 'Unsupported on this target' if target =~ /^vd/i

        cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}'")
        @info[:vm].running?
    end

    it 'pings attached NIC' do
        skip 'Unsupported on this platform' if image =~ /(freebsd)/i
        skip 'Unsupported on this target' if target =~ /^vd/i

        # ping newly configured IP
        ip = @info[:vm].xml['TEMPLATE/NIC[last()]/IP']
        expect(ip).not_to be_empty
        expect(ip).not_to eq(@info[:vm].ip)

        wait_loop do
            @info[:vm].wait_ping(ip)
            @info[:vm].reachable?
        end

        # wait for any contextualization to finish
        wait_loop do
            cmd = @info[:vm].ssh('test -e /var/run/one-context/one-context.lock')
            cmd.fail?
        end
    end

    it 'ran contextualization 2x' do
        skip 'Unsupported on this platform' if image =~ /(freebsd)/i
        skip 'Unsupported on this target' if target =~ /^vd/i

        out = @info[:vm].ssh('cat /tmp/start_script').stdout.strip
        expect(out.lines.length).to eq(2)
    end
end
