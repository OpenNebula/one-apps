############################################################
#
# Tests Snippets
#

# Checks if selected interface has specific metric or no metric at all
shared_examples_for 'context_linux_network_verify_metric' do |image, iface, metric = nil, metric6 = metric|
    if metric
        it "has #{iface ? iface + ' ' : ''}IPv4 metric #{metric}" do
            vm_nic = iface ? iface : @info[:vm_nic]

            if image =~ /freebsd/i
                cmd = @info[:vm].ssh("ifconfig #{vm_nic}")
                expect(cmd.success?).to be(true)

                # we can still have IPv6 metric
                if metric6 && metric != metric6 && cmd.stdout =~ /metric\s+#{metric6}(\s|$)/
                    skip('Found IPv6 metric on FreeBSD')
                else
                    expect(cmd.stdout).to match(/metric\s+#{metric}(\s|$)/)
                end
            else
                cmd = @info[:vm].ssh("ip r s dev #{vm_nic}")
                expect(cmd.success?).to be(true)
                expect(cmd.stdout).to match(/(default|0\.0\.0\.0\/\d+) via .* metric\s+#{metric}/)
            end
        end
    else
        it "has #{iface ? iface + ' ' : ''}IPv4 without metric" do
            vm_nic = iface ? iface : @info[:vm_nic]

            if image =~ /freebsd/i
                cmd = @info[:vm].ssh("ifconfig #{vm_nic}")
                expect(cmd.success?).to be(true)

                if metric6 && cmd.stdout =~ /metric\s+#{metric6}(\s|$)/
                    skip('Found IPv6 metric on FreeBSD')
                else
                    expect(cmd.stdout).to match(/metric 0(\s|$)/)
                end
            else
                cmd = @info[:vm].ssh("ip r s dev #{vm_nic}")
                expect(cmd.success?).to be(true)

                # Ignore default metrics 0 (IPv4), 1 (IPv6)
                # (some set wrongly metric 1 (from IPv6) even for IPv4), TODO unify
                if cmd.stdout !~ /(default|0\.0\.0\.0\/\d+) via .* metric\s+(0|1)(\s|$)/
                    expect(cmd.stdout).not_to match(/(default|0\.0\.0\.0\/\d+) via .* metric\s+\d+/)
                end
            end
        end
    end

    if metric6
        it "has #{iface ? iface + ' ' : ''}IPv6 metric #{metric6}" do
            vm_nic = iface ? iface : @info[:vm_nic]

            if image =~ /freebsd/i
                cmd = @info[:vm].ssh("ifconfig #{vm_nic}")
                expect(cmd.success?).to be(true)

                if metric && metric != metric6 && cmd.stdout =~ /metric\s+#{metric}(\s|$)/
                    # On FreeBSD metrics are configured per interface and are
                    # respected only by dedicated daemons (routed).
                    skip('Found IPv4 metric on FreeBSD')
                else
                    expect(cmd.stdout).to match(/metric\s+#{metric6}(\s|$)/)
                end
            else
                cmd = @info[:vm].ssh("ip -6 r s dev #{vm_nic}")
                expect(cmd.success?).to be(true)
                expect(cmd.stdout).to match(/(default|::|::\/0) via .* metric\s+#{metric6}/)
            end
        end
    else
        it "has #{iface ? iface + ' ' : ''}IPv6 without metric" do
            vm_nic = iface ? iface : @info[:vm_nic]

            if image =~ /freebsd/i
                cmd = @info[:vm].ssh("ifconfig #{vm_nic}")
                expect(cmd.success?).to be(true)

                if metric && cmd.stdout =~ /metric\s+#{metric}(\s|$)/
                    skip('Found IPv4 metric on FreeBSD')
                else
                    expect(cmd.stdout).to match(/metric 0(\s|$)/)
                end
            else
                cmd = @info[:vm].ssh("ip -6 r s dev #{vm_nic}")
                expect(cmd.success?).to be(true)

                # Ignore default metrics
                if cmd.stdout !~ /(default|::|::\/0) via .* metric\s+(1|1024)(\s|$)/
                    expect(cmd.stdout).not_to match(/(default|::|::\/0) via .* metric\s+\d+/)
                end
            end
        end
    end
end

# Checks if selected interface has specific MTU
shared_examples_for "context_linux_network_verify_mtu" do |image, iface, mtu = 1500, mtu6 = mtu|
    it "has #{iface ? iface + ' ' : ''}MTU #{mtu}" do
        vm_nic = iface ? iface : @info[:vm_nic]

        cmd = @info[:vm].ssh("ip link show dev #{vm_nic}")
        cmd = @info[:vm].ssh("ifconfig #{vm_nic}") unless cmd.success?
        expect(cmd.success?).to be(true)
        expect(cmd.stdout).to match(/mtu\s+#{mtu}(\s|$)/)
    end

    if mtu6
        it "has #{iface ? iface + ' ' : ''}IPv6 MTU #{mtu6}" do
            skip 'Unsupported on this platform' if image =~ /(freebsd)/i

            vm_nic = iface ? iface : @info[:vm_nic]
            cmd = @info[:vm].ssh("cat /proc/sys/net/ipv6/conf/#{vm_nic}/mtu")
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).to eq("#{mtu6}")
        end
    end
end

# Common simple networking tests separated from common1
shared_examples_for 'context_linux_network_common' do |image, hv|
    it 'checks NICs in ONE and guest' do
        # calculate NICs in ONE
        @info[:nic_count] = 0
        @info[:vm].xml.each('TEMPLATE/NIC') { @info[:nic_count] += 1 }
        expect(@info[:nic_count]).to be > 0

        # calculate NICs in guest
        cmd = @info[:vm].ssh('test -d /sys/class/net && ls -d /sys/class/net/* | xargs -n1 readlink -f | grep -v virtual | xargs -n1 basename')
        #TODO: this should be redone better, e.g.: ip link show type veth
        cmd = @info[:vm].ssh("ip link | grep -F ': <' | awk -F: '\\$3!~/LOOPBACK/ { print \\$2 }' | grep -v docker") if cmd.fail?
        cmd = @info[:vm].ssh("ifconfig -a | awk -F: '\\$2~/flags=/ && \\$2!~/LOOPBACK/ { print \\$1 }'") if cmd.fail?
        expect(cmd.success?).to be(true)

        expect(cmd.stdout.lines.count).to eq(@info[:nic_count])
        nic_prefix = guess_nic_prefix(image, @info[:vm].xml['TEMPLATE/NIC[last()]/MODEL'], hv)
        expect(cmd.stdout.lines).to all(match(/^\s*#{nic_prefix}\d+(@if\d+)?$/))
    end

    it 'attaches NIC (metric 200, MTU 1499)' do
        # use the same vnet as the previous NIC (it should have a gateway)
        network_id = @info[:vm].xml['TEMPLATE/NIC[last()]/NETWORK_ID']
        cli_action_wrapper_with_tmpfile("onevm nic-attach #{@info[:vm_id]} --file", <<-EOT, true)
            NIC = [
              NETWORK_ID = #{network_id},
              METRIC = 200,
              GUEST_MTU = 1499
            ]
        EOT

        @info[:vm].running?

        @info[:nic_id] = @info[:vm].xml['TEMPLATE/NIC[last()]/NIC_ID']
        @info[:nic_ip] = @info[:vm].xml['TEMPLATE/NIC[last()]/IP']
        expect(@info[:nic_ip]).not_to be_empty
        expect(@info[:nic_ip]).not_to eq(@info[:vm].ip)
        expect(@info[:vm].xml['TEMPLATE/NIC[last()]/METRIC']).to eq('200')
        expect(@info[:vm].xml['TEMPLATE/NIC[last()]/GUEST_MTU']).to eq('1499')
    end

    it 'pings attached NIC' do
        # NOTE: it may happen that when NIC and NIC alias are added
        # without proper wait between CLI operations, the second
        # recontextualization is not done when first one is still running

        # ping newly configured IP
        wait_loop(:timeout => 150) do
            @info[:vm].wait_ping(@info[:nic_ip])
            @info[:vm].reachable?
        end
    end

    include_examples 'context_linux_contextualized'

    ### Wait until interfaces are configured ###

    # Skip Ubuntu 20.04, networkd takes extremely long to configure eth0
    unless image =~ /^ubuntu2004/i
        include_examples 'context_linux_netcfg_type_service_configured',
                         "#{guess_nic_prefix(image, nil, hv)}0"
    end

    include_examples 'context_linux_netcfg_type_service_configured',
                     "#{guess_nic_prefix(image, nil, hv)}1"

    ### Verify metrics on both NICs ###

    include_examples 'context_linux_network_verify_metric', image,
                     "#{guess_nic_prefix(image, nil, hv)}0"

    # Legacy Debian-like fails to add same IPv6 gateway and ignores metric
    unless image =~ /^(debian8|ubuntu14)/i
        include_examples 'context_linux_network_verify_metric', image,
                         "#{guess_nic_prefix(image, nil, hv)}1",
                         '200'
    end

    ### Verify MTUs on both NICs ###

    include_examples 'context_linux_network_verify_mtu', image,
                     "#{guess_nic_prefix(image, nil, hv)}0"

    include_examples 'context_linux_network_verify_mtu', image,
                     "#{guess_nic_prefix(image, nil, hv)}1",
                     1499

    it 'has new NIC in guest' do
        # calculate new NICs in ONE
        new_nic_count = 0
        @info[:vm].xml.each('TEMPLATE/NIC') { new_nic_count += 1 }
        expect(new_nic_count).to eq(@info[:nic_count] + 1)
        @info[:nic_count] = new_nic_count

        # calculate NICs in guest
        @info[:vm].reachable?
        cmd = @info[:vm].ssh('test -d /sys/class/net && ls -d /sys/class/net/* | xargs -n1 readlink -f | grep -v virtual | xargs -n1 basename')
        #TODO: this should be redone better, e.g.: ip link show type veth
        cmd = @info[:vm].ssh("ip link | grep -F ': <' | awk -F: '\\$3!~/LOOPBACK/ { print \\$2 }' | grep -v docker") if cmd.fail?
        cmd = @info[:vm].ssh("ifconfig -a | awk -F: '\\$2~/flags=/ && \\$2!~/LOOPBACK/ { print \\$1 }'") if cmd.fail?
        expect(cmd.success?).to be(true)

        expect(cmd.stdout.lines.count).to eq(@info[:nic_count])
        nic_prefix = guess_nic_prefix(image, @info[:vm].xml['TEMPLATE/NIC[last()]/MODEL'], hv)
        expect(cmd.stdout.lines).to all(match(/^\s*#{nic_prefix}\d+(@if\d+)?$/))
    end

    it 'attaches NIC alias' do
        nic_name = @info[:vm].xml['TEMPLATE/NIC[1]/NAME']
        cli_action("onevm nic-attach #{@info[:vm_id]} --network '#{@info[:network_attach]}' --alias #{nic_name}")
        @info[:vm].running?

        @info[:alias_id] = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/NIC_ID']
        @info[:alias_ip] = @info[:vm].xml['TEMPLATE/NIC_ALIAS[last()]/IP']
        expect(@info[:alias_ip]).not_to be_empty
        expect(@info[:alias_ip]).not_to eq(@info[:vm].ip)
    end

    it 'pings attached NIC alias' do
        # ping newly configured IP
        wait_loop(:timeout => 120) do
            @info[:vm].wait_ping(@info[:alias_ip])
            @info[:vm].reachable?
        end
    end

    include_examples 'context_linux_contextualized'

    it 'detaches NIC alias' do
        cli_action("onevm nic-detach #{@info[:vm_id]} #{@info[:alias_id]}")
        @info[:vm].running?
    end

    it "doesn't ping detached NIC alias" do
        wait_loop(:timeout => 120) do
            @info[:vm].wait_ping
            @info[:vm].wait_no_ping(@info[:alias_ip])
            @info[:vm].wait_ping
            @info[:vm].wait_no_ping(@info[:alias_ip])
        end
    end

    it "doesn't have new NIC in guest" do
        # calculate new NICs in ONE
        new_nic_count = 0
        @info[:vm].xml.each('TEMPLATE/NIC') { new_nic_count += 1 }
        expect(new_nic_count).to eq(@info[:nic_count])

        # calculate NICs in guest
        @info[:vm].reachable?
        cmd = @info[:vm].ssh('test -d /sys/class/net && ls -d /sys/class/net/* | xargs -n1 readlink -f | grep -v virtual | xargs -n1 basename')
        #TODO: this should be redone better, e.g.: ip link show type veth
        cmd = @info[:vm].ssh("ip link | grep -F ': <' | awk -F: '\\$3!~/LOOPBACK/ { print \\$2 }' | grep -v docker") if cmd.fail?
        cmd = @info[:vm].ssh("ifconfig -a | awk -F: '\\$2~/flags=/ && \\$2!~/LOOPBACK/ { print \\$1 }'") if cmd.fail?
        expect(cmd.success?).to be(true)

        expect(cmd.stdout.lines.count).to eq(@info[:nic_count])
        nic_prefix = guess_nic_prefix(image, @info[:vm].xml['TEMPLATE/NIC[last()]/MODEL'], hv)
        expect(cmd.stdout.lines).to all(match(/^\s*#{nic_prefix}\d+(@if\d+)?$/))
    end

    include_examples 'context_linux_contextualized'

    # TODO: Parse BSD static routing
    it 'VM has static route' do
        vm = @info[:vm]

        skip 'Missing route parsing for BSD' if vm.os_type == 'FreeBSD'

        # defined in bootstrap.yaml
        test_routes = ['8.8.4.4/32 via 192.168.150.2', '1.0.0.1/32 via 192.168.150.2']

        sleep(5) # netplan/NM quirks

        test_routes.each do |route|
            # remove '/32' part
            route_seen = route.sub(/\/\d* via/, ' via')

            expect(vm.routes.include?(route_seen)).to be(true)
        end
    end

    # Only the route is checked if ONEGATE_ENDPOINT is set. onegate is not interacted with
    it 'VM has ONEGATE Proxy static route' do
        vm = @info[:vm]

        skip 'Missing route parsing for BSD' if vm.os_type == 'FreeBSD'

        vm.poweroff

        onegate_host='169.254.16.9'
        test_route="#{onegate_host} dev eth0"
        onegate_endpoint = "ONEGATE_ENDPOINT=\"http://#{onegate_host}:5030\""
        vm.recontextualize(onegate_endpoint)

        vm.resume
        vm.reachable?

        expect(vm.routes.include?(test_route)).to be(true)
    end

    it 'detach NIC' do
        cmd = 'cat /tmp/start_script3'
        @info[:context_trigger_count] = @info[:vm].ssh(cmd).stdout.strip.lines.length

        cli_action("onevm nic-detach #{@info[:vm_id]} #{@info[:nic_id]}")
        @info[:vm].running?
    end

    it 'triggered recontextualization after detach NIC' do
        if image =~ /\b(alma|centos|rhel|alt|rocky|oracle)\b/
            problem = 'one-context does not retrigger after detaching a NIC on the following distros'
            problem << 'wordpress alt10 rocky8 c8 alma8 rhel9 rhel8 rhel7'
            problem << 'After the NIC is detached, the configuration remains'
            problem << 'This is not necessarily a problem since the NIC does not exist'
            problem << 'a new NIC or update of the same NIC will retrigger the context'
            problem << 'However, it is still supposed to trigger.'

            skip problem
        end

        @info[:vm].wait_context
    end

    it "doesn't ping detached NIC" do
        @info[:vm].wait_no_ping(@info[:nic_ip])
    end

    # Verify NIC metrics
    metric = "#{guess_nic_prefix(image, nil, hv)}0"
    include_examples 'context_linux_network_verify_metric', image, metric
end

###########################################################
#
# Independent Shared Examples
#

# None?
