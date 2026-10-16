# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module MgmtVRF
    extend self

    DEPENDS_ON = %w[]

    VRF_NAME  = 'mgmt'
    VRF_TABLE = 1000

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
        addrs6  = ip6_addresses nics
        routes6 = default_routes6 nics

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
        SCRIPT

        toggle [:reload]
    end

    def cleanup(basedir: '/etc/sysctl.d')
        msg :info, 'MgmtVRF::cleanup'

        # NOTE: Deleting the VRF device releases its NICs.
        bash ERB.new(<<~SCRIPT, trim_mode: '-').result(binding)
            if ip link show '<%= VRF_NAME %>' >/dev/null 2>&1; then
                ip link del '<%= VRF_NAME %>'
            fi
        SCRIPT

        FileUtils.rm_f "#{basedir}/97-MgmtVRF.conf"
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
