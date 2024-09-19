require_relative 'linux'

require_relative 'service/vrouter'
require_relative 'service/wordpress'
require_relative 'service/harbor'

shared_examples_for 'service' do |type, name, hv|
    if type == 'service_VRouter'
        # No need to go greedy with VNF appliance
        vm_context = "MEMORY=1536\nVCPU=1"
    else
        # Rest appliances are extremely hungry
        vm_context = "MEMORY=3072\nVCPU=2"
    end

    case hv
    when /VCENTER/
        prefix = 'sd'
    else
        prefix = 'vd'
    end

    # run limited common tests
    context 'Linux' do
        context 'common (1)' do
            include_examples 'context_linux_common1', name, hv, prefix, vm_context
        end

        context 'common (2)' do
            include_examples 'context_linux_common2', name, hv, prefix, vm_context
        end
    end

    # continue with service type specific tests
    context 'Service' do
        # configure type specific defaults if exist
        fn = File.join(File.dirname(__FILE__), 'service/defaults.yaml')

        if File.exist?(fn)
            td = YAML.load_file(fn)
            @type_defaults = td[type] if td.key?(type)
        end

        include_examples type, name, hv
    end
end
