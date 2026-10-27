# frozen_string_literal: true

require 'erb'
require 'uri'
require_relative '../vrouter.rb'

module Service
module MgmtVRF
    extend self

    DEPENDS_ON = %w[]

    VRF_NAME  = 'mgmt'
    VRF_TABLE = 1000
    RULE_PREF = 100

    ONEAPP_VNF_MGMT_VRF_ENABLED = env :ONEAPP_VNF_MGMT_VRF_ENABLED, 'YES'

    IPV4_RE = /\A(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\z/

    def install(initdir: '/etc/init.d')
        msg :info, 'MgmtVRF::install'

        puts bash 'apk --no-cache add iproute2 ruby'

        file "#{initdir}/one-mgmt-vrf", <<~SERVICE, mode: 'u=rwx,go=rx'
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            depend() {
                after sysctl net
            }

            start() {
                $command $command_args -e Service::MgmtVRF.execute 1>>/var/log/one-appliance/one-mgmt-vrf.log 2>&1
            }

            stop() {
                $command $command_args -e Service::MgmtVRF.cleanup 1>>/var/log/one-appliance/one-mgmt-vrf.log 2>&1
            }
        SERVICE

        toggle [:update]
    end

    def configure
        msg :info, 'MgmtVRF::configure'

        unless ONEAPP_VNF_MGMT_VRF_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        toggle [:enable, :restart]
    end

    # NOTE: The NIC that OpenNebula marks as VROUTER_MANAGEMENT moves into its own VRF, so its default
    #       route lives in a separate table and does not collide with the one of the main table.
    #       The gateway ends up in a shell command, so anything but a plain dotted quad is rejected.
    def execute(basedir: '/etc/sysctl.d')
        msg :info, 'MgmtVRF::execute'

        nics = ONEAPP_VNF_MGMT_VRF_ENABLED ? detect_mgmt_nics.sort_by { |nic| nic[/\d+/].to_i } : []
        return if nics.empty?

        routes  = default_routes nics
        statics = static_routes nics
        addrs6  = ip6_addresses nics
        routes6 = default_routes6 nics
        leak    = onegate_rule
        others  = other_default_routes nics

        # NOTE: Let sshd and other listeners of the default VRF accept connections on the NIC of the VRF.
        file "#{basedir}/97-MgmtVRF.conf", <<~SYSCTL, mode: 'u=rw,go=r', overwrite: true
            net.ipv4.tcp_l3mdev_accept = 1
            net.ipv4.udp_l3mdev_accept = 1
        SYSCTL

        bash ERB.new(<<~SCRIPT, trim_mode: '-').result(binding)
            if ! ip link show '<%= VRF_NAME %>' >/dev/null 2>&1; then
                ip link add '<%= VRF_NAME %>' type vrf table <%= VRF_TABLE %>
            fi
            ip link set '<%= VRF_NAME %>' up
            <%- nics.each do |nic| -%>
            ip link set '<%= nic %>' master '<%= VRF_NAME %>'
            <%- end -%>
            <%- addrs6.each do |nic, addrs| -%>
            <%- addrs.each do |addr| -%>
            ip -6 addr replace '<%= addr %>' dev '<%= nic %>'
            <%- end -%>
            <%- end -%>
            <%- routes.each do |nic, gateway| -%>
            ip route replace default via '<%= gateway %>' dev '<%= nic %>' table <%= VRF_TABLE %>
            <%- end -%>
            <%- routes6.each do |nic, gateway| -%>
            ip -6 route replace default via '<%= gateway %>' dev '<%= nic %>' onlink table <%= VRF_TABLE %>
            <%- end -%>
            <%- statics.each do |nic, dst, gateway| -%>
            ip route replace '<%= dst %>' via '<%= gateway %>' dev '<%= nic %>' table <%= VRF_TABLE %>
            <%- end -%>
            <%- others[:v4].each do |nic, gateway, metric| -%>
            <%= default_if_missing nic, gateway, metric: metric %>
            <%- end -%>
            <%- others[:v6].each do |nic, gateway| -%>
            <%= default_if_missing nic, gateway, v6: true %>
            <%- end -%>
            <%- unless leak.nil? -%>
            <%= leak[:del] %>
            <%= leak[:add] %>
            <%- end -%>
        SCRIPT

        toggle [:reload]
    end

    def cleanup(basedir: '/etc/sysctl.d')
        msg :info, 'MgmtVRF::cleanup'

        leak    = onegate_rule
        nics    = detect_mgmt_nics.sort_by { |nic| nic[/\d+/].to_i }
        routes  = default_routes nics
        routes6 = default_routes6 nics
        statics = static_routes nics
        addrs6  = ip6_addresses nics
        others  = other_default_routes nics

        # NOTE: Deleting the VRF device releases its NICs, and the routes of the VRF table are gone with it.
        #       one-context does not run again at this point, so the routes of the management NICs, and the
        #       default routes of the other NICs, go back into the main table here, where they are missing.
        bash ERB.new(<<~SCRIPT, trim_mode: '-').result(binding)
            if ip link show '<%= VRF_NAME %>' >/dev/null 2>&1; then
                ip link del '<%= VRF_NAME %>'
            fi
            <%- unless leak.nil? -%>
            <%= leak[:del] %>
            <%- end -%>
            <%- addrs6.each do |nic, addrs| -%>
            <%- addrs.each do |addr| -%>
            ip -6 addr replace '<%= addr %>' dev '<%= nic %>'
            <%- end -%>
            <%- end -%>
            <%- routes.each do |nic, gateway| -%>
            <%= default_if_missing nic, gateway, metric: main_metric(nic) %>
            <%- end -%>
            <%- routes6.each do |nic, gateway| -%>
            <%= default_if_missing nic, gateway, v6: true, onlink: true %>
            <%- end -%>
            <%- statics.each do |nic, dst, gateway| -%>
            ip route replace '<%= dst %>' via '<%= gateway %>' dev '<%= nic %>'
            <%- end -%>
            <%- others[:v4].each do |nic, gateway, metric| -%>
            <%= default_if_missing nic, gateway, metric: metric %>
            <%- end -%>
            <%- others[:v6].each do |nic, gateway| -%>
            <%= default_if_missing nic, gateway, v6: true %>
            <%- end -%>
        SCRIPT

        FileUtils.rm_f "#{basedir}/97-MgmtVRF.conf"
    end

    # NOTE: The appliance talks to OneGate from the default VRF, which cannot reach hosts behind the
    #       management NIC any more. A policy rule sends the traffic for the OneGate address to the VRF
    #       table, and the lookup falls through to the main table when the VRF has no route for it.
    #       Only an IP literal is accepted, since the address ends up in a shell command.
    def onegate_rule
        host = URI.parse(env(:ONEGATE_ENDPOINT, '').to_s).hostname.to_s

        if IPV4_RE.match?(host)
            ip, family, plen = host, 'ip', 32
        elsif valid_ipv6?(host)
            ip, family, plen = host, 'ip -6', 128
        else
            return nil
        end

        spec = "pref #{RULE_PREF} to '#{ip}/#{plen}' lookup #{VRF_TABLE}"

        { del: "#{family} rule del #{spec} 2>/dev/null ||:", add: "#{family} rule add #{spec}" }
    rescue URI::InvalidURIError
        nil
    end

    # NOTE: one-context adds the default route of every NIC with `ip route add`, so the first NIC wins and
    #       the gateways of the others are never installed. With the gateway of the management NIC in the
    #       VRF, the gateways of the other NICs are applied the way one-context would have done it (an
    #       existing default route with the same metric stays, hence the harmless failure).
    def other_default_routes(mgmt_nics)
        nics = (detect_nics - mgmt_nics).sort_by { |nic| nic[/\d+/].to_i }

        { v4: nics.map { |nic| other_gateway4(nic) }.compact, v6: nics.map { |nic| other_gateway6(nic) }.compact }
    end

    def other_gateway4(nic)
        gateway = env("#{nic.upcase}_GATEWAY", '').to_s
        metric  = env("#{nic.upcase}_METRIC", '').to_s

        return nil if gateway.empty?

        unless IPV4_RE.match?(gateway)
            msg :error, "MgmtVRF::execute: invalid #{nic.upcase}_GATEWAY #{gateway[0, 40].inspect} for #{nic}, no default route"
            return nil
        end

        unless metric.empty? || /\A\d{1,9}\z/.match?(metric)
            msg :error, "MgmtVRF::execute: invalid #{nic.upcase}_METRIC #{metric[0, 40].inspect} for #{nic}, no default route"
            return nil
        end

        [nic, gateway, metric.empty? ? nil : metric.to_i]
    end

    def other_gateway6(nic)
        index   = nic[/\d+/]
        gateway = env("ETH#{index}_IP6_GATEWAY", '').to_s
        gateway = env("ETH#{index}_GATEWAY6", '').to_s if gateway.empty?

        return nil if gateway.empty?

        unless valid_ipv6?(gateway)
            msg :error, "MgmtVRF::execute: invalid ETH#{index}_GATEWAY6 #{gateway[0, 40].inspect} for #{nic}, no IPv6 default route"
            return nil
        end

        [nic, gateway]
    end

    # NOTE: Moving a NIC into a VRF drops its static routes (ETH<n>_ROUTES, "<destination> via <gateway>",
    #       separated by commas), so they are put into the VRF table next to the default route.
    #       Only an IPv4 destination (with an optional prefix length) and an IPv4 gateway are accepted.
    def static_routes(nics)
        nics.flat_map do |nic|
            env("#{nic.upcase}_ROUTES", '').to_s.split(',').map(&:strip).reject(&:empty?).filter_map do |route|
                dst, via, gateway, extra = route.split
                prefix = dst.to_s.split('/')

                if via == 'via' && extra.nil? && IPV4_RE.match?(prefix[0].to_s) && IPV4_RE.match?(gateway.to_s) &&
                   (prefix.size == 1 || (prefix.size == 2 && /\A(?:[0-9]|[12][0-9]|3[0-2])\z/.match?(prefix[1])))
                    [nic, dst, gateway]
                else
                    msg :error, "MgmtVRF: invalid #{nic.upcase}_ROUTES entry #{route[0, 40].inspect} for #{nic}, route skipped"
                    nil
                end
            end
        end
    end

    # NOTE: A default route that one-context installed (for example with a metric) stays as it is: the
    #       route of a NIC is only added when the NIC has no default route in the main table.
    def default_if_missing(nic, gateway, metric: nil, v6: false, onlink: false)
        family = v6 ? 'ip -6' : 'ip'
        extra  = (metric.nil? ? '' : " metric #{metric}") + (onlink ? ' onlink' : '')

        "#{family} route show dev '#{nic}' 2>/dev/null | grep -q '^default' || " \
            "#{family} route add default via '#{gateway}' dev '#{nic}'#{extra} 2>/dev/null ||:"
    end

    def main_metric(nic)
        metric = env("#{nic.upcase}_METRIC", '').to_s

        /\A\d{1,9}\z/.match?(metric) ? metric.to_i : nil
    end

    def default_routes(nics)
        nics.each_with_object({}) do |nic, acc|
            gateway = env("#{nic.upcase}_GATEWAY", '').to_s

            next if gateway.empty?

            unless IPV4_RE.match?(gateway)
                msg :error, "MgmtVRF::execute: invalid #{nic.upcase}_GATEWAY #{gateway[0, 40].inspect} for #{nic}, no default route in the VRF"
                next
            end

            acc[nic] = gateway
        end
    end

    # NOTE: Moving a NIC into a VRF flushes its IPv6 addresses, so the static ones are put back the same
    #       way one-context applies them: ETH<n>_IP6 (or ETH<n>_IPV6) with ETH<n>_IP6_PREFIX_LENGTH
    #       (64 by default) and ETH<n>_IP6_ULA (always a /64).
    def ip6_addresses(nics)
        nics.each_with_object({}) do |nic, acc|
            index = nic[/\d+/]
            addrs = []

            addr = env("ETH#{index}_IP6", '').to_s
            addr = env("ETH#{index}_IPV6", '').to_s if addr.empty?
            plen = env("ETH#{index}_IP6_PREFIX_LENGTH", '64').to_s

            if !addr.empty?
                if !valid_ipv6?(addr)
                    msg :error, "MgmtVRF::execute: invalid ETH#{index}_IP6 #{addr[0, 40].inspect} for #{nic}, no IPv6 address restored"
                elsif !/\A\d{1,3}\z/.match?(plen) || !(1..128).cover?(plen.to_i)
                    msg :error, "MgmtVRF::execute: invalid ETH#{index}_IP6_PREFIX_LENGTH #{plen[0, 40].inspect} for #{nic}, no IPv6 address restored"
                else
                    addrs << "#{addr}/#{plen.to_i}"
                end
            end

            ula = env("ETH#{index}_IP6_ULA", '').to_s

            unless ula.empty?
                if valid_ipv6?(ula)
                    addrs << "#{ula}/64"
                else
                    msg :error, "MgmtVRF::execute: invalid ETH#{index}_IP6_ULA #{ula[0, 40].inspect} for #{nic}, no ULA address restored"
                end
            end

            acc[nic] = addrs unless addrs.empty?
        end
    end

    def default_routes6(nics)
        nics.each_with_object({}) do |nic, acc|
            index   = nic[/\d+/]
            gateway = env("ETH#{index}_IP6_GATEWAY", '').to_s
            gateway = env("ETH#{index}_GATEWAY6", '').to_s if gateway.empty?

            next if gateway.empty?

            unless valid_ipv6?(gateway)
                msg :error, "MgmtVRF::execute: invalid ETH#{index}_GATEWAY6 #{gateway[0, 40].inspect} for #{nic}, no IPv6 default route in the VRF"
                next
            end

            acc[nic] = gateway
        end
    end

    # NOTE: The address ends up in a shell command, so only plain IPv6 notation is accepted (no prefix
    #       length, no zone id, no embedded IPv4 part).
    def valid_ipv6?(address)
        return false unless /\A[0-9a-fA-F:]+\z/.match?(address)

        IPAddr.new(address).ipv6?
    rescue IPAddr::Error
        false
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "MgmtVRF::toggle([:#{op}])"
            case op
            when :enable
                puts bash 'rc-update add one-mgmt-vrf default'
            when :disable
                puts bash 'rc-update del one-mgmt-vrf default ||:'
            when :update
                puts bash 'rc-update -u'
            when :reload
                puts bash 'sysctl --system'
            else
                puts bash "rc-service one-mgmt-vrf #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'MgmtVRF::bootstrap'
    end
end
end
