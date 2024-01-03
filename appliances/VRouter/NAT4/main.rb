# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module NAT4
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_NAT4_ENABLED = env :ONEAPP_VNF_NAT4_ENABLED, 'NO'

    ONEAPP_VNF_NAT4_INTERFACES_OUT = env :ONEAPP_VNF_NAT4_INTERFACES_OUT, '' # nil -> none, empty -> all

    def install(initdir: '/etc/init.d')
        msg :info, 'NAT4::install'

        puts bash 'apk --no-cache add iptables-openrc ruby'

        file "#{initdir}/one-nat4", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            depend() {
                after net firewall keepalived
            }

            start() {
                $command $command_args -e Service::NAT4.execute 1>>/var/log/one-appliance/one-nat4.log 2>&1
            }

            stop() {
                $command $command_args -e Service::NAT4.cleanup 1>>/var/log/one-appliance/one-nat4.log 2>&1
            }
        SERVICE

        toggle [:update]
    end

    def configure
        msg :info, 'NAT4::configure'

        if ONEAPP_VNF_NAT4_ENABLED
            toggle [:save, :enable]
        else
            toggle [:stop, :disable]
        end
    end

    def execute
        msg :info, 'NAT4::execute'

        # Add dedicated NAT4 chain.
        bash <<~IPTABLES
            iptables -t nat -nL NAT4 || iptables -t nat -N NAT4
            iptables -t nat -C POSTROUTING -j NAT4 || iptables -t nat -A POSTROUTING -j NAT4
        IPTABLES

        interfaces_out = parse_interfaces ONEAPP_VNF_NAT4_INTERFACES_OUT
        mgmt           = detect_mgmt_interfaces
        interfaces     = interfaces_out.keys - mgmt

        unless interfaces.empty?
            # Add NAT4 rules.
            bash ERB.new(<<~IPTABLES, trim_mode: '-').result(binding)
                iptables -t nat -F NAT4
                <%- interfaces.each do |nic| -%>
                iptables -t nat -A NAT4 -o '<%= nic %>' -j MASQUERADE
                <%- end -%>
            IPTABLES
        end

        toggle [:save, :start, :reload]
    end

    def cleanup
        msg :info, 'NAT4::cleanup'

        # Clear dedicated NAT4 chain.
        bash 'iptables -t nat -F NAT4'

        toggle [:save, :reload, :stop]
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "NAT4::toggle([:#{op}])"
            case op
            when :save
                puts bash 'rc-service iptables save'
            when :reload
                puts bash 'rc-service --ifstarted iptables reload'
            when :enable
                puts bash 'rc-update add iptables default'
                puts bash 'rc-update add one-nat4 default'
            when :disable
                puts bash 'rc-update del one-nat4 default ||:'
            when :update
                puts bash 'rc-update -u'
            when :start
                puts bash 'rc-service iptables start'
            when :stop
                puts bash 'rc-service iptables stop'
            else
                puts bash "rc-service one-nat4 #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'NAT4::bootstrap'
    end
end
end
