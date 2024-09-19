###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_common2' do |image, hv, prefix, context|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        #{context}
        CONTEXT=[
          NETWORK="YES",
          TOKEN="YES",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          START_SCRIPT_BASE64="#{Base64.encode64('echo ok >/tmp/start_script_base64')}",
          START_SCRIPT="echo ok >/tmp/start_script",
          TIMEZONE="Europe/Madrid"
        ]
    EOT

    it 'runs START_SCRIPT_BASE64' do
        out = @info[:vm].ssh('cat /tmp/start_script_base64').stdout.strip
        expect(out).to eq('ok')
    end

    it "doesn't run START_SCRIPT if already START_SCRIPT_BASE64" do
        out = @info[:vm].ssh('cat /tmp/start_script').stdout.strip
        expect(out).to eq('')
    end

    it "doesn't report READY=YES via OneGate" do
        vm_ready = @info[:vm].xml['USER_TEMPLATE/READY']
        expect(vm_ready).to be_nil
    end

    it 'has root account without password' do
        # detect shadow file
        cmd = @info[:vm].ssh('find /etc/tcb/root/shadow /etc/shadow /etc/master.passwd')
        @info[:file_shadow] = cmd.stdout.strip.split("\n")[0]
        expect(@info[:file_shadow]).not_to be_nil
        expect(@info[:file_shadow]).not_to be_empty

        # check root password in shadow
        cmd = @info[:vm].ssh("grep '^root:*:' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
    end

    it 'sets custom password for root' do
        # directly hack password and validate
        cmd = @info[:vm].ssh("sed -i -e 's/^\\(root\\):[^:]*/\\1:password/' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
        cmd = @info[:vm].ssh("grep '^root:password:' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
    end

    it 'set custom timezone' do
        out = @info[:vm].ssh("date '+%Z'").stdout.strip
        expect(out).not_to eq('UTC')
        expect(out).to match(/^CES?T$/i)
    end

    include_examples 'context_linux_reboot'

    it "didn't reset root password" do
        cmd = @info[:vm].ssh("grep '^root:password:' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
    end
end
