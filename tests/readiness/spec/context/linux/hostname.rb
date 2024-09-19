############################################################
#
# Test Snippets
#

shared_context 'context_linux_validate_etc_hosts' do |hostname|
    before(:all) do
        cmd = "grep '#{hostname}' /etc/hosts"
        @hosts_line = @info[:vm].ssh(cmd).stdout.strip
    end

    it 'single entry exists' do
        expect(@hosts_line).not_to be_empty
        expect(@hosts_line.lines.count).to eq 1
    end

    it 'has trailing comment' do
        expect(@hosts_line).to end_with('# one-contextd')
    end

    it 'has hostname' do
        expect(@hosts_line.split).to include(hostname.split('.')[0])
    end

    it 'has FQDN' do
        expect(@hosts_line.split).to include(hostname)
    end

    it 'has IP' do
        expect(@hosts_line.split[0]).to \
            eq('127.0.0.1').or \
                eq('127.0.1.1').or \
                    eq(@info[:vm].ip)
    end
end

shared_context 'context_linux_validate_hostname' do |image, hostname, after_reboot = false|
    it 'check hostname' do
        if image =~ /(freebsd)/i
            cmd = 'hostname -s'
        else
            cmd = 'hostname'
        end

        out = @info[:vm].ssh(cmd).stdout.strip
        exp = hostname.split('.')[0]
        expect(out).to eq(exp)
    end

    it 'check FQDN' do
        out = @info[:vm].ssh('hostname -f').stdout.strip
        expect(out).to eq(hostname)
    end

    it 'domain in resolv.conf' do
        out = @info[:vm].ssh('egrep ^domain /etc/resolv.conf').stdout.strip

        if hostname =~ /^[^\.]+\.(.+)$/
            expect(out).to eq("domain #{Regexp.last_match(1)}")
        else
            expect(out).to be_empty
        end
    end

    if after_reboot
        it 'has hostname in logs' do
            if image =~ /(fedora|opensuse|ubuntu.*min|alt|debian12)/i
                skip 'No syslog'
            end

            out = @info[:vm].ssh('tail -n1 /var/log/messages /var/log/syslog').stdout.strip
            expect(out).not_to be_empty, 'No log entry found'

            line = out.lines[-1]

            # Match various line formats
            if line =~ /^\d/
                # 2021-10-20T15:03:53.799617+00:00 localhost systemd[1]: Queued ...
                _datetime, log_hostname = line.split
            else
                # Oct 19 15:54:00 localhost cron.info crond[2820]: USER root ...
                _month, _day, _time, log_hostname = line.split
            end

            exp_hostname = hostname.split('.')[0]
            expect(log_hostname).to eq(exp_hostname)
        end
    end
end

###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_set_hostname' do |image, hv, prefix, hostname|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          SET_HOSTNAME="#{hostname}",
          SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\"]
    EOT

    include_examples 'context_linux_validate_hostname', image, hostname
    include_examples 'context_linux_reboot', img_safe_reboot(image)
    include_examples 'context_linux_validate_hostname', image, hostname, true

    # creates new entry in /etc/hosts with our comment tag
    context 'creates new entry in /etc/hosts' do
        it 'finds managed entry' do
            out = @info[:vm].ssh("grep '# one-contextd' /etc/hosts").stdout.strip.split
            @info[:hosts_ip] = out[0]
            @info[:hosts_name] = out[1]
            expect(@info[:hosts_ip]).not_to be_empty
            expect(@info[:hosts_ip]).to match(/^\d+\.\d+\.\d+\.\d+$/)
            expect(@info[:hosts_name]).not_to be_empty
            expect(@info[:hosts_name]).to eq(hostname)
        end

        it_behaves_like 'context_linux_validate_etc_hosts', hostname
    end

    # updated our existing entry with latest IP or hostname
    # we don't check for IP/name content, just update our line
    context 'updates own entry in /etc/hosts' do
        it 'hacks record to have just tag' do
            cmd = @info[:vm].ssh("sed -i -e 's/.*\\(# one-contextd\\)$/\\1/' /etc/hosts")
            expect(cmd.success?).to be(true)

            # validate above change
            cmd = @info[:vm].ssh("grep '^# one-contextd$' /etc/hosts")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.lines.count).to eq 1
        end

        include_examples 'context_linux_reboot', img_safe_reboot(image)

        it_behaves_like 'context_linux_validate_etc_hosts', hostname
    end

    context 'updates foreign entry with managed IP in /etc/hosts' do
        it 'hacks record to have fake host without tag' do
            cmd = @info[:vm].ssh("sed -i -e 's/^\\(#{@info[:hosts_ip]}\\).*# one-contextd$/\\1 fakehost.fakedomain fakehost/' /etc/hosts")
            expect(cmd.success?).to be(true)

            # validate above change
            cmd = @info[:vm].ssh("grep 'fakehost.fakedomain' /etc/hosts")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.lines.count).to eq 1
        end

        include_examples 'context_linux_reboot', img_safe_reboot(image)

        it "doesn't find fake host entry" do
            cmd = @info[:vm].ssh("grep 'fakehost.fakedomain' /etc/hosts")
            expect(cmd.success?).to be(false)
            expect(cmd.stdout.lines.count).to eq 0
        end

        it_behaves_like 'context_linux_validate_etc_hosts', hostname
    end

    context 'updates foreign entry with managed host name in /etc/hosts' do
        it 'hacks record to have fake IP without tag' do
            cmd = @info[:vm].ssh("sed -i -e 's/^.*\\(#{@info[:hosts_name]}\\).*# one-contextd$/666.666.666.666 \\1/' /etc/hosts")
            expect(cmd.success?).to be(true)

            # validate above change
            cmd = @info[:vm].ssh("grep '666.666.666.666' /etc/hosts")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.lines.count).to eq 1
        end

        include_examples 'context_linux_reboot', img_safe_reboot(image)

        it "doesn't find fake IP entry" do
            cmd = @info[:vm].ssh("grep '666.666.666.666' /etc/hosts")
            expect(cmd.success?).to be(false)
            expect(cmd.stdout.lines.count).to eq 0
        end

        it_behaves_like 'context_linux_validate_etc_hosts', hostname
    end

    context 'creates new /etc/hosts' do
        it 'deletes /etc/hosts' do
            cmd = @info[:vm].ssh('unlink /etc/hosts')
            expect(cmd.success?).to be(true)
        end

        include_examples 'context_linux_reboot', img_safe_reboot(image)

        it_behaves_like 'context_linux_validate_etc_hosts', hostname
    end
end

shared_examples_for 'context_linux_ec2_hostname' do |image, hv, prefix|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\",
          EC2_HOSTNAME="YES"
        ]
    EOT

    it 'check hostname' do
        if image =~ /(freebsd)/i
            hostname_cmd = 'hostname -s'
        else
            hostname_cmd = 'hostname'
        end

        out = @info[:vm].ssh(hostname_cmd).stdout.strip

        if out =~ /^ip-/
            exp = 'ip-' + @info[:vm].ip.tr('.', '-')
        elsif out =~ /\.novalocal$/
            exp = 'mxfun-vbx02-vsrxm066' # metadata server
        else
            exp = 'cannot get expected hostname'
        end

        expect(out).to eq(exp)
    end

    it 'check FQDN' do
        out = @info[:vm].ssh('hostname -f').stdout.strip

        if out =~ /^ip-/
            exp = 'ip-' + @info[:vm].ip.tr('.', '-')
        elsif out =~ /\.novalocal$/
            exp = 'mxfun-vbx02-vsrxm066.novalocal' # metadata server
        else
            exp = 'cannot get expected hostname'
        end

        expect(out).to eq(exp)
    end
end

shared_examples_for 'context_linux_dns_hostname' do |image, hv, prefix|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\",
          DNS_HOSTNAME="YES"
        ]
    EOT

    it 'check hostname' do
        if image =~ /(freebsd)/i
            hostname_cmd = 'hostname -s'
        else
            hostname_cmd = 'hostname'
        end

        # resolve hostname
        begin
            @info[:dns_hostname] = Resolv.getname(@info[:vm].ip)
        rescue StandardError
            raise "Could not resolve IP #{@info[:vm].ip} to hostname"
        end

        exp = @info[:dns_hostname].split('.')[0]
        out = @info[:vm].ssh(hostname_cmd).stdout.strip
        expect(out).to eq(exp)
    end

    it 'check FQDN' do
        unless @info[:dns_hostname]
            raise "Could not resolve IP #{@info[:vm].ip} to hostname"
        end

        out = @info[:vm].ssh('hostname -f').stdout.strip
        expect(out).to eq(@info[:dns_hostname])
    end
end
