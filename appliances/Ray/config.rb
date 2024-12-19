# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'erb'
require 'yaml'

# hidden, using during install
ONE_APP_RAY_CONFIGFILE_TEMPLATE_PATH = env :ONE_APP_RAY_CONFIGFILE_TEMPLATE_PATH,
                                           '/root/config.yaml.template'

ONE_APP_RAY_MODULES      = env :ONE_APP_RAY_MODULES, 'default,serve'
ONE_APP_RAY_PORT         = env :ONE_APP_RAY_PORT, '6379'

ONE_APP_RAY_CONFIG_FILE = env :ONE_APP_RAY_CONFIG_FILE, ''
ONE_APP_RAY_CONFIG64 = env :ONE_APP_RAY_CONFIG64, ''
ONE_APP_RAY_CONFIGFILE_DEST_PATH = env :ONE_APP_RAY_CONFIGFILE_DEST_PATH, '/root/config.yaml'

ONE_APP_RAY_MODEL_DEST_PATH = env :ONE_APP_RAY_MODEL_DEST_PATH, '/root/model.py'
ONE_APP_RAY_MODEL_URL = env :ONE_APP_AI_MODEL_URL, ''
ONE_APP_RAY_MODEL64 = env :ONE_APP_AI_MODEL64, ''

# Config yaml parameters
ONE_APP_RAY_SERVE_PORT = env :ONE_APP_RAY_SERVE_PORT, '8000'
ONE_APP_RAY_MODEL_ID = env :ONE_APP_RAY_MODEL_ID, 'meta-llama/Llama-3.2-1B'
ONE_APP_RAY_TOKEN = env :ONE_APP_RAY_TOKEN, ''
ONE_APP_RAY_TEMPERATURE = env :ONE_APP_RAY_TEMPERATURE, '0.1'
ONE_APP_RAY_CHATBOT_REPLICAS = env :ONE_APP_RAY_DEPLOYMENT_REPLICAS, '1'
ONE_APP_RAY_CHATBOT_CPUS = env :ONE_APP_RAY_DEPLOYMENT_CPUS, '5.0'

def gen_template_config(template_path = ONE_APP_RAY_CONFIGFILE_TEMPLATE_PATH,
                        config_path = ONE_APP_RAY_CONFIGFILE_DEST_PATH)
    template = File.read(template_path)

    erb = ERB.new(template)
    result = erb.result(binding)
    write_file(config_path, result)
end

def write_file(path, content)
    File.open(path, 'w') do |file|
        file.write(content)
    end
end
