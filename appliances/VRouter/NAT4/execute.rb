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
            # Add MASQUERADE rules.
            bash ERB.new(<<~IPTABLES, trim_mode: '-').result(binding)
                iptables -t nat -F NAT4-MASQ
                <%- nat4_vars[:masq].each do |nic| -%>
                iptables -t nat -A NAT4-MASQ -o '<%= nic %>' -j MASQUERADE
                <%- end -%>
            IPTABLES
        end

        toggle [:save, :start, :reload]
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
