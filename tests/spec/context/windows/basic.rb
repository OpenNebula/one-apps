HOSTNAME = 'rspectest'

shared_examples_for 'context_windows_basic1' do |image, hv, prefix|
    include_examples 'context_windows', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          TOKEN="YES",
          SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
          REPORT_READY="YES",
          SET_HOSTNAME=#{HOSTNAME},
          START_SCRIPT="echo ok >>C:\\start_script.txt",
          FILES_DS="$FILE[IMAGE=\\\"win-touch1.bat\\\"] $FILE[IMAGE=\\\"win-fail.bat\\\"] $FILE[IMAGE=\\\"win-touch2.ps1\\\"]",
          INIT_SCRIPTS="win-touch1.bat win-fail.bat win-touch2.ps1"
        ]
    EOT

    it 'reports READY=YES via OneGate' do
        wait_loop(:success => 'YES') do
            @info[:vm].xml['USER_TEMPLATE/READY']
        end
    end

    # TODO: add test for fqdn hostname
    it 'check hostname' do
        o, _e, s = @info[:vm].winrm('hostname')
        expect(s).to eq(true)
        expect(o).to eq(HOSTNAME)
    end

    it 'runs START_SCRIPT' do
        o, _e, s = @info[:vm].winrm('type c:\start_script.txt')
        expect(s).to eq(true)
        expect(o).to eq('ok')
    end

    it 'runs INIT_SCRIPTS' do
        ['c:\touch1.txt', 'c:\touch2.txt'].each do |f|
            o, _e, s = @info[:vm].winrm("type #{f}")
            expect(s).to eq(true)
            expect(o.include?('ok')).to be(true), "Failed to find #{f}"
        end
    end

    # TODO: resolves machines
    # TODO: resize disk
    # TODO: same scenario with EJECT_CDROM

    context 'live network changes' do
        it 'attach NIC' do
            cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}'")
            @info[:vm].running?
        end

        it 'pings attached NIC' do
            @info[:ip2] = @info[:vm].xml['TEMPLATE/NIC[last()]/IP']
            expect(@info[:ip2]).not_to be_empty
            expect(@info[:ip2]).not_to eq(@info[:vm].ip)

            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
            end
        end

        it 'attach NIC alias' do
            nic_name = @info[:vm].xml['TEMPLATE/NIC[1]/NAME']
            cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}' --alias #{nic_name}")
            @info[:vm].running?
        end

        it 'pings attached NIC alias' do
            @info[:ipa] = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/IP']
            expect(@info[:ipa]).not_to be_empty
            expect(@info[:ipa]).not_to eq(@info[:vm].ip)
            expect(@info[:ipa]).not_to eq(@info[:ip2])

            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
                @info[:vm].wait_ping(@info[:ipa])
            end
        end

        it 'attach external NIC alias' do
            Tempfile.open('tmpl') do |tmpl|
                nic_name = @info[:vm].xml['TEMPLATE/NIC[1]/NAME']
                tmpl << "NIC_ALIAS = [NETWORK=\"#{@info[:network_attach]}\", PARENT=#{nic_name}, EXTERNAL=YES]"
                tmpl.close

                @info[:vm].clear_ready
                cli_action("onevm nic-attach #{@info[:vm_id]} --file #{tmpl.path}")
                @info[:vm].running?
            end
        end

        it 'waits for recontextualization' do
            wait_loop(:success => 'YES', :timeout => 100) do
                @info[:vm].xml['USER_TEMPLATE/READY']
            end
        end

        it "doesn't ping external NIC alias" do
            @info[:ipa] = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/IP']

            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_no_ping(@info[:ipa])
                @info[:vm].wait_ping
                @info[:vm].wait_no_ping(@info[:ipa])
            end
        end

        it 'detach NIC aliases' do
            # external alias
            nic_id = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/NIC_ID']
            cli_action("onevm nic-detach #{@info[:vm_id]} #{nic_id}")
            @info[:vm].running?

            # internal alias
            nic_id = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/NIC_ID']
            cli_action("onevm nic-detach #{@info[:vm_id]} #{nic_id}")
            @info[:vm].running?
        end

        it "doesn't ping NIC alias" do
            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
                @info[:vm].wait_no_ping(@info[:ipa])
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
                @info[:vm].wait_no_ping(@info[:ipa])
            end
        end

        it 'reboots' do
            @info[:vm].clear_ready
            @info[:vm].safe_reboot
            @info[:vm].wait_ping

            wait_loop(:success => 'YES') do
                @info[:vm].xml['USER_TEMPLATE/READY']
            end
        end

        it "still doesn't ping NIC alias" do
            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
                @info[:vm].wait_no_ping(@info[:ipa])
                @info[:vm].wait_ping
                @info[:vm].wait_ping(@info[:ip2])
                @info[:vm].wait_no_ping(@info[:ipa])
            end
        end

        it 'detach NIC' do
            nic_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID']
            cli_action("onevm nic-detach #{@info[:vm_id]} #{nic_id}")
            @info[:vm].running?
        end

        it "doesn't ping NIC" do
            wait_loop(:timeout => 100) do
                @info[:vm].wait_ping
                @info[:vm].wait_no_ping(@info[:ip2])
                @info[:vm].wait_ping
                @info[:vm].wait_no_ping(@info[:ip2])
            end
        end
    end
end

shared_examples_for 'context_windows_basic2' do |image, hv, prefix|
    include_examples 'context_windows', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          TOKEN="YES",
          SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
          PASSWORD_BASE64="#{Base64.encode64(WINRM_PSWD).strip}",
          START_SCRIPT_BASE64="#{Base64.encode64('echo ok >>C:\\start_script_base64.txt').strip}",
          START_SCRIPT="echo ok >>C:\\start_script.txt",
          FILES_DS="$FILE[IMAGE=\\\"win-touch1.bat\\\"]",
          INIT_SCRIPTS="win-touch1.bat"
        ]
    EOT

    it 'sets password from PASSWORD_BASE64' do
        wait_loop(:success => 'ok', :timeout => 100) do
            begin
                o, _e, _s = @info[:vm].winrm('echo ok')
                o
            rescue WinRM::WinRMAuthorizationError
                STDERR.puts 'ERR: WinRMAuthorizationError'
                sleep(10)
            end
        end
    end

    it 'runs START_SCRIPT_BASE64' do
        wait_loop(:success => 'ok', :timeout => 100) do
            o, _e, _s = @info[:vm].winrm('type c:\start_script_base64.txt')
            o
        end
    end

    it "doesn't run START_SCRIPT if already START_SCRIPT_BASE64" do
        o, _e, s = @info[:vm].winrm('type c:\start_script.txt')
        expect(o).to be_empty
    end

    it 'runs INIT_SCRIPTS' do
        ['c:\touch1.txt'].each do |f|
            o, e, s = @info[:vm].winrm("type #{f}")
            expect(s).to eq(true)
            expect(o.include?('ok')).to be(true), "Failed to find #{f}"
        end
    end

    it "doesn't report READY=YES via OneGate" do
        wait_loop(:success => nil) do
            @info[:vm].xml['USER_TEMPLATE/READY']
        end
    end

    context 'offline network changes' do
        include_examples 'context_windows_safe_poweroff'

        it 'attach NIC' do
            cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}'")
            @info[:vm].state?('POWEROFF')
        end

        it 'attach NIC alias' do
            nic_name = @info[:vm].xml['TEMPLATE/NIC[1]/NAME']
            cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}' --alias #{nic_name}")
            @info[:vm].state?('POWEROFF')
        end

        it 'resumes' do
            cli_action("onevm resume #{@info[:vm_id]}")

            @info[:vm].running?
            @info[:vm].wait_ping
        end

        it 'pings all IPs' do
            ip2 = @info[:vm].xml['TEMPLATE/NIC[last()]/IP']
            expect(ip2).not_to be_empty
            expect(ip2).not_to eq(@info[:vm].ip)

            ipa = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/IP']
            expect(ipa).not_to be_empty
            expect(ipa).not_to eq(@info[:vm].ip)
            expect(ipa).not_to eq(ip2)

            wait_loop do
                @info[:vm].wait_ping
                @info[:vm].wait_ping(ip2)
                @info[:vm].wait_ping(ipa)
            end
        end

        include_examples 'context_windows_safe_poweroff'

        it 'detach NIC alias' do
            nic_id = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/NIC_ID']
            cli_action("onevm nic-detach #{@info[:vm_id]} #{nic_id}")
            @info[:vm].state?('POWEROFF')
        end

        it 'detach NIC' do
            nic_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID']
            cli_action("onevm nic-detach #{@info[:vm_id]} #{nic_id}")
            @info[:vm].state?('POWEROFF')
        end

        it 'resumes' do
            cli_action("onevm resume #{@info[:vm_id]}")

            @info[:vm].running?
            @info[:vm].wait_ping
        end
    end
end
