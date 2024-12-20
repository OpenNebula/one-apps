require 'rspec'
require 'yaml'

$LOAD_PATH << "#{Dir.pwd}/clitester"

require 'init' # Load CLI libraries. These issue opennebula commands to mimic admin behavior
require 'image'

config = YAML.load_file("#{File.dirname(caller_locations.first.absolute_path)}/../metadata.yaml")

VM_TEMPLATE = config[:one][:template][:NAME] || 'base'
IMAGE_DATASTORE = config[:one][:datastore] || 'default'

APPS_PATH = config[:infra][:apps_path] || '/opt/one-apps/export'
DISK_FORMAT = config[:infra][:disk_format] || 'qcow2'

APP_IMAGE_NAME = config[:app][:name]
APP_CONTEXT_PARAMS = config[:app][:context][:params]

ENV['ONE_XMLRPC_TIMEOUT'] = config[:one][:timeout] || '90'

RSpec.shared_context 'vm_handler' do
    before(:all) do
        @info = {} # Used to pass info across tests

        if !CLIImage.list('-l NAME').include?(APP_IMAGE_NAME)

            path = "#{APPS_PATH}/#{APP_IMAGE_NAME}.#{DISK_FORMAT}"

            CLIImage.create(APP_IMAGE_NAME, IMAGE_DATASTORE, "--path #{path}")
        end

        prefixed = config[:app][:context][:prefixed]

        options = "--context #{app_context(APP_CONTEXT_PARAMS, prefixed)} --disk #{APP_IMAGE_NAME}"

        # Create a new VM by issuing onetemplate instantiate VM_TEMPLATE
        @info[:vm] = VM.instantiate(VM_TEMPLATE, true, options)
        @info[:vm].info
    end

    after(:all) do
        generate_context(config)
        @info[:vm].terminate_hard
    end
end

#
# Generate context section for app testing based on app input
#
# @param [Hash] app_context_params CONTEXT section parameters
# @param [Bool] prefixed Custom context parameters have been prefixed with ONEAPP_ on the app logic
#
# @return [String] Comma separated list of context parameters ready to be used with --context on CLI template instantiation
#
def app_context(app_context_params, prefixed = true)
    params = [%(SSH_PUBLIC_KEY=\\"\\$USER[SSH_PUBLIC_KEY]\\"), 'NETWORK="YES"']

    prefixed == true ? prefix = 'ONEAPP_' : prefix = ''

    app_context_params.each do |key, value|
        params << "#{prefix}#{key}=\"#{value}\""
    end

    return params.join(',')
end

#
# Generates tests section for defaults.yaml file for context-kvm input
#
# @param [Hash] metadata App Metadata stated in metadata.yaml
#
def generate_context(metadata)
    name = metadata[:app][:name]

    context_input = <<~EOT
        ---
        :tests:
          '#{metadata[:app][:os][:base]}':
            :image_name: #{name}.#{metadata[:infra][:disk_format]}
            :type: #{metadata[:app][:os][:type]}
            :microenvs: ['context-#{metadata[:app][:hypervisor].downcase}']
            :slow: true
            :enable_netcfg_common: True
            :enable_netcfg_ip_methods: True

    EOT

    short_name = metadata[:app][:name].split('_').last
    context_file_path = "#{Dir.pwd}/../../#{short_name}/context.yaml"

    File.write(context_file_path, context_input)
end
