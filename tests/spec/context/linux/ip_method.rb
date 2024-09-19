require_relative '../windows'

# TODO: move into defaults.yaml
IP_METHOD_REMOTE4='192.168.110.1'
IP_METHOD_REMOTE6='fc00::1'
IP_METHOD_MATCH_IP4_DHCP=/^192\.168\.110\./
IP_METHOD_MATCH_IP6_SLAAC=/^fc00::c0ff/i
IP_METHOD_MATCH_IP6_SLAAC_PREFIX=/^fc00::/i
IP_METHOD_MATCH_IP6_DHCP=/^fc00::[a-f,0-9]+$/i

############################################################
#
# Helper Functions
#

# From within VM pings from src_iface/src_ip to dst_ip
# over IPv4 or IPv6 based on use_ipv4 argument.
def ping_from_ip(image, use_ipv4, src_iface, src_ip, dst_ip)
    wait_loop(:timeout => 30) do
        if image =~ /windows/i
            if use_ipv4
                ping = 'ping -4'
            else
                ping = 'ping -6'
            end

            o, _e, s = @info[:vm].winrm("#{ping} -S #{src_ip} -n 2 -w 1000 #{dst_ip}")

            s && \
                !o.match(/Packets: Sent = (\d+), Received = (\d+), Lost = 0 \(0% loss\)/).nil? && \
                Regexp.last_match(1) != '0' && \
                Regexp.last_match(1) == Regexp.last_match(2)

        elsif image =~ /freebsd/i
            if use_ipv4
                ping = 'ping -t 3'
            elsif image =~ /freebsd1[012]/i
                ping = 'ping6 -X 3'
            else
                ping = 'ping -6 -t 3'
            end

            cmd = @info[:vm].ssh("#{ping} -S #{src_ip} -c 2 -q #{dst_ip}")
            cmd.success?
        else
            if image =~ /(centos|rhel) 6/i
                if use_ipv4
                    ping = 'ping'
                else
                    ping = 'ping6'
                end
            else
                if use_ipv4
                    ping = 'ping -4'
                else
                    ping = 'ping -6'
                end
            end

            cmd = @info[:vm].ssh("#{ping} -I #{src_iface} -c 2 -w 3 -q #{dst_ip}")
            cmd.success?
        end
    end
end

# Inside VM read configured IPs
def read_vm_ips(image)
    @info[:vm_nic_ipv4] = []
    @info[:vm_nic_ipv6] = []

    success = false

    if image =~ /windows/i
        cmd = "netsh interface ip show addresses \\\"#{@info[:vm_nic]}\\\""
        o4, _e4, s4 = @info[:vm].winrm(cmd)

        expect(s4).to be(true)

        cmd = "netsh interface ipv6 show addresses \\\"#{@info[:vm_nic]}\\\""
        o6, _e6, s6 = @info[:vm].winrm(cmd)

        expect(s6).to be(true)

        o4.lines.each do |l|
            #     IP Address:                           172.20.0.8
            next unless l =~ /^\s*IP Address:\s*([\d\.]+)$/

            @info[:vm_nic_ipv4] << Regexp.last_match(1)
            break
        end

        o6.lines.each do |l|
            pp l
            # Address fe80::a0f0:6274:3d1e:149c%9 Parameters
            next unless l =~ /^Address\s+([a-f\d:]+)[\s%].*Parameters$/

            @info[:vm_nic_ipv6] << Regexp.last_match(1)
            break
        end

        success = s4 && s6
    else
        # Command ip
        cmd = @info[:vm].ssh("ip addr show dev #{@info[:vm_nic]}")

        if cmd.success?
            cmd.stdout.lines.each do |l|
                if l =~ %r{^\s*inet\s+([\d\.]+)/}
                    @info[:vm_nic_ipv4] << Regexp.last_match(1)
                elsif l =~ %r{^\s*inet6\s+([a-f\d:]+)/}
                    @info[:vm_nic_ipv6] << Regexp.last_match(1)
                end
            end
        else
            # Command ifconfig
            cmd = @info[:vm].ssh("ifconfig #{@info[:vm_nic]}")

            if cmd.success?
                cmd.stdout.lines.each do |l|
                    if l =~ /^\s*inet\s+([\d\.]+)[\s%]/
                        @info[:vm_nic_ipv4] << Regexp.last_match(1)
                    elsif l =~ /^\s*inet6\s+([a-f\d:]+)[\s%]/
                        @info[:vm_nic_ipv6] << Regexp.last_match(1)
                    end
                end
            end
        end

        success = cmd.success?
    end

    # Cleanup and sort
    @info[:vm_nic_ipv4] -= ['0.0.0.0']
    @info[:vm_nic_ipv6] -= ['::']

    @info[:vm_nic_ipv4].sort!
    @info[:vm_nic_ipv6].sort!

    success
end

# Filters most likely IPv4 static addresses
# (without consulting with OpenNebula)
def get_ipv4_static
    @info[:vm_nic_ipv4] \
        - get_ipv4_link_local \
        - get_ipv4_dhcp
end

# Filter IPv4 link-local from a list
def get_ipv4_link_local
    @info[:vm_nic_ipv4].grep(/^169\.254\./)
end

# Filter IPv4 link-local from a list
def get_ipv4_dhcp
    @info[:vm_nic_ipv4].grep(IP_METHOD_MATCH_IP4_DHCP)
end

# Filters most likely IPv6 static addresses
# (without consulting with OpenNebula)
def get_ipv6_static
    @info[:vm_nic_ipv6] \
        - get_ipv6_link_local \
        - get_ipv6_slaac \
        - get_ipv6_slaac_privacy \
        - get_ipv6_dhcp
end

# Filter IPv6 link-local from a list
def get_ipv6_link_local
    @info[:vm_nic_ipv6].grep(/^fe80::/i)
end

# Filter IPv6 SLAAC from a list
def get_ipv6_slaac
    @info[:vm_nic_ipv6].grep(IP_METHOD_MATCH_IP6_SLAAC)
end

# Filter IPv6 privacy SLAAC from a list
def get_ipv6_slaac_privacy
    @info[:vm_nic_ipv6].grep(IP_METHOD_MATCH_IP6_SLAAC_PREFIX) \
        - get_ipv6_slaac \
        - get_ipv6_dhcp
end

# Filter IPv6 DHCPv6 address
def get_ipv6_dhcp
    @info[:vm_nic_ipv6].grep(IP_METHOD_MATCH_IP6_DHCP)
end

# Set NIC name
def set_last_vm_nic(image, hv)
    @info[:vm_nic] = ''

    if image =~ /windows/i
        # MAC address on Windows is uppercased with - separators
        mac_win = @info[:vm].xml['TEMPLATE/NIC[last()]/MAC'] \
                            .upcase \
                            .gsub(':', '-')

        cmd = 'Get-NetAdapter | Select-Object Name, InterfaceDescription, MacAddress, Status | ConvertTo-Csv -NoTypeInformation'
        o, e, s = @info[:vm].powershell(cmd)

        o.lines.each do |l|
            if l =~ /^"([^"]+)",".*","#{mac_win}",/
                @info[:vm_nic] = Regexp.last_match(1)
            end
        end
    else
        # TODO: improve Unix to query the VM inside
        nic_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID'].to_i
        nic_model = @info[:vm].xml['TEMPLATE/NIC[last()]/MODEL']

        @info[:vm_nic] = guess_nic_prefix(image, nic_model, hv)

        # HACK: as we use (different model) e1000 for second interface
        if image =~ /freebsd/i && @info[:vm_nic] == 'em'
            @info[:vm_nic] << '0'
        else
            @info[:vm_nic] << nic_id.to_s
        end
    end
end

# Guess what NIC name prefix can we expect inside the VM based on
# image (Linux or BSD?), ONE NIC model and used hypervisor (default)
def guess_nic_prefix(image, model, hv)
    prefix = 'ethUNKNOWN'

    if image =~ /freebsd/i
        case model
        when 'virtio'
            prefix = 'vtnet'
        when 'e1000'
            prefix = 'em'
        when '', nil # default unspecified
            prefix = 'vtnet'
        end
    else
        prefix = 'eth'
    end

    prefix
end

############################################################
#
# Test Snippets
#

shared_examples_for 'context_linux_ip_method' do |image, hv, prefix, context, netcfg_type, netcfg_netplan_renderer, netcfg_type_default, hotplug, method, ip6_method, vnet, use_dhcp, has_ipv4, has_ipv6, test_metric, test_mtu|
    if image =~ /freebsd/i
        nic_model = 'e1000'
    else
        nic_model = ''
    end

    # NOTE: If IP6_METHOD and METHOD are equal, we intentionally set
    # empty IP6_METHOD='' to test if context scripts propertly default
    # IP6_METHOD to METHOD.
    if hotplug
        vm_context = <<~EOT
            #{context}
            FEATURES=[
              GUEST_AGENT="yes"
            ]
            CONTEXT=[
              NETWORK="YES",
              NETCFG_TYPE="#{netcfg_type}",
              NETCFG_NETPLAN_RENDERER="#{netcfg_netplan_renderer}",
              SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
              PASSWORD="#{WINRM_PSWD}",
              TOKEN="YES",
              REPORT_READY="YES"
            ]
        EOT
    else
        vm_context = <<~EOT
            #{context}
            FEATURES=[
              GUEST_AGENT="yes"
            ]
            CONTEXT=[
              NETWORK="YES",
              NETCFG_TYPE="#{netcfg_type}",
              NETCFG_NETPLAN_RENDERER="#{netcfg_netplan_renderer}",
              SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
              PASSWORD="#{WINRM_PSWD}",
              TOKEN="YES",
              REPORT_READY="YES"
            ]
            NIC=[
              NETWORK="public"
            ]
            NIC=[
              NETWORK="#{vnet}",
              METRIC="444",
              IP6_METRIC="666",
              GUEST_MTU="1499",
              METHOD="#{method}",
              IP6_METHOD="#{method == ip6_method ? '' : ip6_method}"
              #{nic_model.empty? ? '' : ",MODEL=#{nic_model}"}
            ]
        EOT
    end

    if image =~ /windows/i
        include_examples 'context_windows', image, hv, prefix, vm_context
    else
        include_examples 'context_linux', image, hv, prefix, vm_context
    end

    it 'waits for reporting READY via OneGate' do
        wait_loop(:success => 'YES', :timeout => 90) do
            @info[:vm].xml['USER_TEMPLATE/READY']
        end

        # clear to catch anothre READY after hotplug
        cli_update("onevm update #{@info[:vm_id]}", 'READY=""', true, true)
    end

    if hotplug
        it 'attaches NIC (required)' do
            # count NICs so we can validate we have new after attach
            old_nic_count = 0
            @info[:vm].xml.each('TEMPLATE/NIC') { old_nic_count += 1 }
            expect(old_nic_count).to be > 0

            # On FreeBSD (all current versions 11-13), the virtio NIC drops
            # received DHCP packages due to bad checksums. As a workaround,
            # we use emulated NIC.
            if image =~ /freebsd/i
                nic_tmpl = <<-EOT
                    NIC = [
                        NETWORK    = "#{vnet}",
                        METHOD     = "#{method}",
                        IP6_METHOD = "#{method == ip6_method ? '' : ip6_method}",
                        MODEL      = "e1000",
                        METRIC     = "444",
                        IP6_METRIC = "666",
                        GUEST_MTU  = "1499"
                    ]
                EOT
            else
                nic_tmpl = <<-EOT
                    NIC = [
                        NETWORK    = "#{vnet}",
                        METHOD     = "#{method}",
                        IP6_METHOD = "#{method == ip6_method ? '' : ip6_method}",
                        METRIC     = "444",
                        IP6_METRIC = "666",
                        GUEST_MTU  = "1499"
                    ]
                EOT
            end

            cli_action_wrapper_with_tmpfile("onevm nic-attach #{@info[:vm_id]} --file", nic_tmpl,
                                            true)
            @info[:vm].running?

            # validate we still have new NIC attached
            new_nic_count = 0
            @info[:vm].xml.each('TEMPLATE/NIC') { new_nic_count += 1 }
            expect(new_nic_count).to eq(old_nic_count + 1)
        end

        if image =~ /windows/i
            it 'has NIC inside VM (required)' do
                wait_loop(:timeout => 120) do
                    set_last_vm_nic(image, hv)
                    !@info[:vm_nic].empty?
                end

                sleep 3
            end
        else
            it 'has NIC inside VM (required)' do
                set_last_vm_nic(image, hv)

                wait_loop(:timeout => 120) do
                    cmd = @info[:vm].ssh("ip addr show dev #{@info[:vm_nic]}")
                    cmd = @info[:vm].ssh("ifconfig #{@info[:vm_nic]}") unless cmd.success?
                    cmd.success?
                end

                # it could take a while to propagate the udev/devd event
                sleep 3
            end

            include_examples 'context_linux_contextualized'
        end

        it 'waits for reporting READY via OneGate' do
            wait_loop(:success => 'YES', :timeout => 90) do
                @info[:vm].xml['USER_TEMPLATE/READY']
            end
        end
    end

    it 'selects NIC' do
        set_last_vm_nic(image, hv)
    end

    # Validates the requested network provider manages
    # the interface and not any different one
    if has_ipv4 || has_ipv6
        context 'network service' do
            if image =~ /windows/i
                # on Windows we don't validate it's Windows, but only
                # check the interface is connected and configured
                include_examples 'context_linux_netcfg_type_service_configured'
            else
                include_examples 'context_linux_verify_netcfg_type_service',
                                 image,
                                 netcfg_type,
                                 netcfg_netplan_renderer,
                                 netcfg_type_default,
                                 method, ip6_method, use_dhcp
            end
        end
    end

    context 'network interface' do
        it 'reads IP configuration from NIC in VM (required)' do
            set_last_vm_nic(image, hv)

            success = nil

            # wait until hot-plugged interface is available in the system
            wait_loop(:timeout => 120) do
                wait_ips = true

                # give more time on Windows, because we there periodically
                # poll/recontextualize every 30 seconds, not as a result of
                # NIC attach event
                if image =~ /windows/i
                    retries  = 25
                else
                    retries  = 6
                end

                # We don't need to fail test here if guessed number of IPs doesn't
                # appear, because we don't know for sure how many addresses should
                # appear (this is tested by examples below). We only retry few
                # times on our own if number if IPs is strange.
                while retries > 0 && wait_ips
                    success = read_vm_ips(image)

                    retries -= 1
                    wait_ips = !success

                    if use_dhcp
                        wait_ips ||= method == 'dhcp' && @info[:vm_nic_ipv4].empty?
                        wait_ips ||= ip6_method == 'auto' && [get_ipv6_slaac,
                                                              get_ipv6_slaac_privacy].flatten.empty?
                        wait_ips ||= ip6_method == 'dhcp' && [get_ipv6_dhcp].flatten.empty?
                    else
                        wait_ips ||= ['',
                                      'static'].include?(method) && get_ipv4_static.flatten.empty?
                        wait_ips ||= ['',
                                      'static'].include?(ip6_method) && get_ipv6_static.flatten.empty?
                    end

                    sleep 2 if wait_ips
                end

                success
            end

            expect(success).not_to be_nil
            expect(success).to eq(true)
        end

        ### Check IPv4 configuration ###

        if has_ipv4
            if ['', 'static'].include?(method) && !use_dhcp
                it 'has static IPv4' do
                    ips = @info[:vm].xml['TEMPLATE/NIC[last()]/IP']
                    expect(ips).not_to be_empty
                    expect(@info[:vm_nic_ipv4]).to eq([ips])
                end

            elsif method == 'dhcp'
                it 'has IPv4 address from DHCP (required)' do
                    expect(@info[:vm_nic_ipv4].size).to eq(1),
                                                        "Found IPs: #{@info[:vm_nic_ipv4].join(' ')}"
                    expect(get_ipv4_dhcp.size).to eq(1),
                                                  "No IPv4 DHCP found - #{@info[:vm_nic_ipv4].join(' ')}"
                end

                it 'pings IPv4 remote' do
                    ping_from_ip(image, true, @info[:vm_nic], @info[:vm_nic_ipv4][0],
                                 IP_METHOD_REMOTE4)
                end

            elsif method == 'skip' || (['', 'static'].include?(method) && use_dhcp)
                it 'has no IPv4 on skipped interface' do
                    skip('Alpine runs DHCPv4 instead of DHCPv6') if image =~ /alpine/i && ip6_method == 'dhcp'

                    found = get_ipv4_link_local
                    if !found.empty? && found == @info[:vm_nic_ipv4]
                        skip('Link-local on skipped interface!') # We don't control this interface
                    end

                    expect(@info[:vm_nic_ipv4]).to be_empty
                end

            else
                it 'has no IPv4 in unhandled test' do
                    expect(@info[:vm_nic_ipv4]).to be_empty
                    skip("Missing test for #{method}!")
                end
            end
        else
            it 'has no IPv4' do
                expect(@info[:vm_nic_ipv4]).to be_empty
            end
        end

        ### Check IPv6 configuration ###

        if has_ipv6
            if ['', 'static'].include?(ip6_method) && !use_dhcp
                it 'has static IPv6' do
                    ips = []
                    ips << @info[:vm].xml['TEMPLATE/NIC[last()]/IP6_GLOBAL']
                    ips << @info[:vm].xml['TEMPLATE/NIC[last()]/IP6_ULA']
                    ips << @info[:vm].xml['TEMPLATE/NIC[last()]/IP6_LINK']
                    ips.compact!
                    ips.sort!

                    expect(ips).not_to be_empty

                    if windows?
                        expect(@info[:vm_nic_ipv6]).to eq([ips[0]])
                    else
                        expect(@info[:vm_nic_ipv6]).to eq(ips)
                    end
                end

            ### Exceptions to dynamic IPv6 configuration ###
            # Debian 10: Old Netplan with networkd doesn't configure IPv6-only SLAAC
            # interface (when IPv4 is skipped or not configured)
            elsif image =~ /^debian 10/i &&
                   netcfg_type == 'netplan' && netcfg_netplan_renderer.nil? &&
                   ip6_method == 'auto' && (method == 'skip' ||
                   (use_dhcp && ['', 'static'].include?(method)))
                it 'has IPv6 address' do
                    if @info[:vm_nic_ipv6].empty?
                        skip('Known guest misbehaviour!')
                    end

                    # VH-TODO: fail on non empty?
                    expect(@info[:vm_nic_ipv6]).not_to be_empty
                end

            else
                it 'has IPv6 link-local address' do
                    if image =~ /freebsd/i && (ip6_method == 'skip' ||
                       (use_dhcp && ['', 'static'].include?(ip6_method)))
                        skip("FreeBSD don't autoconfigure skipped interface")
                    end

                    @info[:expect_ipv6_count] ||= 0
                    @info[:expect_ipv6_count] += 1

                    skip 'Not supported on Windows' if windows?

                    expect(get_ipv6_link_local.size).to eq(1),
                                                        "No IPv6 link-local found - #{@info[:vm_nic_ipv6].join(' ')}"
                end

                if ['auto', 'dhcp', 'skip'].include?(ip6_method) ||
                   (use_dhcp && ['', 'static'].include?(ip6_method))
                    it 'has no IPv6 SLAAC privacy' do
                        found = get_ipv6_slaac_privacy

                        unless found.empty?
                            @info[:expect_ipv6_count] ||= 0
                            @info[:expect_ipv6_count] += 1
                        end

                        # Interfaces skipped to configure by context scripts
                        # might or might not have the IP address configured
                        if !found.empty? && (ip6_method == 'skip' ||
                           (use_dhcp && ['', 'static'].include?(ip6_method)))
                            skip('Found on skipped interface')
                        end

                        expect(found).to be_empty,
                                         'IPv6 SLAAC privacy found - ' +
                                         @info[:vm_nic_ipv6].join(' ')
                    end

                    it 'has IPv6 SLAAC address' do
                        found = get_ipv6_slaac

                        unless found.empty?
                            @info[:expect_ipv6_count] ||= 0
                            @info[:expect_ipv6_count] += 1
                        end

                        # Interfaces skipped to configure by context scripts
                        # might or might not have the IP address configured
                        if found.empty? && (ip6_method == 'skip' ||
                           (use_dhcp && ['', 'static'].include?(ip6_method)))
                            skip('Optional on skipped interface')
                        end

                        ### Various SLAAC OS quirks ###
                        # On Debian-like with hotplugged interfaces in auto,
                        # the netplan/NM doesn't configure SLAAC
                        if found.empty? && hotplug && ip6_method == 'auto' &&
                            netcfg_type == 'netplan' && netcfg_netplan_renderer == 'NetworkManager'
                            skip('No IPv6 SLAAC. Known guest misbehaviour!')
                        end

                        expect(found.size).to eq(1),
                                              'No IPv6 SLAAC found - ' +
                                              @info[:vm_nic_ipv6].join(' ')

                        @info[:vm_nic_ipv6_ping] = found.first
                    end
                end

                if ['dhcp', 'skip'].include?(ip6_method) ||
                   (use_dhcp && ['', 'static'].include?(ip6_method))
                    it 'has IPv6 DHCPv6 address' do
                        found = get_ipv6_dhcp

                        # Interfaces skipped to configure by context scripts
                        # might or might not have the IP address configured
                        if found.empty? && (ip6_method == 'skip' ||
                           (use_dhcp && ['', 'static'].include?(ip6_method)))
                            skip('Optional on skipped interface')
                        else
                            if (image =~ /freebsd/i && method != 'dhcp') ||
                               (image =~ /alpine/i)
                                skip("FreeBSD and Alpine don't trigger DHCPv6") # leave as TODO
                            end

                            expect(found.size).to eq(1),
                                                  "No IPv6 DHCPv6 found - #{@info[:vm_nic_ipv6].join(' ')}"

                            @info[:expect_ipv6_count] ||= 0
                            @info[:expect_ipv6_count] += 1
                            @info[:vm_nic_ipv6_ping] = found.first
                        end
                    end

                end

                ### Various DHCPv6 OS quirks ###
                # Netplan+networkd doesn't disable properly DHCPv6 in auto
                if (ip6_method == 'auto' && netcfg_type == 'netplan' && netcfg_netplan_renderer.nil?) ||
                   (ip6_method == 'auto' && netcfg_type.empty? && netcfg_type_default == 'netplan' && netcfg_netplan_renderer.nil?) ||
                   # Old systemd-networkd doesn't disable DHCPv6 properly
                   (ip6_method == 'auto' && netcfg_type == 'networkd' && image =~ /^ubuntu(18|20)/i) ||
                   (ip6_method == 'auto' && netcfg_type == 'networkd' && image =~ /^debian(10)/i)
                    it 'has unexpected IPv6 DHCPv6 address!' do
                        @info[:expect_ipv6_count] ||= 0
                        @info[:expect_ipv6_count] += 1

                        expect(get_ipv6_dhcp.size).to eq(1),
                                                      "No IPv6 DHCPv6 found - #{@info[:vm_nic_ipv6].join(' ')}"

                        skip('Known guest misbehaviour!')
                    end
                end

                it "doesn't have more IPv6s" do
                    @info[:expect_ipv6_count] ||= 0

                    found = @info[:vm_nic_ipv6].size

                    skip 'Unsupported on Windows' if windows?

                    expect(found).to eq(@info[:expect_ipv6_count]),
                                     "Expected #{@info[:expect_ipv6_count]} IPv6s, " \
                                     "but #{found} found: " \
                                     + @info[:vm_nic_ipv6].join(' ')
                end

                it 'pings IPv6 remote' do
                    skip('No suitable IPv6 to ping from') unless @info.has_key?(:vm_nic_ipv6_ping)

                    ping_from_ip(image, false, @info[:vm_nic], @info[:vm_nic_ipv6_ping],
                                 IP_METHOD_REMOTE6)
                end
            end
        else
            it 'has no IPv6' do
                expect(@info[:vm_nic_ipv6]).to be_empty
            end
        end

        # Validate we were able to configure custom MTU
        if test_mtu
            if image =~ /windows/i
                test_vm = 'context_windows_network_verify_mtu'
            else
                test_vm = 'context_linux_network_verify_mtu'
            end

            include_examples test_vm,
                             image, nil,
                             1499,
                             ['skip', 'disable'].include?(ip6_method) ? nil : 1499
        end
    end

    # Validate we were able to configure gateway metrics
    # independently on each interface
    if test_metric
        context 'default route' do
            if image =~ /windows/i
                test_vf = 'context_windows_network_verify_metric'
            else
                test_vf = 'context_linux_network_verify_metric'
            end

            include_examples test_vf,
                             image, nil,
                             ['', 'static'].include?(method)     ? '444' : nil,
                             ['', 'static'].include?(ip6_method) ? '666' : nil
        end
    end
end

###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_ip_methods' do |image, hv, prefix, _context, netcfg_type, netcfg_netplan_renderer, netcfg_type_default|
    # Table tests for NIC configuration methods, parameters
    # 1. ETHx_METHOD,
    # 2. ETHx_IP6_METHOD,
    # 3. VNET for NIC,
    # 4. true/false if NICs are autoconfigured
    # 5. expects any IPv4
    # 6. expects any IPv6
    # 7. test for metric
    # 8. test for MTU
    [
        # 1        2           3         4      5      6      7      8
        ['',       '',         'public', false, true,  true,  true,  true],
        ['static', 'static',   'public', false, true,  true,  true,  true],
        ['static', 'skip',     'public', false, true,  true,  true,  true],
        ['static', 'disable',  'public', false, true,  false, true,  true],
        ['skip',   'static',   'public', false, true,  true,  true,  true],
        ['skip',   'skip',     'public', false, false, false, false, false],

        ['dhcp',   'auto',     'dhcp',   true,  true,  true,  false, true],
        ['dhcp',   'dhcp',     'dhcp',   true,  true,  true,  false, true],
        ['dhcp',   'skip',     'dhcp',   true,  true,  true,  false, true],
        ['dhcp',   'disable',  'dhcp',   true,  true,  false, false, true],
        ['skip',   'auto',     'dhcp',   true,  true,  true,  false, true],
        ['skip',   'dhcp',     'dhcp',   true,  true,  true,  false, true],

        # edge cases
        ['static', 'static',   'dhcp',   true,  false, false, false, false],
        ['static', 'skip',     'dhcp',   true,  false, false, false, false],
        ['skip',   'static',   'dhcp',   true,  false, false, false, false],
        ['dhcp',   'static',   'dhcp',   true,  true,  true,  false, true],
        ['static', 'auto',     'dhcp',   true,  true,  true,  false, true]
    ].each do |t|
        # test NIC configuration via coldplug and hotplug
        [false, true].each do |hotplug|
            test_name = "with METHOD='#{t[0]}', IP6_METHOD='#{t[1]}'"
            test_name << ' on DHCP-only network' if t[3]
            test_name = 'hotplugged ' + test_name if hotplug

            context test_name do
                include_examples 'context_linux_ip_method',
                                 image, hv, prefix, nil,
                                 netcfg_type, netcfg_netplan_renderer,
                                 netcfg_type_default,
                                 hotplug, *t
            end
        end
    end
end
