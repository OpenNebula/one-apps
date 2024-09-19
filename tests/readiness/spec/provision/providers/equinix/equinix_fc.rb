require 'init_functionality'

require_relative '../cleanup'
require_relative '../provision'
require_relative 'equinix'

RSpec.describe 'Equinix provision [Firecracker]' do
    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), '../../defaults.yaml')
        )
    end

    hypervisor = 'firecracker'
    type       = 'metal'
    instance   = 'c3.medium'

    it_behaves_like 'equinix_provision', hypervisor, type, instance
end
