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
end
