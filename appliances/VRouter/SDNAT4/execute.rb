# frozen_string_literal: true

require 'erb'
require 'ipaddr'
require 'json'
require_relative '../vrouter.rb'

module Service
module SDNAT4
    extend self

    def extract_external(vnets = {})
        @interfaces ||= parse_interfaces ONEAPP_VNF_SDNAT4_INTERFACES
        @mgmt       ||= detect_mgmt_interfaces
        @subnets    ||= addrs_to_subnets(@interfaces.keys - @mgmt, family: %w[inet]).values.uniq.map { |s| IPAddr.new(s) }

        vm_map   = {}
        external = []
        vnets.each do |vn|
            next if (vn_id = vn.dig('VNET', 'ID')).nil?

            [vn.dig('VNET', 'AR_POOL', 'AR')].flatten.each do |ar|
                ar.dig('LEASES', 'LEASE')&.each do |lease|
                    vm_map[[lease['VM'], vn_id]] = lease
                    external << lease if lease['EXTERNAL']
                end
            end
        end

        ip_map = {}
        external.each do |lease|
            k = [lease['VM'], lease['PARENT_NETWORK_ID']]
            v = vm_map.dig(k, 'IP')

            next if v.nil?

            next unless @subnets.map { |s| s.include?(v) } .any?

            ip_map[lease['IP']] = v
        end

        ip_added = []
        document = ip_addr_show 'lo'
        document&.dig('addr_info')&.each do |a|
            next if a['label'].nil? || a['label'] != 'SDNAT4'
            next if a['local'].nil?

            ip_added << a['local']
        end

        to_del = []
        ip_added.each do |ext|
            to_del << ext unless ip_map.keys.include?(ext)
        end

        to_add = []
        ip_map.each do |ext, _|
            to_add << ext unless ip_added.include?(ext)
        end

        { external: external, ip_map: ip_map, to_del: to_del, to_add: to_add }
    end

    def apply(sdnat4_vars)
        # Add SDNAT4 rules.
        bash ERB.new(<<~IPTABLES, trim_mode: '-').result(binding)
            iptables -t nat -F SNAT4
            iptables -t nat -F DNAT4
            <%- sdnat4_vars[:ip_map].each do |ext, int| -%>
            iptables -t nat -A SNAT4 -s '<%= int %>/32' -j SNAT --to-s '<%= ext %>'
            iptables -t nat -A DNAT4 -d '<%= ext %>/32' -j DNAT --to-d '<%= int %>'
            <%- end -%>
        IPTABLES

        # Delete / Add IP aliases.
        bash ERB.new(<<~IP, trim_mode: '-').result(binding)
            <%- sdnat4_vars[:to_del].each do |ext| -%>
            ip address del '<%= ext %>/32' dev lo label SDNAT4
            <%- end -%>
            <%- sdnat4_vars[:to_add].each do |ext| -%>
            ip address add '<%= ext %>/32' dev lo label SDNAT4
            <%- end -%>
        IP
    end

    def execute
        msg :info, 'SDNAT4::execute'

        prev = []

        if ONEAPP_VNF_SDNAT4_ENABLED
            # Add dedicated SNAT4 chain.
            bash <<~IPTABLES
                iptables -t nat -nL SNAT4 || iptables -t nat -N SNAT4
                iptables -t nat -C POSTROUTING -j SNAT4 || iptables -t nat -I POSTROUTING 1 -j SNAT4
            IPTABLES

            # Add dedicated DNAT4 chain.
            bash <<~IPTABLES
                iptables -t nat -nL DNAT4 || iptables -t nat -N DNAT4
                iptables -t nat -C PREROUTING -j DNAT4 || iptables -t nat -I PREROUTING 1 -j DNAT4
            IPTABLES

            toggle [:save, :start]

            loop do
                unless (vnets = get_vrouter_vnets).empty?
                    if prev != (this = extract_external(vnets))[:external]
                        msg :debug, this

                        apply this

                        toggle [:save, :reload]
                    end

                    prev = this[:external]
                end

                sleep ONEAPP_VNF_SDNAT4_REFRESH_RATE.to_i
            end
        else
            sleep
        end
    end

    def cleanup
        msg :info, 'SDNAT4::cleanup'

        # Clear dedicated SDNAT4 chains.
        bash <<~IPTABLES
            if iptables -t nat -nL SNAT4; then iptables -t nat -F SNAT4; fi
            if iptables -t nat -nL DNAT4; then iptables -t nat -F DNAT4; fi
        IPTABLES

        # Clear all SDNAT4-labeled IPs.
        document = ip_addr_show 'lo'
        document&.dig('addr_info')&.each do |a|
            next if a['label'].nil? || a['label'] != 'SDNAT4'
            next if a['local'].nil?

            bash "ip address del #{a['local']}/32 dev lo label SDNAT4"
        end

        toggle [:save, :reload]
    end
end
end
