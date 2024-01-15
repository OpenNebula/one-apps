# frozen_string_literal: true

require_relative '../vrouter.rb'
require_relative 'execute.rb'

module Service
module SDNAT4
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_SDNAT4_ENABLED = env :ONEAPP_VNF_SDNAT4_ENABLED, 'NO'

    ONEAPP_VNF_SDNAT4_REFRESH_RATE = env :ONEAPP_VNF_SDNAT4_REFRESH_RATE, '30'

    ONEAPP_VNF_SDNAT4_INTERFACES = env :ONEAPP_VNF_SDNAT4_INTERFACES, nil # nil -> none, empty -> all

    def install(initdir: '/etc/init.d')
        msg :info, 'SDNAT4::install'

        puts bash 'apk --no-cache add iproute2 iptables-openrc ruby'

        file "#{initdir}/one-sdnat4", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::SDNAT4.execute"

            command_background="yes"
            pidfile="/run/$RC_SVCNAME.pid"

            output_log="/var/log/one-appliance/one-sdnat4.log"
            error_log="/var/log/one-appliance/one-sdnat4.log"

            depend() {
                after net firewall keepalived
            }

            stop_post() {
                $command -r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::SDNAT4.cleanup 1>>$output_log 2>>$error_log
            }
        SERVICE

        toggle [:update]
    end

    def configure
        msg :info, 'SDNAT4::configure'

        if ONEAPP_VNF_SDNAT4_ENABLED
            # Add dedicated SNAT4 chain.
            puts bash(<<~IPTABLES)
                iptables -t nat -nL SNAT4 || iptables -t nat -N SNAT4
                iptables -t nat -C POSTROUTING -j SNAT4 || iptables -t nat -I POSTROUTING 1 -j SNAT4
            IPTABLES

            # Add dedicated DNAT4 chain.
            puts bash(<<~IPTABLES)
                iptables -t nat -nL DNAT4 || iptables -t nat -N DNAT4
                iptables -t nat -C PREROUTING -j DNAT4 || iptables -t nat -I PREROUTING 1 -j DNAT4
            IPTABLES

            toggle [:save]
        else
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
        end
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "SDNAT4::toggle([:#{op}])"
            case op
            when :save
                puts bash 'rc-service iptables save'
            when :reload
                puts bash 'rc-service --ifstarted iptables reload'
            when :disable
                puts bash 'rc-update del one-sdnat4 default ||:'
            when :update
                puts bash 'rc-update -u'
            when :start
                puts bash 'rc-service iptables start'
            else
                puts bash "rc-service one-sdnat4 #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'SDNAT4::bootstrap'
    end
end
end
