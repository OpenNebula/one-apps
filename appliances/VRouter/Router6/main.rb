# frozen_string_literal: true

require_relative '../vrouter.rb'

module Service
module Router6
    extend self

    DEPENDS_ON = %w[Service::Failover]

    # NOTE: Opt-in, unlike Router4: an IPv6 router that was not asked for would start to forward
    #       unfiltered IPv6 traffic (there is no IPv6 filtering or NAT66 in the appliance).
    ONEAPP_VNF_ROUTER6_ENABLED = env :ONEAPP_VNF_ROUTER6_ENABLED, 'NO'

    def install(initdir: '/etc/init.d')
        msg :info, 'Router6::install'

        puts bash 'apk --no-cache add procps ruby'

        file "#{initdir}/one-router6", <<~SERVICE, mode: 'u=rwx,go=rx'
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            depend() {
                after sysctl net firewall keepalived
            }

            start() {
                $command $command_args -e Service::Router6.execute 1>>/var/log/one-appliance/one-router6.log 2>&1
            }

            stop() {
                $command $command_args -e Service::Router6.cleanup 1>>/var/log/one-appliance/one-router6.log 2>&1
            }
        SERVICE

        toggle [:update]
    end

    def configure
        msg :info, 'Router6::configure'

        unless ONEAPP_VNF_ROUTER6_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end
    end

    def execute(basedir: '/etc/sysctl.d')
        msg :info, 'Router6::execute'

        nics = detect_nics

        file "#{basedir}/98-Router6.conf", render(routed: nics - detect_mgmt_nics, others: detect_mgmt_nics & nics),
             mode: 'u=rw,go=r', overwrite: true

        toggle [:reload]
    end

    def cleanup(basedir: '/etc/sysctl.d')
        msg :info, 'Router6::cleanup'

        file "#{basedir}/98-Router6.conf", render(routed: [], others: detect_nics),
             mode: 'u=rw,go=r', overwrite: true

        toggle [:reload]
    end

    # Linux forwards IPv6 only when net.ipv6.conf.all.forwarding is 1; writing a single interface
    # does not set it, and once it is 1 the router forwards between ALL interfaces. So the switch is
    # global, and the management NICs are only kept from being routers themselves.
    #
    # Enabled: accept_ra=2 on every NIC first (writing all.forwarding=1 turns router advertisement
    # acceptance off on the interfaces with accept_ra=1), then the global switch, then the
    # per-NIC zero on the management NICs. Disabled (nothing routed): everything is switched off.
    def render(routed:, others:)
        lines = if routed.empty?
            ['net.ipv6.conf.all.forwarding = 0', 'net.ipv6.conf.default.forwarding = 0'] +
                others.map { |nic| "net.ipv6.conf.#{nic}.forwarding = 0" }
        else
            (routed + others).map { |nic| "net.ipv6.conf.#{nic}.accept_ra = 2" } +
                ['net.ipv6.conf.default.forwarding = 0', 'net.ipv6.conf.all.forwarding = 1'] +
                others.map { |nic| "net.ipv6.conf.#{nic}.forwarding = 0" }
        end

        "#{lines.join("\n")}\n"
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "Router6::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del one-router6 default ||:'
            when :update
                puts bash 'rc-update -u'
            when :reload
                puts bash 'sysctl --system'
            else
                puts bash "rc-service one-router6 #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'Router6::bootstrap'
    end
end
end
