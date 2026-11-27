# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module NAT4
    extend self

    def execute
        msg :info, 'NAT4::execute'

        # Add dedicated NAT4-DNAT chain.
        bash <<~IPTABLES
            iptables -t nat -nL NAT4-DNAT || iptables -t nat -N NAT4-DNAT
            iptables -t nat -C PREROUTING -j NAT4-DNAT || iptables -t nat -A PREROUTING -j NAT4-DNAT
        IPTABLES

        # Add dedicated NAT4-MASQ chain.
        bash <<~IPTABLES
            iptables -t nat -nL NAT4-MASQ || iptables -t nat -N NAT4-MASQ
            iptables -t nat -C POSTROUTING -j NAT4-MASQ || iptables -t nat -A POSTROUTING -j NAT4-MASQ
        IPTABLES

        nat4_vars = parse_env

        unless nat4_vars[:dnat].empty?
            # Add DNAT rules.
            bash ERB.new(<<~IPTABLES, trim_mode: '-').result(binding)
                iptables -t nat -F NAT4-DNAT
                <%- nat4_vars[:dnat].values.each do |(old_dest, old_port, new_dest, new_port)| -%>
                iptables -t nat -A NAT4-DNAT \
                         -p tcp \
                         <%= ('-d ' + old_dest) unless old_dest.nil? %> \
                         --dport <%= old_port %> \
                         -j DNAT \
                         --to-destination <%= new_dest %><%= (':' + new_port.to_s) unless new_port.nil? %>
                iptables -t nat -A NAT4-DNAT \
                         -p udp \
                         <%= ('-d ' + old_dest) unless old_dest.nil? %> \
                         --dport <%= old_port %> \
                         -j DNAT \
                         --to-destination <%= new_dest %><%= (':' + new_port.to_s) unless new_port.nil? %>
                <%- end -%>
            IPTABLES
        end

        unless nat4_vars[:masq].empty?
            snat = snat_sources nat4_vars[:masq]

            # Add MASQUERADE rules (SNAT to an address or to the VIP, if configured).
            bash ERB.new(<<~IPTABLES, trim_mode: '-').result(binding)
                iptables -t nat -F NAT4-MASQ
                <%- local_returns(nat4_vars[:masq], snat).each do |match| -%>
                iptables -t nat -A NAT4-MASQ -m addrtype --src-type LOCAL <%= match %>-j RETURN
                <%- end -%>
                <%- nat4_vars[:masq].each do |nic| -%>
                <%- if snat.key?(nic) -%>
                iptables -t nat -A NAT4-MASQ -o '<%= nic %>' -j SNAT --to-source '<%= snat[nic] %>'
                <%- else -%>
                <%- if ONEAPP_VNF_NAT4_SNAT_LOCAL && !snat.empty? -%>
                iptables -t nat -A NAT4-MASQ -m addrtype --src-type LOCAL -o '<%= nic %>' -j RETURN
                <%- end -%>
                iptables -t nat -A NAT4-MASQ -o '<%= nic %>' -j MASQUERADE
                <%- end -%>
                <%- end -%>
            IPTABLES
        end

        toggle [:save, :reload]
    end

    # NOTE: The matches of the RETURN rules for locally generated traffic, each with a trailing space.
    #       Without SNAT there are none, with SNAT_LOCAL=NO one empty match returns all of it.
    def local_returns(nics, snat)
        return [] if snat.empty?
        return [''] unless ONEAPP_VNF_NAT4_SNAT_LOCAL

        local_matches(nics).map { |match| "#{match} " }
    end

    # NOTE: Local traffic that keeps the node address. Matched by protocol and subnet rather than by
    #       neighbor address, because neighbors can change at runtime.
    def local_matches(nics)
        ['-d 224.0.0.0/4', '--dst-type BROADCAST', '-d 169.254.0.0/16', '-p 112', '-p 89',
         *connected_subnets(nics).map { |subnet| "-d #{subnet}" },
         '-p tcp --dport 179', '-p tcp --sport 179', '-p udp -m multiport --dports 3784,3785,4784',
         '-p 47', '-p 4',
         *feature_matches]
    end

    # NOTE: The IPv4 subnets of the NIC addresses, VIPs and aliases of the NICs. Unparsable values are
    #       skipped: a rule iptables refuses would abort the script after the chain has been flushed.
    def connected_subnets(nics)
        addrs = nics_to_subnets(nics.select { |nic| IPV4_RE.match?(env("#{nic.upcase}_IP", '').split(%[/])[0]) })

        (addrs.values.flatten + vip_subnets(nics) + alias_subnets(nics)).uniq
    end

    def vip_subnets(nics)
        detect_vips.slice(*nics).flat_map do |nic, vips|
            vips.values.filter_map { |vip| ipv4_subnet(nic.delete_prefix('eth'), vip) }
        end
    end

    def alias_subnets(nics)
        ENV.keys.grep(/\AETH\d+_ALIAS\d+_IP\z/).sort.filter_map do |name|
            index = name[/\AETH(\d+)/, 1]
            mask  = env(name.sub(/IP\z/, 'MASK'), nil)
            next unless nics.include?("eth#{index}") && IPV4_RE.match?(mask.to_s)

            ipv4_subnet(index, "#{ENV[name].split(%[/])[0]}/#{IPAddr.new(mask).to_i.to_s(2).count('1')}")
        end
    end

    def ipv4_subnet(eth_index, address)
        ip, length = address.to_s.split(%[/])
        return unless IPV4_RE.match?(ip.to_s) && (length.nil? || length.match?(/\A([0-9]|[12]\d|3[0-2])\z/))

        subnet = IPAddr.new(append_pfxlen(eth_index, address))
        "#{subnet}/#{subnet.prefix}"
    end

    # NOTE: Exceptions of other modules, read from their boot-time attributes.
    def feature_matches
        [conntrack_peer_match, wireguard_match].compact
    end

    def conntrack_peer_match
        peer = env(:ONEAPP_VNF_CONNTRACK_SYNC_PEER, '').strip
        return if peer.empty?
        return "-d #{peer}" if unicast_ipv4?(peer)

        msg :error, "NAT4::local_matches: invalid ONEAPP_VNF_CONNTRACK_SYNC_PEER #{peer[0, 40].inspect}, ignored"
        nil
    end

    def wireguard_match
        return unless env(:ONEAPP_VNF_WG_ENABLED, 'NO')

        port = env(:ONEAPP_VNF_WG_LISTEN_PORT, '51820').to_s.strip
        return "-p udp --sport #{port}" if port.match?(/\A\d{1,5}\z/) && (1..65_535).cover?(port.to_i)

        msg :error, "NAT4::local_matches: invalid ONEAPP_VNF_WG_LISTEN_PORT #{port[0, 40].inspect}, ignored"
        nil
    end

    def cleanup
        msg :info, 'NAT4::cleanup'

        # Clear dedicated NAT4-DNAT chain.
        bash 'iptables -t nat -F NAT4-DNAT'

        # Clear dedicated NAT4-MASQ chain.
        bash 'iptables -t nat -F NAT4-MASQ'

        toggle [:save, :reload]
    end
end
end
