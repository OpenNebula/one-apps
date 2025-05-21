# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'erb'
require 'yaml'
require 'fileutils'
require 'etc'

BASE_PATH     = '/etc/one-appliance/service.d/Ray'
VLLM_LOG_FILE = '/var/log/one-appliance/vllm.log'
WEB_PATH      = '/etc/one-appliance/service.d/Ray/client'
PYTHON_VENV   = 'source /root/ray_env/bin/activate'



# These variables are not exposed to the user and only used during install
ONEAPP_RAY_MODULES = 'default,serve'
ONEAPP_RAY_RELEASE_VERSION = env :ONEAPP_RAY_RELEASE_VERSION,'2.45.0'
ONEAPP_RAY_JINJA2_VERSION = env :ONEAPP_RAY_JINJA2_VERSION, '3.1.6'
ONEAPP_RAY_VLLM_VERSION = env :ONEAPP_RAY_VLLM_VERSION, '0.8.5'
ONEAPP_RAY_FLASK_VERSION = env :ONEAPP_RAY_FLASK_VERSION,'3.1.0'
# looks that bitsandbytes ended compatibility with arm64 in 0.42.0
BITSANDBYTES_DEFAULT_VERSION = RbConfig::CONFIG['host_cpu'] =~ /arm64|aarch64/ ? '0.42.0' : '0.45.0'
ONEAPP_RAY_BITSANDBYTES_VERSION = env :ONEAPP_RAY_BITSANDBYTES_VERSION, BITSANDBYTES_DEFAULT_VERSION

ONEAPP_RAY_PORT    = env :ONEAPP_RAY_PORT, '6379'

# ------------------------------------------------------------------------------
# Deployment framework and configuration file
# ------------------------------------------------------------------------------
#   ONEAPP_RAY_AI_FRAMEWORK. Selects the deployment framework for the LLM:
#     - RAY uses ray and serve
#     - VLLM uses vllm tool
#
#   ONEAPP_RAY_CONFIG_FILE64. Not exposed by default, it can be used for automation
#   of custom scenatios
# ------------------------------------------------------------------------------
ONEAPP_RAY_AI_FRAMEWORK = env :ONEAPP_RAY_AI_FRAMEWORK, 'RAY'

ONEAPP_RAY_CONFIG_FILE64 = env :ONEAPP_RAY_CONFIG_FILE64, ''

RAY_CONFIG_TEMPLATE      = File.join(BASE_PATH, 'configs/config.yaml.template')
RAY_VLLM_CONFIG_TEMPLATE = File.join(BASE_PATH, 'configs/config_vllm.yaml.template')

RAY_CONFIG_PATH = File.join(BASE_PATH, 'config.yaml')

# ------------------------------------------------------------------------------
# Application to deploy in Ray
# ------------------------------------------------------------------------------
#   ONEAPP_RAY_APPLICATION_URL. URL to download the python app. Not exposed by
#   default, it can be used for automation of custom scenarios.
#
#   ONEAPP_RAY_APPLICATION_FILE64. Same as above but providing the file (base64)
# ------------------------------------------------------------------------------
RAY_APPLICATION_PATH = File.join(BASE_PATH, 'model.py')

ONEAPP_RAY_APPLICATION_URL    = env :ONEAPP_AI_APPLICATION_URL, ''
ONEAPP_RAY_APPLICATION_FILE64 = env :ONEAPP_AI_APPLICATION_FILE64, ''

# RAY framework using the default chat
RAY_APPLICATION      = File.join(BASE_PATH, 'models/model.py')

# RAY framework using the default chat with OpenAI API
RAY_OAI_APPLICATION  = File.join(BASE_PATH, 'models/model_openai.py')

# VLLM framework using the default chat
RAY_VLLM_APPLICATION = File.join(BASE_PATH, 'models/model_vllm.py')

# ------------------------------------------------------------------------------
# Configuration parameters for API
# ------------------------------------------------------------------------------
#  ONEAPP_RAY_API_PORT port number the API will listen for incoming requests
#
#  ONEAPP_RAY_API_WEB <YES|NO> deploy web application to interact with the model
#
#  ONEAPP_RAY_API_OPENAI <YES|NO> use the OpenAI API to interface with the LLM
# ------------------------------------------------------------------------------
ONEAPP_RAY_API_PORT   = env :ONEAPP_RAY_API_PORT, '8000'
ONEAPP_RAY_API_WEB    = env :ONEAPP_RAY_API_WEB, 'YES'
ONEAPP_RAY_API_OPENAI = env :ONEAPP_RAY_API_OPENAI, 'NO'

RAY_API_ROUTE = '/chat'

# ------------------------------------------------------------------------------
# Model Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_RAY_MODEL_ID: Name of the model in Hugging Face
#
#  ONEAPP_RAY_MODEL_TOKEN: HF API token
#
#  ONEAPP_RAY_MODEL_QUANTIZATION 0,4,8 Use quantization for the LLM weights.
#  (8bits only supported by Ray, 0 = No quantization)
#
#  ONEAPP_RAY_MODEL_MAX_NEW_TOKENS Model context length for prompt and output.
#
#  The following model parameters are only for Ray deployments without OpenAI:
#
#  ONEAPP_RAY_MODEL_TEMPERATURE
#
#  ONEAPP_RAY_MODEL_PROMPT
# ------------------------------------------------------------------------------
ONEAPP_RAY_MODEL_ID    = env :ONEAPP_RAY_MODEL_ID, 'meta-llama/Llama-3.2-1B-Instruct'
ONEAPP_RAY_MODEL_TOKEN = env :ONEAPP_RAY_MODEL_TOKEN, ''

ONEAPP_RAY_MODEL_QUANTIZATION = env :ONEAPP_RAY_MODEL_QUANTIZATION, 0
ONEAPP_RAY_MODEL_MAX_NEW_TOKENS     = env :ONEAPP_RAY_MODEL_MAX_NEW_TOKENS, 1024

ONEAPP_RAY_MODEL_TEMPERATURE = env :ONEAPP_RAY_MODEL_TEMPERATURE, '0.1'
ONEAPP_RAY_MODEL_PROMPT      = env :ONEAPP_RAY_MODEL_PROMPT, \
                                   'You are a helpful assisstant. Answer the question.'

# ------------------------------------------------------------------------------
# Not exposed parameters, this should be computed from VCPU
# ------------------------------------------------------------------------------
ONEAPP_RAY_CHATBOT_REPLICAS = env :ONEAPP_RAY_CHATBOT_REPLICAS, '1'
DEFAULT_RAY_CHATBOT_CPUS = Etc.nprocessors # gets the number of logical processors
ONEAPP_RAY_CHATBOT_CPUS     = env :ONEAPP_RAY_CHATBOT_CPUS, DEFAULT_RAY_CHATBOT_CPUS

def route
    if ONEAPP_RAY_API_OPENAI
        'v1'
    else
        RAY_API_ROUTE
    end
end

def gen_web_config
    config = <<~CONFIG
      base_url: "http://localhost:#{ONEAPP_RAY_API_PORT}/#{route}"
      model: "#{ONEAPP_RAY_MODEL_ID}"
      api_key: "your-api-key-here"
      prompt: "You are a helpful assistant, answer the questions."
    CONFIG

    write_file(File.join(WEB_PATH, 'config.yaml'), config)
end

#TODO
def gen_template_config
  template_path = case ONEAPP_RAY_AI_FRAMEWORK
                  when 'RAY'
                      RAY_CONFIG_TEMPLATE
                  when 'VLLM'
                      if ONEAPP_RAY_API_OPENAI
                          ''
                      else
                          RAY_VLLM_CONFIG_TEMPLATE
                      end
                  end

    return if template_path.empty?

    instantiate_template(template_path, RAY_CONFIG_PATH)
end

def instantiate_template(template_path, output_path)
    template = File.read(template_path)

    # trim
    erb    = ERB.new(template, nil , '-')
    result = erb.result(binding)

    write_file(output_path, result)
end

def gen_model
    model = case ONEAPP_RAY_AI_FRAMEWORK
            when 'RAY'
                if ONEAPP_RAY_API_OPENAI
                    RAY_OAI_APPLICATION
                else
                    RAY_APPLICATION
                end
            when 'VLLM'
                if !ONEAPP_RAY_API_OPENAI
                    RAY_VLLM_APPLICATION
                else
                    ''
                end
            else
                ''
            end

    return if model.empty?

    FileUtils.cp(model, RAY_APPLICATION_PATH)

    FileUtils.chmod 0o755, RAY_APPLICATION_PATH
end

def write_file(path, data, perm = 0o644)
    File.open(path, 'w', perm) do |file|
        file.write(data)
    end
end
