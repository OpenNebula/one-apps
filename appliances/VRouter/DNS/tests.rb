# frozen_string_literal: true

require 'rspec'

def clear_env
    ENV.delete_if { |name| name.include?('VROUTER_') || name.include?('_VNF_') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide and parse all env vars (default networks)' do
        clear_env

        ENV['ONEAPP_VNF_DNS_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_TCP_DISABLED'] = 'YES'
        ENV['ONEAPP_VNF_DNS_UDP_DISABLED'] = 'YES'

        ENV['ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT'] = '123'
        ENV['ONEAPP_VNF_DNS_MAX_CACHE_TTL'] = '234'

        ENV['ONEAPP_VNF_DNS_USE_ROOTSERVERS'] = 'YES'
        ENV['ONEAPP_VNF_DNS_NAMESERVERS'] = '1.1.1.1 8.8.8.8'

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = ''

        load './main.rb'; include Service::DNS

        allow(Service::DNS).to receive(:ip_addr_list).and_return([
            { 'ifname'    => 'eth0',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '10.20.30.40',
                                 'prefixlen' => 24 } ] },

            { 'ifname'    => 'eth1',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '20.30.40.50',
                                 'prefixlen' => 16 } ] },

            { 'ifname'    => 'eth2',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '30.40.50.60',
                                 'prefixlen' => 8 } ] },

            { 'ifname'    => 'eth3',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '40.50.60.70',
                                 'prefixlen' => 24 } ] },
        ])

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth1' => { addr: '20.30.40.50', name: 'eth1', port: nil },
                          'eth2' => { addr: '30.40.50.60', name: 'eth2', port: nil },
                          'eth3' => { addr: '40.50.60.70', name: 'eth3', port: nil } },

            nameservers: %w[1.1.1.1 8.8.8.8],

            networks: %w[20.30.0.0/16 30.0.0.0/8 40.50.60.0/24],
        })
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

        ENV['ONEAPP_VNF_DNS_INTERFACES'] = 'eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DNS_ALLOWED_NETWORKS'] = '20.30.0.0/16 30.0.0.0/8'

        load './main.rb'; include Service::DNS

        allow(Service::DNS).to receive(:ip_addr_list).and_return([
            { 'ifname'    => 'eth0',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '10.20.30.40',
                                 'prefixlen' => 24 } ] },

            { 'ifname'    => 'eth1',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '20.30.40.50',
                                 'prefixlen' => 16 } ] },

            { 'ifname'    => 'eth2',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '30.40.50.60',
                                 'prefixlen' => 8 } ] },

            { 'ifname'    => 'eth3',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '40.50.60.70',
                                 'prefixlen' => 24 } ] },
        ])

        clear_vars Service::DNS

        expect(Service::DNS.parse_env).to eq ({
            interfaces: { 'eth1' => { addr: '20.30.40.50', name: 'eth1', port: nil },
                          'eth2' => { addr: '30.40.50.60', name: 'eth2', port: nil },
                          'eth3' => { addr: '40.50.60.70', name: 'eth3', port: nil } },

            nameservers: %w[1.1.1.1 8.8.8.8],

            networks: %w[20.30.0.0/16 30.0.0.0/8],
        })
    end
end
