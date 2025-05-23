# frozen_string_literal: true

require_relative '../vrouter.rb'
require_relative 'execute.rb'

module Service
module HAProxy
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_HAPROXY_ENABLED         = env :ONEAPP_VNF_HAPROXY_ENABLED, 'NO'
    ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED = env :ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED, 'NO'

    ONEAPP_VNF_HAPROXY_REFRESH_RATE = env :ONEAPP_VNF_HAPROXY_REFRESH_RATE, '30'

    ONEAPP_VNF_HAPROXY_INTERFACES = env :ONEAPP_VNF_HAPROXY_INTERFACES, '' # nil -> none, empty -> all

    ONEAPP_VNF_LB_ONEGATE_API = env :ONEAPP_VNF_LB_ONEGATE_API, 'auto'

    def install(initdir: '/etc/init.d')
        msg :info, 'HAProxy::install'

        puts bash 'apk --no-cache add haproxy ruby'

        file "#{initdir}/one-haproxy", <<~SERVICE, mode: 'u=rwx,go=rx'
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::HAProxy.execute"

            command_background="YES"
            pidfile="/run/$RC_SVCNAME.pid"

            output_log="/var/log/one-appliance/one-haproxy.log"
            error_log="/var/log/one-appliance/one-haproxy.log"

            depend() {
                after net firewall keepalived
            }

            start_pre() {
                rc-service haproxy start --nodeps
            }

            stop_post() {
                rc-service haproxy stop --nodeps
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/haproxy', confdir: '/etc/conf.d')
        msg :info, 'HAProxy::configure'

        unless ONEAPP_VNF_HAPROXY_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        file "#{confdir}/haproxy", <<~CONFIG, mode: 'u=rw,g=r,o=', overwrite: true
            HAPROXY_CONF="#{basedir}"
        CONFIG

        file "#{basedir}/haproxy.cfg", <<~CONFIG, mode: 'u=rw,g=r,o=', overwrite: true
            global
                log /dev/log local0
                log /dev/log local1 notice
                stats socket /var/run/haproxy.sock mode 666 level admin
                stats timeout 120s
                user haproxy
                group haproxy
                daemon

            defaults
                log global
                retries 3
                maxconn 2000
                timeout connect 5s
                timeout client 120s
                timeout server 120s
        CONFIG

        # Ensure HAProxy starts without any effective config, otherwise it'd be possible
        # for it to fail when for example re-contexting removed a VIP.
        file "#{basedir}/servers.cfg", '', mode: 'u=rw,g=r,o=', overwrite: true
    end

    def toggle(operations)
        operations.each do |op|
            msg :debug, "HAProxy::toggle([:#{op}])"
            case op
            when :reload
                puts bash 'rc-service --ifstarted haproxy reload'
            when :disable
                puts bash 'rc-update del haproxy default ||:'
                puts bash 'rc-update del one-haproxy default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-haproxy #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'HAProxy::bootstrap'
    end
end
end
