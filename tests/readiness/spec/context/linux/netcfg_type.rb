############################################################
#
# Test Snippets
#

# Validates that expected network service is managing the particular interface
shared_examples_for 'context_linux_verify_netcfg_type_service' do |image, netcfg_type, netcfg_netplan_renderer, netcfg_type_default, method = '', ip6_method = '', use_dhcp = false|
    # network scripts (/etc/sysconfig/network-scripts/)
    if netcfg_type == 'scripts' ||
       (netcfg_type.empty? && netcfg_type_default == 'scripts')
        it 'is network scripts' do
            if image =~ /^(opensuse|sles)/i
                filename = "/etc/sysconfig/network/ifcfg-#{@info[:vm_nic]}"
            else
                filename = "/etc/sysconfig/network-scripts/ifcfg-#{@info[:vm_nic]}"
            end

            cmd = @info[:vm].ssh("cat #{filename}")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(/DEVICE=#{@info[:vm_nic]}/)
            expect(cmd.stdout).to match(/NM_CONTROLLED=no/)
        end
    else
        it 'is not network scripts' do
            if image =~ /^(opensuse|sles)/i
                filename = "/etc/sysconfig/network/ifcfg-#{@info[:vm_nic]}"
            else
                filename = "/etc/sysconfig/network-scripts/ifcfg-#{@info[:vm_nic]}"
            end

            cmd = @info[:vm].ssh("cat #{filename}")

            if cmd.success?
                expect(cmd.stdout).not_to match(/NM_CONTROLLED=['"]?(no|false)['"]/i)
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    # interfaces (/etc/network/interfaces)
    if netcfg_type == 'interfaces' ||
       (netcfg_type.empty? && netcfg_type_default == 'interfaces')
        it 'is interfaces (ifupdown)' do
            cmd = @info[:vm].ssh('cat /etc/network/interfaces')
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(/iface #{@info[:vm_nic]} /)
        end
    else
        it 'is not interfaces (ifupdown)' do
            cmd = @info[:vm].ssh('cat /etc/network/interfaces')

            if cmd.success?
                expect(cmd.stdout).not_to match(/iface #{@info[:vm_nic]} /)
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    # BSD
    if netcfg_type == 'bsd' ||
       (netcfg_type.empty? && netcfg_type_default == 'bsd')
        it 'is BSD network conf.' do
            cmd = @info[:vm].ssh('cat /etc/rc.conf.d/network')
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(/ifconfig_#{@info[:vm_nic]}[_=]/)
        end
    else
        it 'is not BSD network conf.' do
            cmd = @info[:vm].ssh('cat /etc/rc.conf.d/network')

            if cmd.success?
                expect(cmd.stdout).not_to match(/ifconfig_#{@info[:vm_nic]}[_=]/)
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    # NetworkManager
    if netcfg_type == 'nm' ||
       (netcfg_type.empty? && netcfg_type_default == 'nm') ||
       (netcfg_type == 'netplan' && netcfg_netplan_renderer == 'NetworkManager')
        it 'is NetworkManager' do
            cmd = @info[:vm].ssh("nmcli -g GENERAL.STATE dev show #{@info[:vm_nic]}")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(/ \(connect(ing|ed)/)
        end
    else
        it 'is not NetworkManager' do
            cmd = @info[:vm].ssh("nmcli -g GENERAL.STATE dev show #{@info[:vm_nic]}")

            if cmd.success?
                expect(cmd.stdout).to match(/ \(unmanaged\)/)
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    # systemd-networkd
    if netcfg_type == 'networkd' ||
       (netcfg_type.empty? && netcfg_type_default == 'networkd') ||
       (netcfg_type.empty? && netcfg_type_default == 'netplan') || # netplan usually uses networkd renderer
       (netcfg_type == 'netplan' && netcfg_netplan_renderer.nil?)
        it 'is networkd' do
            cmd = @info[:vm].ssh("networkctl status #{@info[:vm_nic]}")

            # Debian 10: Old Netplan with networkd doesn't configure IPv6-only
            # SLAAC interface (when IPv4 is skipped or not configured)
            if image =~ /^debian10/i &&
               netcfg_type == 'netplan' && netcfg_netplan_renderer.nil? &&
               ip6_method == 'auto' && (method == 'skip' ||
               (use_dhcp && ['', 'static'].include?(method)))
                expect(cmd.stdout).to match(%r{Network File: n/a})
                expect(cmd.stdout).to match(/State: [^(]+ \(unmanaged\)/)
                skip('Known guest misbehaviour!')
            end

            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(%r{Network File: /(etc|run)/systemd/})
            expect(cmd.stdout).to match(/State: [^(]+ \(configur(ing|ed)\)/)
        end
    else
        it 'is not networkd' do
            cmd = @info[:vm].ssh("networkctl status #{@info[:vm_nic]}")

            if cmd.success?
                expect(cmd.stdout).to match(%r{Network File: n/a})
                expect(cmd.stdout).to match(%r{State: [^(]+ \(unmanaged|n/a\)})
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    # Netplan
    if netcfg_type == 'netplan' ||
       (netcfg_type.empty? && netcfg_type_default == 'netplan')
        it 'is Netplan' do
            cmd = @info[:vm].ssh('cat /etc/netplan/50-one-context.yaml')
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).to match(/#{@info[:vm_nic]}:/)
            expect(cmd.stdout).to match(/renderer: #{netcfg_netplan_renderer || 'networkd'}/)
        end
    else
        it 'is not Netplan' do
            cmd = @info[:vm].ssh('cat /etc/netplan/50-one-context.yaml')

            if cmd.success?
                expect(cmd.stdout).not_to match(/#{@info[:vm_nic]}:/)
            else
                expect(cmd.stdout).to be_empty
            end
        end
    end

    include_examples 'context_linux_netcfg_type_service_configured'
end

# Checks various network services (only in best-effort mode) and if
# specified interface is still being configured, it waits few cycles
shared_examples_for 'context_linux_netcfg_type_service_configured' do |iface = nil|
    it "waits for #{iface ? iface + ' ' : ''}NIC configuration" do
        vm_nic = iface ? iface : @info[:vm_nic]

        # Windows
        if vm_nic =~ /^Ethernet/i
            cmd = "netsh interface show interface name=\\\"#{vm_nic}\\\""

            winrm = @info[:vm].winrm(cmd)

            unless winrm.flatten.join("\n").match(/Connected/)
                wait_loop(:timeout => 30) do
                    winrm = @info[:vm].winrm(cmd)

                    expect(winrm).not_to be_nil
                    !winrm.flatten.join("\n").match(/Connected/).nil?
                end
            end

            next if winrm.flatten.join("\n").match(/Connected/)
        end

        # Network Manager
        cmd = @info[:vm].ssh("nmcli -g GENERAL.STATE dev show #{vm_nic}")

        if cmd.success?
            if cmd.stdout =~ / \(connecting/
                wait_loop(:timeout => 30) do
                    cmd = @info[:vm].ssh("nmcli -g GENERAL.STATE dev show #{vm_nic}")
                    expect(cmd.success?).to be(true)
                    cmd.stdout.match(/ \(connected/) != nil
                end
            end

            next if cmd.stdout.match(/ \(connected/)
        end

        # systemd-networkd
        cmd = @info[:vm].ssh("networkctl status #{vm_nic}")

        if cmd.success?
            if cmd.stdout =~ /State: [^(]+ \(configuring\)/
                wait_loop(:timeout => 30) do
                    cmd = @info[:vm].ssh("networkctl status #{vm_nic}")
                    expect(cmd.success?).to be(true)
                    cmd.stdout.match(/State: [^(]+ \(configured\)/) != nil
                end
            end

            next if cmd.stdout.match(/State: [^(]+ \(configured\)/)
        end

        skip('Unsupported on this network service')
    end
end

###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_network_netcfg_type_common' do |image, hv, prefix, context, netcfg_type, netcfg_netplan_renderer, netcfg_type_default|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        #{context}
        FEATURES=[
          GUEST_AGENT="yes"]
        CONTEXT=[
          NETWORK="YES",
          NETCFG_TYPE="#{netcfg_type}",
          NETCFG_NETPLAN_RENDERER="#{netcfg_netplan_renderer}",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          START_SCRIPT="echo ok >/tmp/start_script1;
        echo ok >/tmp/start_script2;
        echo ok >>/tmp/start_script3
        "
        ]
    EOT

    context 'network service' do
        it 'selects last NIC' do
            set_last_vm_nic(image, hv)
            expect(@info[:vm_nic]).not_to be_empty
        end

        include_examples 'context_linux_verify_netcfg_type_service',
                         image,
                         netcfg_type,
                         netcfg_netplan_renderer,
                         netcfg_type_default
    end

    context 'general networking' do
        include_examples 'context_linux_network_common', image, hv
    end
end
