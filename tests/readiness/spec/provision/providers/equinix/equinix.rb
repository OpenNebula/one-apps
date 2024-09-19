RSpec.shared_examples_for 'equinix_provision' do |hypervisor, type, instance|
    provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                    "#{type}/providers/equinix/equinix-sv.yml"

    inputs = 'number_hosts=2,' <<
             "equinix_plan=#{instance}," <<
             'equinix_os=ubuntu_22_04,' <<
             'number_public_ips=2,' <<
             'dns=1.1.1.1,' <<
             "one_hypervisor=#{hypervisor}"

    before(:all) do
        @info = {}
    end

    it_behaves_like 'provision', hypervisor, type, provider_path, inputs

    it_behaves_like 'cleanup'
end
