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
    it 'should parse env vars' do
        clear_env

        ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = 'eth0'

        # valid
        ENV['ONEAPP_VNF_NAT4_PORT_FWD0'] = '14.15.16.17:1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD1'] = '14.15.16.17:1234:10.11.12.13'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD2'] = '1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD3'] = '2345:10.11.12.13'

        # ignored
        ENV['ONEAPP_VNF_NAT4_PORT_FWD4'] = ''
        ENV['ONEAPP_VNF_NAT4_PORT_FWD5'] = ':'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD6'] = '::'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD7'] = '1234:'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD8'] = '14.15.16.17:1234:10.11.12.13:4321:asd'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD9'] = 'asd:1234:10.11.12.13:4321'

        load './main.rb'; include Service::NAT4

        clear_vars Service::NAT4

        expect(Service::NAT4.parse_env).to eq ({
            dnat: { 0 => ['14.15.16.17', '1234', '10.11.12.13', '4321'],
                    1 => ['14.15.16.17', '1234', '10.11.12.13', nil],
                    2 => [nil, '1234', '10.11.12.13', '4321'],
                    3 => [nil, '2345', '10.11.12.13', nil] },

            masq: %w[eth0]
        })
    end

    it 'should parse and interpolate env vars' do
        clear_env

        ENV['ONEAPP_VNF_NAT4_ENABLED'] = 'YES'
        ENV['ONEAPP_VNF_NAT4_INTERFACES_OUT'] = 'eth1'

        ENV['ETH0_IP'] = '14.15.16.17'
        ENV['ETH0_MASK'] = '255.255.255.0'

        ENV['ETH1_IP'] = '15.16.17.18'
        ENV['ETH1_MASK'] = '255.255.255.0'

        ENV['ONEAPP_VROUTER_ETH0_VIP0'] = '14.15.16.86'

        ENV['ONEAPP_VNF_NAT4_PORT_FWD0'] = '<ETH0_EP0>:1234:10.11.12.13:4321'
        ENV['ONEAPP_VNF_NAT4_PORT_FWD1'] = '<ETH1_EP0>:4321:10.11.12.13'

        load './main.rb'; include Service::NAT4

        clear_vars Service::NAT4

        expect(Service::NAT4.parse_env).to eq ({
            dnat: { 0 => ['14.15.16.86', '1234', '10.11.12.13', '4321'],
                    1 => ['15.16.17.18', '4321', '10.11.12.13', nil] },

            masq: %w[eth1]
        })
    end
end
