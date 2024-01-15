# frozen_string_literal: true

require 'rspec'

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
        ENV['ONEAPP_VNF_DNS_UDP_DISABLED'] = 'YES'

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

        ENV['ETH1_ALIAS0_IP'] = '20.30.40.55'
        ENV['ETH1_ALIAS0_MASK'] = '255.255.0.0'

        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        ENV['ETH3_IP'] = '40.50.60.70'
        ENV['ETH3_MASK'] = '255.255.255.0'

        load './main.rb'; include Service::DNS

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
            interfaces: { 'eth1' => { addr: '20.30.40.50', name: 'eth1', port: nil },
                          'eth2' => { addr: '30.40.50.60', name: 'eth2', port: nil },
                          'eth3' => { addr: '40.50.60.70', name: 'eth3', port: nil } },

            nameservers: %w[1.1.1.1 8.8.8.8],

            networks: %w[20.30.0.0/16 30.0.0.0/8]
        })
    end
end
