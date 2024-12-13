require 'rspec'
require 'yaml'

require_relative 'init' # Load CLI libraries. These issue opennebula commands to mimic admin behavior
require_relative 'image'

config = YAML.load_file(File.join(Dir.pwd, 'defaults.yaml'))

VM_TEMPLATE = config[:one][:template] || 'base'
APPS_PATH = config[:infra][:apps_path] || '/opt/one-apps/export'
DISK_FORMAT = config[:infra][:disk_format] || 'qcow2'
IMAGE_DATASTORE = config[:one][:datastore] || 'default'

APP_IMAGE_NAME = config[:app][:name]
APP_IMAGE_PATH = "#{config[:one][:template]}/#{APP_IMAGE_NAME}.#{DISK_FORMAT}"

ENV['ONE_XMLRPC_TIMEOUT'] = config[:one][:template] || '90'

RSpec.shared_context 'vm_handler' do
    before(:all) do
        @info = {} # Used to pass info across tests

        if !CLIImage.list('-l NAME').include?(APP_IMAGE_NAME)
            CLIImage.create(APP_IMAGE_NAME, IMAGE_DATASTORE, "--path #{APP_IMAGE_PATH}")
        end

        options = "--context #{app_context(APP_CONTEXT_PARAMS)} --disk #{APP_IMAGE_NAME}"

        # Create a new VM by issuing onetemplate instantiate VM_TEMPLATE
        @info[:vm] = VM.instantiate(VM_TEMPLATE, true, options)
    end

    after(:all) do
        @info[:vm].terminate_hard
    end
end

#
# Generate context section for app testing based on app input
#
# @param [Hash] app_context_params CONTEXT section parameters
#
# @return [String] Comma separated list of context parameters ready to be used with --context on CLI template instantiation
#
def app_context(app_context_params)
    params = [%(SSH_PUBLIC_KEY=\\"\\$USER[SSH_PUBLIC_KEY]\\"), 'NETWORK="YES"']

    app_context_params.each do |key, value|
        params << "ONEAPP_#{key}=\"#{value}\""
    end

    return params.join(',')
end
