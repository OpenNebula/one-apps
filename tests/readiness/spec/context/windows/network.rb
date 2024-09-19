############################################################
#
# Tests Snippets
#

# Checks if selected interface has specific metric or no metric at all
shared_examples_for 'context_windows_network_verify_metric' do |_image, iface, metric = nil, metric6 = metric|
    it "has #{iface ? iface + ' ' : ''}IPv4 with metric ? --> #{metric}" do
        vm_nic = iface ? iface : @info[:vm_nic]

        cmd = "netsh interface ipv4 show addresses \\\"#{vm_nic}\\\" | findstr /C:\\\"Gateway Metric\\\""
        o, _e, s = @info[:vm].winrm(cmd)
        expect(s).to be(true)

        if metric
            expect(o.split(' ').last).to eq(metric)
        else
            expect(o.split(' ').last).to eq(1)
        end
    end

    it "has #{iface ? iface + ' ' : ''}IPv6 with metric ? --> #{metric6}" do
        cmd = 'netsh interface ipv6 show route'
        o, _e, s = @info[:vm].winrm(cmd)
        expect(s).to be(true)

        if metric6
            expect(o.include?(metric6)).to be(true)
        else
            host_metric = o.lines[3].split(' ')[2].to_i
            expect(host_metric).to eq(256)
        end
    end
end

# Checks if selected interface has specific MTU
shared_examples_for 'context_windows_network_verify_mtu' do |_image, iface, mtu = 1500, mtu6 = mtu|
    it "has #{iface ? iface + ' ' : ''}MTU #{mtu}" do
        vm_nic = iface ? iface : @info[:vm_nic]

        cmd = "netsh interface ipv4 show interfaces \\\"#{vm_nic}\\\""
        o, _e, s = @info[:vm].winrm(cmd)
        expect(s).to be(true)

        expect(o).to match(/Link MTU\s*:\s*#{mtu} bytes/)
    end

    if mtu6
        it "has #{iface ? iface + ' ' : ''}IPv6 MTU #{mtu6}" do
            vm_nic = iface ? iface : @info[:vm_nic]

            cmd = "netsh interface ipv6 show interfaces \\\"#{vm_nic}\\\""
            o, _e, s = @info[:vm].winrm(cmd)
            expect(s).to be(true)

            expect(o).to match(/Link MTU\s*:\s*#{mtu} bytes/)
        end
    end
end
