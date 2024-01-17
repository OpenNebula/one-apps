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

    def install(initdir: '/etc/init.d')
        msg :info, 'DNS::install'

        puts bash <<~SCRIPT
            apk --no-cache add dns-root-hints ruby unbound
            install -o unbound -g unbound -m u=rwx,go=rx -d /var/log/unbound/
        SCRIPT

        file "#{initdir}/one-dns", <<~SERVICE, mode: 'u=rwx,g=rx,o='
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

        file "#{basedir}/unbound.conf", ERB.new(<<~CONFIG, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            server:
                verbosity: 1

                interface: 127.0.0.1
                <%- dns_vars[:interfaces].each do |_, info| -%>
                <%- info.uniq.each do |h| -%>
                interface: <%= render_interface(h, name: h[:addr].nil?, addr: !h[:addr].nil?, port: true) %>
                <%- end -%>
                <%- end -%>

                unknown-server-time-limit: <%= ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT %>

                do-ip4: yes
                do-ip6: no
                do-udp: <%= proto_yesno.('udp') %>
                do-tcp: <%= proto_yesno.('tcp') %>

                tcp-upstream: <%= proto_yesno.('tcp-upstream') %>
                udp-upstream-without-downstream: <%= proto_yesno.('udp-upstream') %>

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
                local-data: "<%= k %>.<%= ONEAPP_VNF_DNS_CLUSTER_DOMAIN %>. IN A <%= v %>"
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
