require_relative '../linux/ip_method' # TODO: Mess

###########################################################
#
# Main Tests
#

shared_examples_for 'context_windows_ip_methods' do |image, hv, prefix, context|
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
        ['', '', 'public', false, true, true, true, true],
        ['static', 'disable', 'public', false, true, false, true, true],
        ['dhcp',   'auto',     'dhcp',   true,  true,  true, false, true],
        ['dhcp',   'dhcp',     'dhcp',   true,  true,  true, false, true]
    ].each do |t|
        # test NIC configuration via coldplug and hotplug
        [false, true].each do |hotplug|
            test_name = "with METHOD='#{t[0]}', IP6_METHOD='#{t[1]}'"
            test_name << ' on DHCP-only network' if t[3]
            test_name = 'hotplugged ' + test_name if hotplug

            context test_name do
                include_examples 'context_linux_ip_method',
                                 image, hv, prefix, context,
                                 '', '', 'windows',
                                 hotplug, *t
            end
        end
    end
end
