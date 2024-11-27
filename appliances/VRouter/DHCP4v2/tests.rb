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
    it 'should provide and parse all env vars' do
        clear_env

        ENV['ONEAPP_VNF_DHCP4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_AUTHORITATIVE'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_MAC2IP_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_MAC2IP_MACPREFIX'] = '02:00'

        ENV['ONEAPP_VNF_DHCP4_LEASE_TIME'] = '3600'

        ENV['ONEAPP_VNF_DHCP4_GATEWAY'] = '1.2.3.4'
        ENV['ONEAPP_VNF_DHCP4_DNS'] = '1.1.1.1'

        ENV['ONEAPP_VNF_DHCP4_INTERFACES'] = 'eth0 eth1 eth2 eth3'
        ENV['ETH0_VROUTER_MANAGEMENT'] = 'YES'

        ENV['ONEAPP_VNF_DHCP4_ETH2'] = '30.0.0.0/8:30.40.50.64-30.40.50.68'
        ENV['ONEAPP_VNF_DHCP4_ETH2_GATEWAY'] = '30.40.50.1'
        ENV['ONEAPP_VNF_DHCP4_ETH2_DNS'] = '8.8.8.8'

        ENV['ONEAPP_VNF_DHCP4_ETH3_GATEWAY'] = '40.50.60.1'
        ENV['ONEAPP_VNF_DHCP4_ETH3_DNS'] = '8.8.4.4'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.0.0'

        ENV['ETH1_ALIAS0_IP'] = '5.6.7.8' # ignored (unsupported)
        ENV['ETH1_ALIAS0_MASK'] = '255.255.255.0' # ignored (unsupported)

        ENV['ETH2_IP'] = '30.40.50.60'
        ENV['ETH2_MASK'] = '255.0.0.0'

        ENV['ETH3_IP'] = '40.50.60.70'
        ENV['ETH3_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '1.2.3.4' # ignored (not in the subnet)

        load './main.rb'; include Service::DHCP4v2

        allow(Service::DHCP4v2).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 },
            { 'mtu' => 3333 }
        )

        clear_vars Service::DHCP4v2

        expect(Service::DHCP4v2.parse_env).to eq ({
            'eth1' => [ { address: '20.30.40.50',
                          dns:     '1.1.1.1',
                          gateway: '1.2.3.4',
                          mtu:     1111,
                          range:   '20.30.0.2-20.30.255.254',
                          subnet:  '20.30.0.0/16',
                          vips:    %w[20.30.40.55] } ],

            'eth2' => [ { address: '30.40.50.60',
                          dns:     '8.8.8.8',
                          gateway: '30.40.50.1',
                          mtu:     2222,
                          range:   '30.40.50.64-30.40.50.68',
                          subnet:  '30.0.0.0/8',
                          vips:    %w[] } ],

            'eth3' => [ { address: '40.50.60.70',
                          dns:     '8.8.4.4',
                          gateway: '40.50.60.1',
                          mtu:     3333,
                          range:   '40.50.60.2-40.50.60.254',
                          subnet:  '40.50.60.0/24',
                          vips:    %w[] } ]
        })

        output = <<~'ONELEASE_CONF'
            ---
            eth1:
              server4:
                listen:
                - "%eth1"
                plugins:
                - lease_time: 3600s
                - server_id: 20.30.40.50
                - dns: 1.1.1.1
                - mtu: 1111
                - router: 1.2.3.4
                - netmask: 255.255.0.0
                - range: leases-eth1.sqlite3 20.30.0.2 20.30.255.254 3600s --excluded-ips 20.30.40.50,20.30.40.55
                    --mac2ip --mac2ip-prefix 02:00
                - onelease:
            eth2:
              server4:
                listen:
                - "%eth2"
                plugins:
                - lease_time: 3600s
                - server_id: 30.40.50.60
                - dns: 8.8.8.8
                - mtu: 2222
                - router: 30.40.50.1
                - netmask: 255.0.0.0
                - range: leases-eth2.sqlite3 30.40.50.64 30.40.50.68 3600s --excluded-ips 30.40.50.60
                    --mac2ip --mac2ip-prefix 02:00
                - onelease:
            eth3:
              server4:
                listen:
                - "%eth3"
                plugins:
                - lease_time: 3600s
                - server_id: 40.50.60.70
                - dns: 8.8.4.4
                - mtu: 3333
                - router: 40.50.60.1
                - netmask: 255.255.255.0
                - range: leases-eth3.sqlite3 40.50.60.2 40.50.60.254 3600s --excluded-ips 40.50.60.70
                    --mac2ip --mac2ip-prefix 02:00
                - onelease:
        ONELEASE_CONF

        allow(Service::DHCP4v2).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 },
            { 'mtu' => 3333 }
        )

        Dir.mktmpdir do |dir|
            Service::DHCP4v2.configure basedir: dir
            result = File.read "#{dir}/onelease-config.yml"
            expect(result.strip).to eq output.strip
        end
    end

    it 'should interpolate GW and DNS values' do
        clear_env

        ENV['ONEAPP_VNF_DHCP4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_DHCP4_INTERFACES'] = 'eth0 eth1'

        ENV['ONEAPP_VNF_DHCP4_ETH0_GATEWAY'] = '<ETH0_EP0>'
        ENV['ONEAPP_VNF_DHCP4_ETH0_DNS'] = '<ETH0_EP0>'

        ENV['ONEAPP_VNF_DHCP4_ETH1_GATEWAY'] = '<ETH1_VIP0>'
        ENV['ONEAPP_VNF_DHCP4_ETH1_DNS'] = '<ETH1_VIP1>'

        ENV['ETH0_IP'] = '10.20.30.40'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '20.30.40.50'
        ENV['ETH1_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '10.20.30.45'
        ENV['ONEAPP_VROUTER_ETH1_VIP0'] = '20.30.40.55'
        ENV['ONEAPP_VROUTER_ETH1_VIP1'] = '20.30.40.110'

        load './main.rb'; include Service::DHCP4v2

        allow(Service::DHCP4v2).to receive(:ip_link_show).and_return(
            { 'mtu' => 1111 },
            { 'mtu' => 2222 }
        )

        clear_vars Service::DHCP4v2

        expect(Service::DHCP4v2.parse_env).to eq ({
            'eth0' => [ { address: '10.20.30.40',
                          dns:     '10.20.30.45',
                          gateway: '10.20.30.45',
                          mtu:     1111,
                          range:   '10.20.30.2-10.20.30.254',
                          subnet:  '10.20.30.0/24',
                          vips:    %w[10.20.30.45] } ],

            'eth1' => [ { address: '20.30.40.50',
                          dns:     '20.30.40.110',
                          gateway: '20.30.40.55',
                          mtu:     2222,
                          range:   '20.30.40.2-20.30.40.254',
                          subnet:  '20.30.40.0/24',
                          vips:    %w[20.30.40.55 20.30.40.110] } ]
        })
    end
end
