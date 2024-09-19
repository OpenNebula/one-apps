require 'init_functionality'

require_relative '../cleanup'
require_relative '../provision'
require_relative 'aws'
require_relative 'tf'

RSpec.describe 'AWS provision [KVM]' do
    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), '../../defaults.yaml')
        )
    end

    hypervisor = 'kvm'
    type       = 'metal'
    instance   = 'c5.metal'

    it_behaves_like 'aws_provision', hypervisor, type, instance
end
