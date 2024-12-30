# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'
require_relative 'execute.rb'

module Service
module NAT4
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_NAT4_ENABLED = env :ONEAPP_VNF_NAT4_ENABLED, 'NO'

    ONEAPP_VNF_NAT4_INTERFACES_OUT = env :ONEAPP_VNF_NAT4_INTERFACES_OUT, nil # nil -> none, empty -> all

    def parse_env
        @interfaces_out ||= parse_interfaces ONEAPP_VNF_NAT4_INTERFACES_OUT
        @mgmt           ||= detect_mgmt_nics
        @interfaces     ||= @interfaces_out.keys - @mgmt

        @ave ||= [detect_addrs, detect_vips].then do |a, v|
            [a, v, detect_endpoints(a, v)]
        end.map(&:values).flatten.each_with_object({}) do |h, acc|
            hashmap.combine! acc, h
        end

        ENV.each_with_object({dnat: {}, masq: []}) do |(name, v), acc|
            next if v.strip.empty?
            case name
            when /^ONEAPP_VNF_NAT4_PORT_FWD(\d+)$/
                index      = $1.to_i
                positional = v.split(%[:]).map(&:strip)

                next if positional.count > 4
                next if positional[0].nil? || positional[0].empty?

                if /^<ETH\d+_(?:IP|EP|VIP)\d+>$/ =~ positional[0]
                    (old_dest, old_port, new_dest, new_port) = \
                        [backends.interpolate(positional[0], @ave)] + positional[1..(-1)]
                elsif ipv4?(positional[0])
                    (old_dest, old_port, new_dest, new_port) = positional
                elsif port?(positional[0])
                    (old_dest, old_port, new_dest, new_port) = [nil] + positional
                else
                    next
                end

                next if !old_dest.nil? && !old_dest.empty? && !ipv4?(old_dest)
                next if old_port.nil? || old_port.empty? || !port?(old_port)
                next if new_dest.nil? || new_dest.empty? || !ipv4?(new_dest)
                next if !new_port.nil? && !new_port.empty? && !port?(new_port)

                acc[:dnat][index] = [old_dest, old_port, new_dest, new_port]
            end
        end.then do |vars|
            vars[:masq] = @interfaces.dup
            vars
        end
    end

    def install(initdir: '/etc/init.d')
        msg :info, 'NAT4::install'

        puts bash 'apk --no-cache add iptables-openrc ruby'

        file "#{initdir}/one-nat4", <<~SERVICE, mode: 'u=rwx,go=rx'
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

        unless ONEAPP_VNF_NAT4_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        toggle [:save]
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "NAT4::toggle([:#{op}])"
            case op
            when :save
                puts bash 'rc-service iptables save'
            when :reload
                puts bash 'rc-service --ifstarted iptables reload'
            when :disable
                puts bash 'rc-update del one-nat4 default ||:'
            when :update
                puts bash 'rc-update -u'
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
