# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module Router4
    extend self

    DEPENDS_ON = %w[Service::Failover]

    VROUTER_ID = env :VROUTER_ID, nil

    ONEAPP_VNF_ROUTER4_ENABLED = env :ONEAPP_VNF_ROUTER4_ENABLED, (VROUTER_ID.nil? ? 'NO' : 'YES')

    ONEAPP_VNF_ROUTER4_INTERFACES = env :ONEAPP_VNF_ROUTER4_INTERFACES, '' # nil -> none, empty -> all

    def install(initdir: '/etc/init.d')
        msg :info, 'Router4::install'

        puts bash 'apk --no-cache add procps ruby'

        file "#{initdir}/one-router4", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            depend() {
                after sysctl net firewall keepalived
            }

            start() {
                $command $command_args -e Service::Router4.execute 1>>/var/log/one-appliance/one-router4.log 2>&1
            }

            stop() {
                $command $command_args -e Service::Router4.cleanup 1>>/var/log/one-appliance/one-router4.log 2>&1
            }
        SERVICE

        toggle [:update]
    end

    def configure
        msg :info, 'Router4::configure'

        unless ONEAPP_VNF_ROUTER4_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end
    end

    def execute(basedir: '/etc/sysctl.d')
        msg :info, 'Router4::execute'

        interfaces = parse_interfaces ONEAPP_VNF_ROUTER4_INTERFACES
        mgmt       = detect_mgmt_nics

        to_enable  = interfaces.keys - mgmt
        to_disable = detect_nics - to_enable

        file "#{basedir}/98-Router4.conf", ERB.new(<<~SYSCTL, trim_mode: '-').result(binding), mode: 'u=rw,go=r', overwrite: true
            net.ipv4.ip_forward = 0
            net.ipv4.conf.all.forwarding = 0
            net.ipv4.conf.default.forwarding = 0
            <%- to_enable.each do |nic| -%>
            net.ipv4.conf.<%= nic %>.forwarding = 1
            <%- end -%>
            <%- to_disable.each do |nic| -%>
            net.ipv4.conf.<%= nic %>.forwarding = 0
            <%- end -%>
        SYSCTL

        toggle [:reload]
    end

    def cleanup(basedir: '/etc/sysctl.d')
        msg :info, 'Router4::cleanup'

        to_disable = detect_nics

        file "#{basedir}/98-Router4.conf", ERB.new(<<~SYSCTL, trim_mode: '-').result(binding), mode: 'u=rw,go=r', overwrite: true
            net.ipv4.ip_forward = 0
            net.ipv4.conf.all.forwarding = 0
            net.ipv4.conf.default.forwarding = 0
            <%- to_disable.each do |nic| -%>
            net.ipv4.conf.<%= nic %>.forwarding = 0
            <%- end -%>
        SYSCTL

        toggle [:reload]
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "Router4::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del one-router4 default ||:'
            when :update
                puts bash 'rc-update -u'
            when :reload
                puts bash 'sysctl --system'
            else
                puts bash "rc-service one-router4 #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'Router4::bootstrap'
    end
end
end
