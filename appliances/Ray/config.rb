# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'erb'
require 'yaml'
require 'fileutils'

BASE_PATH='/etc/one-appliance/service.d/Ray'

# These variables are not exposed to the user and only used during install
ONEAPP_RAY_MODULES = 'default,serve'
ONEAPP_RAY_PORT    = env :ONEAPP_RAY_PORT, '6379'

# ------------------------------------------------------------------------------
# Configuration file for Ray
# ------------------------------------------------------------------------------
ONEAPP_RAY_CONFIG_FILE   = env :ONEAPP_RAY_CONFIG_FILE, ''
ONEAPP_RAY_CONFIG_FILE64 = env :ONEAPP_RAY_CONFIG_FILE64, ''

RAY_CONFIG_TEMPLATE = File.join(BASE_PATH, 'configs/config.yaml.template')
RAY_VLLM_CONFIG_TEMPLATE = File.join(BASE_PATH, 'configs/config_vllm.yaml.template')

RAY_CONFIG_PATH = File.join(BASE_PATH, 'config.yaml')

# ------------------------------------------------------------------------------
# Application to deploy in Ray
# ------------------------------------------------------------------------------
RAY_APPLICATION_PATH = File.join(BASE_PATH, 'model.py')

ONEAPP_RAY_APPLICATION_URL    = env :ONEAPP_AI_APPLICATION_URL, ''
ONEAPP_RAY_APPLICATION_FILE   = env :ONEAPP_AI_APPLICATION_FILE, ''
ONEAPP_RAY_APPLICATION_FILE64 = env :ONEAPP_AI_APPLICATION_FILE64, ''

RAY_APPLICATION_DEFAULT      = File.join(BASE_PATH, 'models/model.py')
RAY_VLLM_APPLICATION_DEFAULT = File.join(BASE_PATH, 'models/model_vllm.py')

# ------------------------------------------------------------------------------
# Configuration parameters for API and inference model
# ------------------------------------------------------------------------------
ONEAPP_RAY_API_PORT  = env :ONEAPP_RAY_API_PORT, '8000'
ONEAPP_RAY_API_ROUTE = env :ONEAPP_RAY_API_ROUTE, '/chat'

ONEAPP_RAY_MODEL_ID          = env :ONEAPP_RAY_MODEL_ID, 'meta-llama/Llama-3.2-1B-Instruct'
ONEAPP_RAY_MODEL_TOKEN       = env :ONEAPP_RAY_MODEL_TOKEN, ''
ONEAPP_RAY_MODEL_TEMPERATURE = env :ONEAPP_RAY_MODEL_TEMPERATURE, '0.1'
ONEAPP_RAY_MODEL_PROMPT      = env :ONEAPP_RAY_MODEL_PROMPT, \
                                   'You are a helpful assisstant. Answer the question.'

ONEAPP_RAY_MODEL_VLLM      = env :ONEAPP_RAY_MODEL_VLLM, 'NO'
ONEAPP_RAY_MODEL_VLLM_ARGS = env :ONEAPP_RAY_MODEL_VLLM_ARGS, ''

ONEAPP_RAY_API_OPENAI = env :ONEAPP_RAY_API_OPENAI, 'NO'

# ------------------------------------------------------------------------------
# Not exposed parameters, this should be computed from VCPU
# ------------------------------------------------------------------------------
ONEAPP_RAY_CHATBOT_REPLICAS = env :ONEAPP_RAY_CHATBOT_REPLICAS, '1'
ONEAPP_RAY_CHATBOT_CPUS     = env :ONEAPP_RAY_CHATBOT_CPUS, '5.0'

def vllm?
    ONEAPP_RAY_MODEL_VLLM || ONEAPP_RAY_API_OPENAI
end

def gen_template_config
    template_path = if vllm?
                        RAY_VLLM_CONFIG_TEMPLATE
                    else
                        RAY_CONFIG_TEMPLATE
                    end

    template = File.read(template_path)

    erb    = ERB.new(template)
    result = erb.result(binding)

    write_file(RAY_CONFIG_PATH, result)
end

def gen_model
    model = if vllm?
                RAY_VLLM_APPLICATION_DEFAULT
            else
                RAY_APPLICATION_DEFAULT
            end

    FileUtils.cp(model, RAY_APPLICATION_PATH)

    FileUtils.chmod 0o755, RAY_APPLICATION_PATH
end

def write_file(path, data, perm = 0o644)
    File.open(path, 'w', perm) do |file|
        file.write(data)
    end
end
