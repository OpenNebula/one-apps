# frozen_string_literal: true

require 'rspec'
require 'tmpdir'

def clear_env
    ENV.delete_if { |name| name.start_with?('ETH') || name.include?('VROUTER_') || name.include?('_VNF_') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide and parse all env vars (default networks)' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_TCP_DISABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_UDP_DISABLED'] = 'NO'

        ENV['ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT'] = '123'
        ENV['ONEAPP_VNF_DNS_MAX_CACHE_TTL'] = '234'

        ENV['ONEAPP_VNF_DNS_USE_ROOTSERVERS'] = 'YES'
        ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '1.1.1.1 8.8.8.8'

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = ''

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55/16'
        ENV['ONEAPP_VROUTER_ETH0_VIP10'] = '9.10.11.12/13'
        ENV['ONEAPP_VROUTER_ETH0_VIP1'] = '5.6.7.8/9'
        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '1.2.3.4/5'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        ENV['ETH3_IP'] = '40.50.60.70'
        ENV['ETH3_MASK'] = '255.255.255.0'

        load './main.rb'; include Service::DNS

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                          'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                          'eth3' => [ { name: 'eth3', addr: nil, port: nil } ] },

            nameservers: %w[1.1.1.1 8.8.8.8],

            networks: %w[20.30.0.0/16 30.0.0.0/8 40.50.60.0/24],

            hosts: { 'ip0.eth0'   => '10.20.30.40',
                     'ip0.eth1'   => '20.30.40.50',
                     'ip0.eth2'   => '30.40.50.60',
                     'ip0.eth3'   => '40.50.60.70',
                     'vip0.eth1'  => '20.30.40.55',
                     'vip10.eth0' => '9.10.11.12',
                     'vip1.eth0'  => '5.6.7.8',
                     'vip0.eth0'  => '1.2.3.4',
                     'ep0.eth0'   => '1.2.3.4',
                     'ep10.eth0'  => '9.10.11.12',
                     'ep1.eth0'   => '5.6.7.8',
                     'ep0.eth1'   => '20.30.40.55',
                     'ep0.eth2'   => '30.40.50.60',
                     'ep0.eth3'   => '40.50.60.70' }
        })

        output = <<~'UNBOUND_CONF'
            server:
                verbosity: 1

                interface: 127.0.0.1
                interface: eth1
                interface: eth2
                interface: eth3

                unknown-server-time-limit: 123

                do-ip4: yes
                do-ip6: no
                do-udp: yes
                do-tcp: no

                tcp-upstream: no
                udp-upstream-without-downstream: yes

                access-control: 0.0.0.0/0 refuse
                access-control: ::0/0 refuse
                access-control: 127.0.0.0/8 allow
                access-control: 20.30.0.0/16 allow
                access-control: 30.0.0.0/8 allow
                access-control: 40.50.60.0/24 allow

                cache-min-ttl: 0
                cache-max-ttl: 234

                logfile: "/var/log/unbound/unbound.log"
                log-identity: ""
                log-time-ascii: yes
                log-queries: no
                log-replies: no
                log-servfail: yes

                root-hints: /usr/share/dns-root-hints/named.root

                hide-identity: yes
                hide-version: yes

                serve-expired: no

                use-systemd: no
                do-daemonize: yes

                local-zone: "vr." static
                local-data: "ip0.eth0.vr. IN A 10.20.30.40"
                local-data: "ip0.eth1.vr. IN A 20.30.40.50"
                local-data: "ip0.eth2.vr. IN A 30.40.50.60"
                local-data: "ip0.eth3.vr. IN A 40.50.60.70"
                local-data: "vip0.eth1.vr. IN A 20.30.40.55"
                local-data: "vip10.eth0.vr. IN A 9.10.11.12"
                local-data: "vip1.eth0.vr. IN A 5.6.7.8"
                local-data: "vip0.eth0.vr. IN A 1.2.3.4"
                local-data: "ep0.eth0.vr. IN A 1.2.3.4"
                local-data: "ep10.eth0.vr. IN A 9.10.11.12"
                local-data: "ep1.eth0.vr. IN A 5.6.7.8"
                local-data: "ep0.eth1.vr. IN A 20.30.40.55"
                local-data: "ep0.eth2.vr. IN A 30.40.50.60"
                local-data: "ep0.eth3.vr. IN A 40.50.60.70"

            remote-control:
                control-enable: no
        UNBOUND_CONF
        Dir.mktmpdir do |dir|
            Service::DNS.configure basedir: dir
            result = File.read "#{dir}/unbound.conf"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should provide and parse all env vars' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_TCP_DISABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_UDP_DISABLED'] = 'YES'

        ENV['ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT'] = '123'
        ENV['ONEAPP_VNF_DNS_MAX_CACHE_TTL'] = '234'

        ENV['ONEAPP_VNF_DNS_USE_ROOTSERVERS'] = 'YES'
        ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '1.1.1.1 8.8.8.8'

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth1 eth2 eth3/40.50.60.70'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = '20.30.0.0/16 30.0.0.0/8'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        ENV['ETH3_IP'] = '40.50.60.70'
        ENV['ETH3_MASK'] = '255.255.255.0'

        load './main.rb'; include Service::DNS

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth1' => [ { name: 'eth1', addr: nil, port: nil },
                                      { name: 'eth1', addr: nil, port: nil } ],
                          'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                          'eth3' => [ { name: 'eth3', addr: '40.50.60.70', port: nil } ] },

            nameservers: %w[1.1.1.1 8.8.8.8],

            networks: %w[20.30.0.0/16 30.0.0.0/8],

            hosts: { 'ip0.eth0' => '10.20.30.40',
                     'ip0.eth1' => '20.30.40.50',
                     'ip0.eth2' => '30.40.50.60',
                     'ip0.eth3' => '40.50.60.70',
                     'ep0.eth0' => '10.20.30.40',
                     'ep0.eth1' => '20.30.40.50',
                     'ep0.eth2' => '30.40.50.60',
                     'ep0.eth3' => '40.50.60.70' }
        })
    end

    it 'should fallback to VIPs' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 1.2.3.4'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = ''

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '1.2.3.4/16'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        load './main.rb'; include Service::DNS

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth1' => [ { name: 'eth1', addr: '1.2.3.4', port: nil } ] },

            nameservers: %w[],

            networks: %w[1.2.0.0/16],

            hosts: { 'ip0.eth0'  => '10.20.30.40',
                     'vip0.eth1' => '1.2.3.4',
                     'ep0.eth0'  => '10.20.30.40',
                     'ep0.eth1'  => '1.2.3.4' }
        })
    end

    it 'should NOT skip networks with inferred netmasks' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth2 eth3 eth4'

        ENV['ETH0_IP'] = '10.0.0.1'
        ENV['ETH1_IP'] = '172.16.0.1'
        ENV['ETH2_IP'] = '192.168.0.1'

        ENV['ETH3_IP'] = '1.2.3.4'
        ENV['ETH4_IP'] = '2.3.4.5'
        ENV["ETH4_MASK"] = '255.255.0.0'

        load './main.rb'; include Service::DNS

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth0' => [ { name: 'eth0', addr: nil, port: nil } ],
                          'eth1' => [ { name: 'eth1', addr: nil, port: nil } ],
                          'eth2' => [ { name: 'eth2', addr: nil, port: nil } ],
                          'eth3' => [ { name: 'eth3', addr: nil, port: nil } ],
                          'eth4' => [ { name: 'eth4', addr: nil, port: nil } ] },

            nameservers: %w[],

            networks: %w[10.0.0.0/8 172.16.0.0/16 192.168.0.0/24 1.2.3.0/24 2.3.0.0/16],

            hosts: { 'ep0.eth0' => '10.0.0.1',
                     'ep0.eth1' => '172.16.0.1',
                     'ep0.eth2' => '192.168.0.1',
                     'ep0.eth3' => '1.2.3.4',
                     'ep0.eth4' => '2.3.4.5',
                     'ip0.eth0' => '10.0.0.1',
                     'ip0.eth1' => '172.16.0.1',
                     'ip0.eth2' => '192.168.0.1',
                     'ip0.eth3' => '1.2.3.4',
                     'ip0.eth4' => '2.3.4.5' }
        })
    end

    def render_conf(default_route: false)
        load './main.rb'; include Service::DNS

        clear_vars Service::DNS

        allow(Service::DNS).to receive(:ipv6_default_route?).and_return(default_route)

        Dir.mktmpdir do |dir|
            Service::DNS.configure basedir: dir
            File.read "#{dir}/unbound.conf"
        end
    end

    def dual_stack_env
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55/16'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '2001:db8:1::1/64'
    end

    it 'should render byte-identical config for IPv4-only routers' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1'
        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        result = render_conf

        expect(result).to include "    interface: 127.0.0.1\n    interface: eth1\n\n"
        expect(result).to include "    do-ip4: yes\n    do-ip6: no\n    do-udp: yes\n"
        expect(result).to include "    access-control: 20.30.0.0/16 allow\n\n    cache-min-ttl: 0\n"
        expect(result).not_to match(/AAAA|freebind|do-not-query/)
        expect(result).to include 'local-data: "ip0.eth1.vr. IN A 20.30.40.50"'
    end

    it 'should serve, allow and publish IPv6 on a dual-stack router' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '1.1.1.1'
        ENV['ETH1_VROUTER_IP6'] = '2001:db8:2::1/64'

        result = render_conf

        expect(result).to include "    interface: 127.0.0.1\n    interface: 20.30.40.50\n    interface: 20.30.40.55\n" \
                                  "    interface: 2001:db8:1::1\n    interface: 2001:db8:2::1\n" \
                                  "    ip-freebind: yes\n\n"
        expect(result).not_to include "interface: eth1\n"
        expect(result).to include "    do-ip4: yes\n    do-ip6: yes\n"
        expect(result).to include 'access-control: ::0/0 refuse'
        expect(result).to include 'access-control: 20.30.0.0/16 allow'
        expect(result).to include 'access-control: 2001:db8:1::/64 allow'
        expect(result).to include 'access-control: 2001:db8:2::/64 allow'
        expect(result).to include 'local-data: "vip0.eth1.vr. IN A 20.30.40.55"'
        expect(result).to include 'local-data: "vip1.eth1.vr. IN AAAA 2001:db8:1::1"'
        expect(result).to include 'local-data: "ep1.eth1.vr. IN AAAA 2001:db8:1::1"'
        expect(result).to include 'local-data: "vip-ip6.eth1.vr. IN AAAA 2001:db8:2::1"'
        expect(result).to include 'local-data: "ep-ip6.eth1.vr. IN AAAA 2001:db8:2::1"'
    end

    it 'should serve IPv6 on an IPv6-only router' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1'
        ENV['ETH1_IP'] = '2001:db8:1::10'

        result = render_conf

        expect(result).to include "    interface: 127.0.0.1\n    interface: 2001:db8:1::10\n" \
                                  "    ip-freebind: yes\n\n"
        expect(result).not_to include "interface: eth1\n"
        expect(result).to include "    do-ip6: yes\n"
        expect(result).to include 'access-control: 2001:db8:1::/64 allow'
        expect(result).to include 'local-data: "ip0.eth1.vr. IN AAAA 2001:db8:1::10"'
        expect(result).not_to include ' IN A '
    end

    it 'should NOT bind IPv6 on management NICs' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1'
        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '2001:db8:9::1/64'

        result = render_conf

        expect(result).not_to include 'interface: 2001:db8:9::1'
        expect(result).not_to include 'access-control: 2001:db8:9::/64'
    end

    context 'upstream IPv6 (ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED)' do
        it 'should use IPv6 upstream with an IPv6 default route' do
            dual_stack_env

            result = render_conf default_route: true

            expect(result).to include "    do-ip6: yes\n"
            expect(result).not_to include 'do-not-query-address'
        end

        it 'should block IPv6 upstream, but keep serving, without an IPv6 default route' do
            dual_stack_env

            result = render_conf default_route: false

            expect(result).to include "    do-ip6: yes\n"
            expect(result).to include "    do-not-query-address: ::0/0\n"
            expect(result).to include 'interface: 2001:db8:1::1'
        end

        it 'should render do-ip6 no on IPv4-only routers without an IPv6 default route' do
            clear_env
            ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
            ENV['ETH1_IP'] = '20.30.40.50'

            result = render_conf default_route: false

            expect(result).to include "    do-ip6: no\n"
            expect(result).not_to include 'do-not-query-address'
        end

        it 'should treat a failing route lookup as no default route' do
            clear_env
            ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
            ENV['ETH1_IP'] = '20.30.40.50'

            load './main.rb'
            expect(Service::DNS).to receive(:bash).with(/ip -6 route show default/, terminate: false)
                                                  .and_raise('1: boom')
            expect(Service::DNS.ipv6_default_route?).to eq false
        end

        it 'should detect default routes from the route listing' do
            load './main.rb'
            allow(Service::DNS).to receive(:bash).and_return("default via fe80::1 dev eth0 metric 1024\n")
            expect(Service::DNS.ipv6_default_route?).to eq true
            allow(Service::DNS).to receive(:bash).and_return("")
            expect(Service::DNS.ipv6_default_route?).to eq false
            allow(Service::DNS).to receive(:bash).and_return("unreachable default dev lo metric 4278198272\n")
            expect(Service::DNS.ipv6_default_route?).to eq false
        end

        it 'should block IPv6 upstream when disabled, even with an IPv6 default route' do
            dual_stack_env
            ENV['ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED'] = 'YES'

            result = render_conf default_route: true

            expect(result).to include "    do-ip6: yes\n"
            expect(result).to include "    do-not-query-address: ::0/0\n"
            expect(result).to include 'interface: 2001:db8:1::1'
        end

        it 'should render do-ip6 no on IPv4-only routers when disabled' do
            clear_env
            ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
            ENV['ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED'] = 'YES'
            ENV['ETH1_IP'] = '20.30.40.50'

            result = render_conf default_route: true

            expect(result).to include "    do-ip6: no\n"
            expect(result).not_to include 'do-not-query-address'
        end

        it 'should use IPv6 upstream when explicitly NOT disabled' do
            dual_stack_env
            ENV['ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED'] = 'NO'

            result = render_conf default_route: true

            expect(result).not_to include 'do-not-query-address'
        end

        it 'should still query IPv6 forwarders when IPv6 upstream is disabled' do
            clear_env
            ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
            ENV['ONEAPP_VNF_DNS_IPV6_UPSTREAM_DISABLED'] = 'YES'
            ENV['ONEAPP_VNF_DNS_USE_ROOTSERVERS'] = 'NO'
            ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '2606:4700:4700::1111'
            ENV['ETH1_IP'] = '20.30.40.50'

            result = render_conf default_route: false

            expect(result).to include "    do-ip6: yes\n"
            expect(result).not_to include 'do-not-query-address'
            expect(result).to include 'forward-addr: 2606:4700:4700::1111'
        end
    end

    it 'should keep IPv6 forwarders' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_USE_ROOTSERVERS'] = 'NO'
        ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '1.1.1.1,2606:4700:4700::1111 2001:4860:4860::8888'

        result = render_conf default_route: true

        expect(result).to include "forward-addr: 1.1.1.1\n    forward-addr: 2606:4700:4700::1111\n" \
                                  "    forward-addr: 2001:4860:4860::8888\n"
    end

    it 'should accept IPv6 CIDRs in ONEAPP_VNF_DNS_ALLOWED_NETWORKS' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = '20.30.0.0/16 2001:db8:abcd::/48'

        result = render_conf

        expect(result).to include "    access-control: 20.30.0.0/16 allow\n    access-control: 2001:db8:abcd::/48 allow\n"
        expect(result).not_to include 'access-control: 2001:db8:1::/64 allow'
        expect(result).to include 'interface: 2001:db8:1::1'
    end

    it 'should NOT duplicate an explicit IPv6 interface' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1/2001:db8:1::1@5353'

        result = render_conf

        expect(result.scan('interface: 2001:db8:1::1@5353').size).to eq 1
        expect(result).not_to include "interface: eth1\n"
    end

    it 'should render the exact IPv4-only config (golden)' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1'
        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        expect(render_conf(default_route: false)).to eq <<~GOLDEN
            server:
                verbosity: 1

                interface: 127.0.0.1
                interface: eth1

                unknown-server-time-limit: 1128

                do-ip4: yes
                do-ip6: no
                do-udp: yes
                do-tcp: yes

                tcp-upstream: no
                udp-upstream-without-downstream: yes

                access-control: 0.0.0.0/0 refuse
                access-control: ::0/0 refuse
                access-control: 127.0.0.0/8 allow
                access-control: 20.30.0.0/16 allow

                cache-min-ttl: 0
                cache-max-ttl: 3600

                logfile: "/var/log/unbound/unbound.log"
                log-identity: ""
                log-time-ascii: yes
                log-queries: no
                log-replies: no
                log-servfail: yes

                root-hints: /usr/share/dns-root-hints/named.root

                hide-identity: yes
                hide-version: yes

                serve-expired: no

                use-systemd: no
                do-daemonize: yes

                local-zone: "vr." static
                local-data: "ip0.eth1.vr. IN A 20.30.40.50"
                local-data: "ep0.eth1.vr. IN A 20.30.40.50"

            remote-control:
                control-enable: no

        GOLDEN
    end

    it 'should resolve upstream over IPv6 on IPv4-only routers with an IPv6 default route' do
        clear_env
        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1'
        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        result = render_conf default_route: true

        expect(result).to include "    interface: eth1\n"
        expect(result).to include "    do-ip6: yes\n"
        expect(result).not_to match(/freebind|do-not-query/)
    end

    it 'should bind explicit addresses of all kinds without the NIC name when the NIC has IPv6' do
        dual_stack_env

        result = render_conf

        expect(result).not_to include "interface: eth1\n"
        %w[20.30.40.50 20.30.40.55 2001:db8:1::1].each do |a|
            expect(result.scan(/^    interface: #{Regexp.escape(a)}$/).size).to eq 1
        end
        expect(result).to include "    ip-freebind: yes\n"
    end

    it 'should keep the NIC name for NICs without IPv6 next to NICs with IPv6' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth2'
        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        result = render_conf

        expect(result).to include "    interface: eth2\n"
        expect(result).not_to include "interface: eth1\n"
    end

    it 'should apply the port of the NIC entry to every bound address' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1@5353'

        result = render_conf

        expect(result).to include "    interface: 20.30.40.50@5353\n    interface: 20.30.40.55@5353\n" \
                                  "    interface: 2001:db8:1::1@5353\n"
    end

    it 'should not repeat an address that is also configured explicitly' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1 eth1/2001:db8:1::1'

        result = render_conf

        expect(result.scan('interface: 2001:db8:1::1').size).to eq 1
        expect(result).not_to include "interface: eth1\n"
    end

    it 'should dedupe the ETHx_VROUTER_IP6 floating address given twice' do
        dual_stack_env
        ENV['ETH1_VROUTER_IP6'] = '2001:db8:1:0::1/64'

        result = render_conf

        expect(result.scan('interface: 2001:db8:1::1').size).to eq 1
    end

    it 'should serve IPv6 and use freebind for an explicit IPv6 interface' do
        dual_stack_env
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1/2001:db8:1::1'

        result = render_conf default_route: false

        expect(result).to include "    interface: 2001:db8:1::1\n"
        expect(result).to include "    ip-freebind: yes\n"
        expect(result).to include "    do-ip6: yes\n"
        expect(result).to include "    do-not-query-address: ::0/0\n"
    end

    it 'should serve IPv6 and use freebind for an explicit IPv6 interface with a port' do
        clear_env
        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth1/2001:db8:1::1@5353'
        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        result = render_conf default_route: false

        expect(result).to include "    interface: 2001:db8:1::1@5353\n"
        expect(result).to include "    ip-freebind: yes\n"
        expect(result).to include "    do-ip6: yes\n"
    end
end
