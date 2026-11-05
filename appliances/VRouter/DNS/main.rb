# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module DNS
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_DNS_ENABLED      = env :ONEAPP_VNF_DNS_ENABLED, 'NO'
    ONEAPP_VNF_DNS_TCP_DISABLED = env :ONEAPP_VNF_DNS_TCP_DISABLED, 'NO'
    ONEAPP_VNF_DNS_UDP_DISABLED = env :ONEAPP_VNF_DNS_UDP_DISABLED, 'NO'

    ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT = env :ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT, 1128
    ONEAPP_VNF_DNS_MAX_CACHE_TTL    = env :ONEAPP_VNF_DNS_MAX_CACHE_TTL, 3600

    ONEAPP_VNF_DNS_USE_ROOTSERVERS = env :ONEAPP_VNF_DNS_USE_ROOTSERVERS, 'YES'
    ONEAPP_VNF_DNS_NAMESERVERS     = env :ONEAPP_VNF_DNS_NAMESERVERS, ''

    ONEAPP_VNF_DNS_INTERFACES       = env :ONEAPP_VNF_DNS_INTERFACES, '' # nil -> none, empty -> all
    ONEAPP_VNF_DNS_ALLOWED_NETWORKS = env :ONEAPP_VNF_DNS_ALLOWED_NETWORKS, ''

    ONEAPP_VNF_DNS_CLUSTER_DOMAIN = env :ONEAPP_VNF_DNS_CLUSTER_DOMAIN, 'vr'

    # NOTE: Serving on IPv6 addresses needs no attribute, it follows the addresses of the allowed NICs.
    #       Querying IPv6 servers upstream is automatic (IPv6 default route), this only forces it off.
    #       IPv6 forwarders in ONEAPP_VNF_DNS_NAMESERVERS are explicit and always queried.
    #       LIMIT: the IPv6 default route is checked only when configure runs, there is no polling. A default
    #       route learned later (RA/SLAAC) or lost is picked up when configure runs again (re-context / restart).
    ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED = env :ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED, 'NO'

    def parse_env
        @interfaces ||= parse_interfaces ONEAPP_VNF_DNS_INTERFACES
        @mgmt       ||= detect_mgmt_nics

        interfaces = @interfaces.keys - @mgmt

        @hosts ||= [detect_addrs, detect_vips].then do |a, v|
            [a, v, detect_endpoints(a, v)]
        end.map(&:values).flatten.each_with_object({}) do |h, acc|
            hashmap.combine! acc, h
        end.each_with_object({}) do |(name, v), acc|
            case name
            when /^ETH(\d+)_(IP)(\d+)$/, /^ETH(\d+)_(VIP)(\d+)$/, /^ETH(\d+)_(EP)(\d+)$/
                acc["#{$2.downcase}#{$3.to_i}.eth#{$1.to_i}"] = v.split(%[/])[0]
            when /^ETH(\d+)_(VIP|EP)_IP6$/ # floating IPv6 (ETHx_VROUTER_IP6), no index
                acc["#{$2.downcase}-ip6.eth#{$1.to_i}"] = v.split(%[/])[0]
            end
        end

        {
            interfaces: @interfaces.select { |nic, _| interfaces.include?(nic) },

            nameservers: ONEAPP_VNF_DNS_NAMESERVERS.split(%r{[ ,;]})
                                                   .map(&:strip)
                                                   .reject(&:empty?),

            networks: if ONEAPP_VNF_DNS_ALLOWED_NETWORKS.empty? then
                subnets = [ *addrs_to_subnets(interfaces).values,
                            *vips_to_subnets(interfaces).values ]
                subnets.uniq.join(%[,])
            else
                ONEAPP_VNF_DNS_ALLOWED_NETWORKS
            end.split(%r{[ ,;]})
               .map(&:strip)
               .reject(&:empty?),

            hosts: @hosts
        }
    end

    # Addresses (node addresses and VIPs, IPv4 and IPv6) of one NIC, without prefix length, as `ip` prints them.
    def nic_addresses(nic)
        [detect_addrs, detect_vips].flat_map { |source| (source[nic] || {}).values }.map { |a| normalize_addr(a) }.uniq
    end

    # The `interface:` values of the served NICs, as [{ name:, addr:, port: }] rendered by render_interface.
    #
    # A NIC is bound by its name, unless it has IPv6: Unbound expands a NIC name to the addresses it has at that
    # moment, so a NIC name next to an explicit address (needed to bind a VIP that is not there yet, see
    # `ip-freebind`) makes the same address appear twice when the VIP is present, and `unbound-checkconf`
    # refuses to start ("present twice, cannot bind the same ports twice"). So a NIC with IPv6 (known addresses
    # or explicit IPv6 entries) is bound by explicit addresses only: all node addresses and VIPs, IPv4 and
    # IPv6, with the port of the NIC entry, and every address is listed once, explicit entries included.
    def parse_bind_interfaces(interfaces)
        interfaces.flat_map do |nic, entries|
            entries = entries.uniq
            wholes, explicit = entries.partition { |h| h[:addr].nil? }
            v6 = explicit.any? { |h| h[:addr].include?(':') } || nic_addresses(nic).any? { |a| a.include?(':') }

            next entries unless v6 && !wholes.empty?

            expanded = wholes.flat_map { |w| nic_addresses(nic).map { |a| { name: nic, addr: a, port: w[:port] } } }

            (explicit + expanded).uniq { |h| [try_normalize_addr(h[:addr]) || h[:addr], h[:port]] }
        end
    end

    # Whether the router has an IPv6 default route in the main routing table.
    # NOTE: Evaluated once per configure run (boot, re-contexting, restart of one-dns), there is no polling:
    #       a default route learned later (RA/SLAAC) is missed and a vanished one is not noticed until
    #       configure runs again, which re-evaluates it from scratch.
    # NOTE: A failing lookup (no `ip`, no IPv6 in the kernel) counts as no default route.
    def ipv6_default_route?
        routes = bash 'ip -6 route show default', terminate: false
        routes.each_line.any? { |line| line.start_with?('default') }
    rescue StandardError => e
        msg :debug, "DNS::ipv6_default_route?: lookup failed, assuming no IPv6 default route: #{e.message}"
        false
    end

    def install(initdir: '/etc/init.d')
        msg :info, 'DNS::install'

        puts bash <<~SCRIPT
            apk --no-cache add dns-root-hints ruby unbound
            install -o unbound -g unbound -m u=rwx,go=rx -d /var/log/unbound/
        SCRIPT

        file "#{initdir}/one-dns", <<~SERVICE, mode: 'u=rwx,go=rx'
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            output_log="/var/log/one-appliance/one-dns.log"
            error_log="/var/log/one-appliance/one-dns.log"

            depend() {
                after net firewall keepalived
            }

            start_pre() {
                rc-service unbound start --nodeps
            }

            start() { :; }

            stop() { :; }

            stop_post() {
                rc-service unbound stop --nodeps
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/unbound')
        msg :info, 'DNS::configure'

        unless ONEAPP_VNF_DNS_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        proto_yesno = ->(proto) {
            udp = ONEAPP_VNF_DNS_UDP_DISABLED ? 'no' : 'yes'
            tcp = ONEAPP_VNF_DNS_TCP_DISABLED ? 'no' : 'yes'
            case proto
            when 'udp', 'udp-upstream' then udp
            when 'tcp'                 then tcp
            when 'tcp-upstream'        then udp == 'yes' ? 'no' : 'yes'
            end
        }

        dns_vars = parse_env

        bind_interfaces = parse_bind_interfaces dns_vars[:interfaces]
        ipv6_bound      = bind_interfaces.any? { |h| h[:addr]&.include?(':') }

        # NOTE: In Unbound `do-ip6: no` also stops answering on IPv6 addresses, so it must be `yes` whenever
        #       IPv6 addresses are bound (derived or explicit).
        #       A router with an IPv6 default route gets `do-ip6: yes` even if it has no IPv6 address of its own
        #       (IPv4-only service, dual-stack upstream): upstream IPv6 is wanted then. Without a default route
        #       the output is the pre-IPv6 one. ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED=YES forces it off. `do-not-query-address: ::0/0` then keeps the upstream side on IPv4.
        #       Explicit IPv6 forwarders are exempt: with forwarders in use, they are the only upstream servers.
        ipv6_upstream  = !ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED && ipv6_default_route?
        ipv6_forwarder = !ONEAPP_VNF_DNS_USE_ROOTSERVERS && dns_vars[:nameservers].any? { |a| a.include?(':') }
        do_ip6         = ipv6_upstream || ipv6_forwarder || ipv6_bound
        block_ip6      = do_ip6 && !ipv6_upstream && !ipv6_forwarder

        file "#{basedir}/unbound.conf", ERB.new(<<~CONFIG, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            server:
                verbosity: 1

                interface: 127.0.0.1
                <%- bind_interfaces.each do |h| -%>
                interface: <%= render_interface(h, name: h[:addr].nil?, addr: !h[:addr].nil?, port: true) %>
                <%- end -%>
                <%- if ipv6_bound -%>
                ip-freebind: yes
                <%- end -%>

                unknown-server-time-limit: <%= ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT %>

                do-ip4: yes
                do-ip6: <%= do_ip6 ? 'yes' : 'no' %>
                do-udp: <%= proto_yesno.('udp') %>
                do-tcp: <%= proto_yesno.('tcp') %>

                tcp-upstream: <%= proto_yesno.('tcp-upstream') %>
                udp-upstream-without-downstream: <%= proto_yesno.('udp-upstream') %>
                <%- if block_ip6 -%>
                do-not-query-address: ::0/0
                <%- end -%>

                access-control: 0.0.0.0/0 refuse
                access-control: ::0/0 refuse
                access-control: 127.0.0.0/8 allow
                <%- dns_vars[:networks].uniq.each do |subnet| -%>
                access-control: <%= subnet %> allow
                <%- end -%>

                cache-min-ttl: 0
                cache-max-ttl: <%= ONEAPP_VNF_DNS_MAX_CACHE_TTL %>

                logfile: "/var/log/unbound/unbound.log"
                log-identity: ""
                log-time-ascii: yes
                log-queries: no
                log-replies: no
                log-servfail: yes

                <%- if ONEAPP_VNF_DNS_USE_ROOTSERVERS -%>
                root-hints: /usr/share/dns-root-hints/named.root
                <%- else -%>
                # root-hints: /usr/share/dns-root-hints/named.root
                <%- end -%>

                hide-identity: yes
                hide-version: yes

                serve-expired: no

                use-systemd: no
                do-daemonize: yes

                <%- unless ONEAPP_VNF_DNS_CLUSTER_DOMAIN.empty? -%>
                local-zone: "<%= ONEAPP_VNF_DNS_CLUSTER_DOMAIN %>." static
                <%- dns_vars[:hosts].each do |k, v| -%>
                local-data: "<%= k %>.<%= ONEAPP_VNF_DNS_CLUSTER_DOMAIN %>. IN <%= v.include?(':') ? 'AAAA' : 'A' %> <%= v %>"
                <%- end -%>
                <%- end -%>

            remote-control:
                control-enable: no

            <%- unless ONEAPP_VNF_DNS_USE_ROOTSERVERS -%>
            forward-zone:
                name: "."
            <%- dns_vars[:nameservers].uniq.each do |nameserver| -%>
                forward-addr: <%= nameserver %>
            <%- end -%>
            <%- end -%>
        CONFIG
    end

    def toggle(operations)
        operations.each do |op|
            msg :debug, "DNS::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del unbound default ||:'
                puts bash 'rc-update del one-dns default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-dns #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'DNS::bootstrap'
    end
end
end
