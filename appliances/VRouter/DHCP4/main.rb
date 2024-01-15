# frozen_string_literal: true

require 'ipaddr'
require 'json'
require_relative '../vrouter.rb'

module Service
module DHCP4
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_DHCP4_ENABLED = env :ONEAPP_VNF_DHCP4_ENABLED, 'NO'

    ONEAPP_VNF_DHCP4_AUTHORITATIVE = env :ONEAPP_VNF_DHCP4_AUTHORITATIVE, 'YES'

    ONEAPP_VNF_DHCP4_MAC2IP_ENABLED   = env :ONEAPP_VNF_DHCP4_MAC2IP_ENABLED, 'YES'
    ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX = env :ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX, '02:00'

    ONEAPP_VNF_DHCP4_LEASE_TIME = env :ONEAPP_VNF_DHCP4_LEASE_TIME, '3600'

    ONEAPP_VNF_DHCP4_GATEWAY = env :ONEAPP_VNF_DHCP4_GATEWAY, nil
    ONEAPP_VNF_DHCP4_DNS     = env :ONEAPP_VNF_DHCP4_DNS, nil

    ONEAPP_VNF_DHCP4_INTERFACES = env :ONEAPP_VNF_DHCP4_INTERFACES, '' # nil -> none, empty -> all

    def parse_env
        @interfaces ||= parse_interfaces ONEAPP_VNF_DHCP4_INTERFACES
        @mgmt       ||= detect_mgmt_nics

        interfaces = @interfaces.keys - @mgmt

        @n2a ||= nics_to_addrs(interfaces).to_h { |n, a| [n, a[0..0]] } # aliases are unsupported

        @a2s ||= addrs_to_subnets(interfaces).to_h { |a, s| [a.split(%[/])[0], s] }

        @s2r ||= subnets_to_ranges(@a2s.values)

        @vips ||= detect_vips.to_h { |n, v| [n, v.values.map { |v| v.split(%[/])[0] }] }

        interfaces.each_with_object({}) do |nic, vars|
            (s, r) = env("ONEAPP_VNF_DHCP4_#{nic.upcase}", nil)&.split(%[:])&.map(&:strip)

            @n2a[nic]&.each do |a|
                subnet = s || @a2s[a]
                range  = r || @s2r[@a2s[a]]

                vars[nic] ||= []
                vars[nic] << {
                    address: a,
                    subnet:  subnet,
                    range:   range,
                    gateway: env("ONEAPP_VNF_DHCP4_#{nic.upcase}_GATEWAY", ONEAPP_VNF_DHCP4_GATEWAY),
                    dns:     env("ONEAPP_VNF_DHCP4_#{nic.upcase}_DNS", ONEAPP_VNF_DHCP4_DNS),
                    mtu:     env("ONEAPP_VNF_DHCP4_#{nic.upcase}_MTU", ip_link_show(nic)['mtu']),

                    vips: @vips[nic].to_a.select do |vip|
                        IPAddr.new(subnet).include?(vip) # exclude VIPs from outside of the subnet
                    end
                }
            end
        end
    end

    def install(initdir: '/etc/init.d')
        msg :info, 'DHCP4::install'

        onelease4_apk = File.join File.dirname(__FILE__), 'kea-hook-onelease4-1.1.1-r0.apk'

        puts bash <<~SCRIPT
            apk --no-cache add ruby kea-dhcp4
            apk --no-cache --allow-untrusted add '#{onelease4_apk}'
        SCRIPT

        file "#{initdir}/one-dhcp4", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            output_log="/var/log/one-appliance/one-dhcp4.log"
            error_log="/var/log/one-appliance/one-dhcp4.log"

            depend() {
                after net firewall keepalived
            }

            start_pre() {
                rc-service kea-dhcp4 start --nodeps
            }

            start() { :; }

            stop() { :; }

            stop_post() {
                rc-service kea-dhcp4 stop --nodeps
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/kea', owner: 'kea', group: 'kea')
        msg :info, 'DHCP4::configure'

        unless ONEAPP_VNF_DHCP4_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        dhcp4_vars = parse_env

        config = { 'Dhcp4' => {
            'interfaces-config' => { 'interfaces' => dhcp4_vars.keys },
            'authoritative' => ONEAPP_VNF_DHCP4_AUTHORITATIVE,
            'option-data' => [],
            'subnet4' => dhcp4_vars.each_with_object([]) do |(nic, vars), acc|
                vars.each do |h|
                    acc << {
                        'subnet' => h[:subnet],
                        'pools' => [ { 'pool' => h[:range] } ],
                        'option-data' => [].then do |acc|
                            acc << { 'name' => 'routers',
                                     'data' => h[:gateway] } unless h[:gateway].nil?

                            acc << { 'name' => 'domain-name-servers',
                                     'data' => h[:dns] } unless h[:dns].nil?

                            acc << { 'name' => 'interface-mtu',
                                     'data' => h[:mtu].to_s } unless h[:mtu].nil?
                            acc
                        end,
                        'reservations' => ([h[:address]] + h[:vips]).each_with_object([]) do |ip, acc|
                            acc << { 'flex-id' => "'DO-NOT-LEASE-#{ip}'",
                                     'ip-address' => ip }
                        end,
                        'reservation-mode' => 'all'
                    }
                end
            end,
            'lease-database' => {
                'type' => 'memfile',
                'persist' => true,
                'lfc-interval' => 2 * ONEAPP_VNF_DHCP4_LEASE_TIME.to_i
            },
            'sanity-checks' => { 'lease-checks' => 'fix-del' },
            'valid-lifetime' => ONEAPP_VNF_DHCP4_LEASE_TIME.to_i,
            'calculate-tee-times' => true,
            'loggers' => [
                { 'name' => 'kea-dhcp4',
                  'output_options' => [ { 'output' => '/var/log/kea/kea-dhcp4.log' } ],
                  'severity' => 'INFO',
                  'debuglevel' => 0 }
            ],
            'hooks-libraries' => if ONEAPP_VNF_DHCP4_MAC2IP_ENABLED then
                [ { 'library' => '/usr/lib/kea/hooks/libkea-onelease-dhcp4.so',
                    'parameters' => {
                        'enabled' => true,
                        'byte-prefix' => ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX,
                        'logger-name' => 'onelease-dhcp4',
                        'debug' => false,
                        'debug-logfile' => '/var/log/kea/onelease-dhcp4-debug.log' } } ]
            else [] end
        } }

        file "#{basedir}/kea-dhcp4.conf", JSON.pretty_generate(config), owner: owner,
                                                                        group: group,
                                                                        mode: 'u=rw,g=r,o=',
                                                                        overwrite: true
    end

    def toggle(operations)
        operations.each do |op|
            msg :debug, "DHCP4::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del kea-dhcp4 default ||:'
                puts bash 'rc-update del one-dhcp4 default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-dhcp4 #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'DHCP4::bootstrap'
    end
end
end
