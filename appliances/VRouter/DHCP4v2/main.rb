# frozen_string_literal: true

require_relative '../vrouter.rb'
require 'yaml'

module Service
    module DHCP4v2
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

        ONELEASE_DIR     = '/etc/one-appliance/service.d/VRouter/DHCP4v2/coredhcp-onelease'
        CONFIG_FILE_NAME = 'onelease-config.yml'

        def parse_env
            @interfaces ||= parse_interfaces ONEAPP_VNF_DHCP4_INTERFACES
            @mgmt       ||= detect_mgmt_nics

            interfaces = @interfaces.keys - @mgmt

            # generates a map between interfaces and their IP addresses (without netmask)
            @nics2addrs ||= nics_to_addrs(interfaces).to_h { |nic, addr| [nic, addr[0..0]] } # aliases are unsupported

            # generates a map between IP addresses and their subnets identifiers with mask
            @addrs2snets ||= addrs_to_subnets(interfaces).to_h { |a, s| [a.split(%[/])[0], s] }

            # generates a map between subnets identifiers and their allocatable IPs ranges
            @snets2ranges ||= subnets_to_ranges(@addrs2snets.values)

            # generates a map between interfaces and array of its vip addresses (without netmask)
            @vips ||= detect_vips.to_h { |nic, vip_map| [nic, vip_map.values.map { |vip| vip.split(%[/])[0] }] }

            # generates a map between interfaces and the endpoint addresses, taking VIPs into account
            @ave ||= [detect_addrs, detect_vips].then do |addrs, vips|
                [addrs, vips, detect_endpoints(addrs, vips)]
            end.map(&:values).flatten.each_with_object({}) do |h, acc|
                hashmap.combine! acc, h
            end

            interfaces.each_with_object({}) do |nic, vars|
                (snet, rng) = env("ONEAPP_VNF_DHCP4_#{nic.upcase}", nil)&.split(%[:])&.map(&:strip)

                @nics2addrs[nic]&.each do |addr|
                    subnet = snet || @addrs2snets[addr]
                    range  = rng || @snets2ranges[@addrs2snets[addr]]

                    vars[nic] ||= []
                    vars[nic] << {
                        address: addr,
                        subnet:  subnet,
                        range:   range,

                        gateway: env("ONEAPP_VNF_DHCP4_#{nic.upcase}_GATEWAY", ONEAPP_VNF_DHCP4_GATEWAY).then do |gw|
                            # interpolates in case gw address comes in the form of a nic reference, e.g. <ETH0>
                            backends.interpolate(gw, @ave) unless gw.nil?
                        end,

                        dns: env("ONEAPP_VNF_DHCP4_#{nic.upcase}_DNS", ONEAPP_VNF_DHCP4_DNS).then do |dns|
                            # interpolates in case dns address comes in the form of a nic reference, e.g. <ETH0>
                            backends.interpolate(dns, @ave) unless dns.nil?
                        end,

                        mtu: env("ONEAPP_VNF_DHCP4_#{nic.upcase}_MTU", ip_link_show(nic)['mtu']),

                        vips: @vips[nic].to_a.select do |vip|
                            IPAddr.new(subnet).include?(vip) # exclude VIPs from outside of the subnet
                        end
                    }
                end
            end
        end

        def generate_config(basedir, vars)
            config = vars.each_with_object({}) do |(nic, vars), acc|
                nic_data = vars[0] # For now, we don't support nic aliases
                acc[nic] = {
                    'server4' => {
                        'listen' => ["%#{nic}"],
                        'plugins' => [].then do |acc|
                            acc << {'lease_time' => "#{ONEAPP_VNF_DHCP4_LEASE_TIME}s"}
                            acc << {'server_id' => nic_data[:address]}
                            acc << {'dns' => nic_data[:dns]} unless nic_data[:dns].nil?
                            acc << {'mtu' => nic_data[:mtu]} unless nic_data[:mtu].nil?
                            acc << {'router' => nic_data[:gateway]} unless nic_data[:gateway].nil?
                            acc << {'netmask' => IPAddr.new('255.255.255.255').mask(nic_data[:subnet].split(%[/])[1]).to_s}
                            acc << {'onelease' => generate_onelease_config(nic, nic_data)}
                            acc
                        end
                    },
                }
            end

            file "#{basedir}/#{CONFIG_FILE_NAME}", config.to_yaml, mode: 'u=rw,g=r,o=', overwrite: true
        end

        def generate_onelease_config(nic, nic_data)
            lease_range = nic_data[:range]&.gsub('-', ' ')
            excluded_ips_str = ([nic_data[:address]] + nic_data[:vips]).join(',')
            onelease_config = "leases-#{nic}.sqlite3 #{lease_range} #{ONEAPP_VNF_DHCP4_LEASE_TIME}s"
            onelease_config += " --excluded-ips #{excluded_ips_str}" unless excluded_ips_str.empty?
            onelease_config += " --mac2ip" if ONEAPP_VNF_DHCP4_MAC2IP_ENABLED
            onelease_config += " --mac2ip-prefix #{ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX}" if ONEAPP_VNF_DHCP4_MAC2IP_ENABLED
            return onelease_config
        end

        def install(initdir: '/etc/init.d')
            msg :info, 'DHCP4v2::install'

            puts bash <<~SCRIPT
                CGO_ENABLED=1 GCC=musl-gcc go build -C #{ONELEASE_DIR}/
                strip --strip-unneeded #{ONELEASE_DIR}/coredhcp-onelease
                find #{ONELEASE_DIR}/ \\( -type f ! -name coredhcp-onelease -o -type d -empty \\) -delete
            SCRIPT

            file "#{initdir}/coredhcp", <<~SERVICE, :mode => 'u=rwx,go=rx'
                #!/sbin/openrc-run
                source /run/one-context/one_env

                BASE_DIR="#{ONELEASE_DIR}"
                CONFIG_FILE="$BASE_DIR/#{CONFIG_FILE_NAME}"
                SERVICE_EXEC="$BASE_DIR/coredhcp-onelease"
                PIDFILE="/run/$RC_SVCNAME.pid"
                LOG_DIR="/var/log"
                LOG_FILE="$LOG_DIR/$RC_SVCNAME.log"

                command="$SERVICE_EXEC"
                command_args="-c $CONFIG_FILE"
                command_background="YES"
                pidfile="$PIDFILE"

                output_log="$LOG_FILE"
                error_log="$LOG_FILE"

                depend() {
                    after net firewall keepalived
                }
            SERVICE

            file "#{initdir}/one-dhcp4v2", <<~SERVICE, mode: 'u=rwx,go=rx'
                #!/sbin/openrc-run
                source /run/one-context/one_env

                command="/usr/bin/ruby"
                command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

                output_log="/var/log/one-appliance/one-dhcp4v2.log"
                error_log="/var/log/one-appliance/one-dhcp4v2.log"

                depend() {
                    after net firewall keepalived
                }

                start_pre() {
                    rc-service coredhcp start --nodeps
                }

                start() { :; }

                stop() { :; }

                stop_post() {
                    rc-service coredhcp stop --nodeps
                }
            SERVICE

            toggle [:update]
        end

        def configure(basedir: ONELEASE_DIR)
            msg :info, 'DHCP4v2::configure'

            unless ONEAPP_VNF_DHCP4_ENABLED
                # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
                toggle [:stop, :disable]
                return
            end

            dhcp4_vars = parse_env

            generate_config(basedir, dhcp4_vars)
        end

        def toggle(operations)
            operations.each do |op|
                msg :debug, "DHCP4v2::toggle([:#{op}])"
                case op
                when :disable
                    puts bash 'rc-update del coredhcp default ||:'
                    puts bash 'rc-update del one-dhcp4v2 default ||:'
                when :update
                    puts bash 'rc-update -u'
                else
                    puts bash "rc-service one-dhcp4v2 #{op.to_s}"
                end
            end
        end

        def bootstrap
            msg :info, 'DHCP4v2::bootstrap'
        end
    end
end
