require 'init'
require 'context/requirements'
require 'context/common'
require 'context/linux'
require 'context/service'
require 'context/windows'

ENV['ONE_XMLRPC_TIMEOUT'] = '90'
HV = 'KVM'

describe 'Contextualization' do
    @defaults = RSpec.configuration.defaults

    @defaults[:apps][:linux].each do |name, _metadata|
        context "image #{name} on #{HV}" do
            include_examples 'requirements'
            include_examples 'linux', name, HV
        end
    end
end