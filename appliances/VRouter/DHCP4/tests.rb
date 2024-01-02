# frozen_string_literal: true

require 'rspec'

def clear_env
    ENV.delete_if { |name| name.include?('VROUTER_') || name.include?('_VNF_') }
end

def clear_vars(object)
    object.instance_variables.each { |name| object.remove_instance_variable(name) }
end

RSpec.describe self do
    it 'should provide and parse all env vars' do
        clear_env

        ENV['ONEAPP_VNF_DHCP4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_AUTHORITATIVE'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_MAC2IP_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX'] = '02:00'

        ENV['ONEAPP_VNF_DHCP4_LEASE_TIME'] = '3600'

        ENV['ONEAPP_VNF_DHCP4_GATEWAY'] = '1.2.3.4'
        ENV['ONEAPP_VNF_DHCP4_DNS'] = '1.1.1.1'

        ENV['ONEAPP_VNF_DHCP4_INTERFACES'] = 'lo/127.0.0.1 eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_ETH2'] = '30.0.0.0/8:30.40.50.64-30.40.50.68'
        ENV['ONEAPP_VNF_DHCP4_ETH2_GATEWAY'] = '30.40.50.1'
        ENV['ONEAPP_VNF_DHCP4_ETH2_DNS'] = '8.8.8.8'

        ENV['ONEAPP_VNF_DHCP4_ETH3_GATEWAY'] = '40.50.60.1'
        ENV['ONEAPP_VNF_DHCP4_ETH3_DNS'] = '8.8.4.4'

        load './main.rb'; include Service::DHCP4

        allow(Service::DHCP4).to receive(:ip_addr_list).and_return([
            { 'ifname'    => 'lo',
              'addr_info' => [ { 'family'    => 'inet',
                                 'local'     => '127.0.0.1',
                                 'prefixlen' => 8 } ] },

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

        allow(Service::DHCP4).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 },
            { 'mtu' => 3333 },
            { 'mtu' => 4444 },
        )

        clear_vars Service::DHCP4

        expect(Service::DHCP4.parse_env).to eq ({
            'lo' => {
                address: '127.0.0.1',
                dns:     '1.1.1.1',
                gateway: '1.2.3.4',
                mtu:     1111,
                range:   '127.0.0.2-127.255.255.254',
                subnet:  '127.0.0.0/8',
            },
            'eth1' => {
                address: '20.30.40.50',
                dns:     '1.1.1.1',
                gateway: '1.2.3.4',
                mtu:     2222,
                range:   '20.30.0.2-20.30.255.254',
                subnet:  '20.30.0.0/16',
            },
            'eth2' => {
                address: '30.40.50.60',
                dns:     '8.8.8.8',
                gateway: '30.40.50.1',
                mtu:     3333,
                range:   '30.40.50.64-30.40.50.68',
                subnet:  '30.0.0.0/8',
            },
            'eth3' => {
                address: '40.50.60.70',
                dns:     '8.8.4.4',
                gateway: '40.50.60.1',
                mtu:     4444,
                range:   '40.50.60.2-40.50.60.254',
                subnet:  '40.50.60.0/24',
            },
        })
    end
end
