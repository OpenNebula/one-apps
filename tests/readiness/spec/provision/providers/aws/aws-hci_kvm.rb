require 'init_functionality'

require_relative '../cleanup'
require_relative '../provision_hci'
require_relative 'aws-hci'
require_relative 'tf-hci'

RSpec.describe 'AWS HCI provision [KVM]' do
    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), '../../defaults.yaml')
        )
    end

    hypervisor = 'kvm'
    type       = 'metal'
    instance   = 'c5.metal'

    it_behaves_like 'aws_hci_provision', hypervisor, type, instance
end
