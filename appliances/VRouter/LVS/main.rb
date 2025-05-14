# frozen_string_literal: true

require_relative '../vrouter.rb'
require_relative 'execute.rb'

module Service
module LVS
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_LB_ENABLED         = env :ONEAPP_VNF_LB_ENABLED, 'NO'
    ONEAPP_VNF_LB_ONEGATE_ENABLED = env :ONEAPP_VNF_LB_ONEGATE_ENABLED, 'NO'

    ONEAPP_VNF_LB_REFRESH_RATE  = env :ONEAPP_VNF_LB_REFRESH_RATE, '30'
    ONEAPP_VNF_LB_FWMARK_OFFSET = env :ONEAPP_VNF_LB_FWMARK_OFFSET, '10000'

    ONEAPP_VNF_LB_INTERFACES = env :ONEAPP_VNF_LB_INTERFACES, '' # nil -> none, empty -> all

    ONEAPP_VNF_LB_ONEGATE_API = env :ONEAPP_VNF_LB_ONEGATE_API, 'auto'

    def install(initdir: '/etc/init.d')
        msg :info, 'LVS::install'

        puts bash 'apk --no-cache add ipvsadm ruby'

        file "#{initdir}/one-lvs", <<~SERVICE, mode: 'u=rwx,go=rx'
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::LVS.execute"

            command_background="YES"
            pidfile="/run/$RC_SVCNAME.pid"

            output_log="/var/log/one-appliance/one-lvs.log"
            error_log="/var/log/one-appliance/one-lvs.log"

            depend() {
                after net firewall keepalived
            }

            stop_post() {
                $command -r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::LVS.cleanup 1>>$output_log 2>>$error_log
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/keepalived')
        msg :info, 'LVS::configure'

        unless ONEAPP_VNF_LB_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:disable, :reload]
            return
        end
    end

    def toggle(operations)
        operations.each do |op|
            msg :debug, "LVS::toggle([:#{op}])"
            case op
            when :reload
                puts bash 'rc-service --ifstarted keepalived reload'
            when :disable
                puts bash 'rc-update del one-lvs default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-lvs #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'LVS::bootstrap'
    end
end
end
