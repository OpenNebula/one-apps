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

        routes = default_routes nics

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
            <%- routes.each do |nic, gateway| -%>
            ip route replace default via '<%= gateway %>' dev '<%= nic %>' table <%= VRF_TABLE %>
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
