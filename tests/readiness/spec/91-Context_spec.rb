require 'init'

require 'context/requirements'
require 'context/common'
require 'context/linux'
require 'context/service'
require 'context/windows'

# Sometimes OpenNebula is terribly slow
ENV['ONE_XMLRPC_TIMEOUT'] = '90'

describe 'Contextualization' do
    @defaults = RSpec.configuration.defaults

    @defaults[:tests].each do |name, metadata|
        # if additional parameter set, limit test only to particular platform
        next if ENV.key?('RSPEC_PARAM_TEST') &&
            !ENV['RSPEC_PARAM_TEST'].empty? &&
            ENV['RSPEC_PARAM_TEST'] != name

        # some images might be limited to the particular microenv
        next if @defaults.key?(:microenv) &&
            metadata.key?(:microenvs) &&
            ![metadata[:microenvs]].flatten.include?(@defaults[:microenv])

        # lame detect hypervisor
        case @defaults[:microenv]
        when /lxd/
            hv = 'LXD'
        when /lxc/
            hv = 'LXC'
        when /vcenter/
            hv = 'VCENTER'
        else
            hv = 'KVM'
        end

        context "image #{name} on #{hv}" do
            include_examples 'requirements'

            # run service app. tests via a 'service' wrapper,
            # which adds extra common Linux tests
            if metadata[:type] =~ /^service/
                include_examples 'service', metadata[:type], name, hv
            else
                include_examples metadata[:type], name, hv
            end
        end
    end
end
