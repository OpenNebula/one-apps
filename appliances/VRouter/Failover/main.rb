# frozen_string_literal: true

require_relative 'execute.rb'

module Service
module Failover
    extend self

    DEPENDS_ON = %w[Service::Keepalived]

    def install(initdir: '/etc/init.d')
        msg :info, 'Failover::install'

        puts bash 'apk --no-cache add ruby'

        file "#{initdir}/one-failover", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::Failover.execute"

            command_background="yes"
            pidfile="/run/$RC_SVCNAME.pid"

            output_log="/var/log/one-appliance/one-failover.log"
            error_log="/var/log/one-appliance/one-failover.log"

            depend() {
                need keepalived
                after net
            }
        SERVICE

        toggle [:disable, :update, :stop]
    end

    def configure
        msg :info, 'Failover::configure'

        puts bash <<~SCRIPT
            if [[ "$(virt-what)" != vmware ]]; then
                rc-update del open-vm-tools default && rc-update -u ||:
                rc-service open-vm-tools stop ||:
            fi
        SCRIPT

        toggle [:enable, :start]
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "Failover::toggle([:#{op}])"
            case op
            when :enable
                puts bash 'rc-update add one-failover default'
            when :disable
                puts bash 'rc-update del one-failover default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-failover #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'Failover::bootstrap'
    end
end
end
