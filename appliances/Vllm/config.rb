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
PYTHON_VENV_CPU_PATH   = '/root/vllm_cpu_env'
PYTHON_VENV_GPU_PATH   = '/root/vllm_gpu_env'



# These variables are not exposed to the user and only used during install
ONEAPP_VLLM_RELEASE_VERSION = env :ONEAPP_VLLM_RELEASE_VERSION, '0.10.2'
ONEAPP_VLLM_CUDA_VERSION   = env :ONEAPP_VLLM_CUDA_VERSION, '128'

# Appliance args
ONEAPP_VLLM_MODEL_ID    = env :ONEAPP_VLLM_MODEL_ID, 'meta-llama/Llama-3.2-1B-Instruct'
ONEAPP_VLLM_MODEL_TOKEN = env :ONEAPP_VLLM_MODEL_TOKEN, ''

# ------------------------------------------------------------------------------
# Configuration parameters for API
# ------------------------------------------------------------------------------
#  ONEAPP_VLLM_API_PORT port number the API will listen for incoming requests
#
#  ONEAPP_VLLM_API_WEB <YES|NO> deploy web application to interact with the model
#
#  ONEAPP_VLLM_API_OPENAI <YES|NO> use the OpenAI API to interface with the LLM
# ------------------------------------------------------------------------------
ONEAPP_VLLM_API_PORT   = env :ONEAPP_RAY_API_PORT, '8000'
ONEAPP_VLLM_API_WEB    = env :ONEAPP_VLLM_API_WEB, 'YES'
ONEAPP_VLLM_API_OPENAI = env :ONEAPP_VLLM_API_OPENAI, 'NO'

VLLM_API_ROUTE = '/chat'

# ------------------------------------------------------------------------------
# Model Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_VLLM_MODEL_ID: Name of the model in Hugging Face
#
#  ONEAPP_VLLM_MODEL_TOKEN: HF API token
#
#  ONEAPP_VLLM_MODEL_QUANTIZATION 0,4,8 Use quantization for the LLM weights.
#  (8bits only supported by Ray, 0 = No quantization)
#
#  ONEAPP_VLLM_MODEL_MAX_NEW_TOKENS Model context length for prompt and output.
#
#  The following model parameters are only for Ray deployments without OpenAI:
#
#  ONEAPP_VLLM_MODEL_TEMPERATURE
#
#  ONEAPP_VLLM_MODEL_PROMPT
# ------------------------------------------------------------------------------
ONEAPP_VLLM_MODEL_ID    = env :ONEAPP_VLLM_MODEL_ID, 'meta-llama/Llama-3.2-1B-Instruct'
ONEAPP_VLLM_MODEL_TOKEN = env :ONEAPP_VLLM_MODEL_TOKEN, ''

ONEAPP_VLLM_MODEL_QUANTIZATION = env :ONEAPP_VLLM_MODEL_QUANTIZATION, 0
ONEAPP_VLLM_MODEL_MAX_NEW_TOKENS     = env :ONEAPP_VLLM_MODEL_MAX_NEW_TOKENS, 1024

# ------------------------------------------------------------------------------
# Not exposed parameters, this should be computed from VCPU
# ------------------------------------------------------------------------------
DEFAULT_RAY_CHATBOT_CPUS = Etc.nprocessors # gets the number of logical processors
ONEAPP_RAY_CHATBOT_CPUS     = env :ONEAPP_RAY_CHATBOT_CPUS, DEFAULT_RAY_CHATBOT_CPUS

def route
    if ONEAPP_VLLM_API_OPENAI
        'v1'
    else
        VLLM_API_ROUTE
    end
end

def gen_web_config
    config = <<~CONFIG
      base_url: "http://localhost:#{ONEAPP_VLLM_API_PORT}/#{route}"
      model: "#{ONEAPP_VLLM_MODEL_ID}"
      api_key: "your-api-key-here"
      prompt: "You are a helpful assistant, answer the questions."
    CONFIG

    write_file(File.join(WEB_PATH, 'config.yaml'), config)
end


def write_file(path, data, perm = 0o644)
    File.open(path, 'w', perm) do |file|
        file.write(data)
    end
end
