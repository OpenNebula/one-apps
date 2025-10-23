# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'yaml'
require 'fileutils'

BASE_PATH     = '/etc/one-appliance/service.d/Vllm'
VLLM_LOG_FILE = '/var/log/one-appliance/vllm.log'
WEB_PATH      = '/etc/one-appliance/service.d/Vllm/client'
PYTHON_VENV_CPU_PATH   = '/root/vllm_cpu_env'
PYTHON_VENV_GPU_PATH   = '/root/vllm_gpu_env'
PYTHON_VENV_WEB_PATH   = '/root/vllm_web_env'

VLLM_API_ROUTE='/v1'

DEFAULT_GPU_MEMORY_UTILIZATION = "0.9"

# These variables are not exposed to the user and only used during install
ONEAPP_VLLM_RELEASE_VERSION = env :ONEAPP_VLLM_RELEASE_VERSION, '0.10.2'
ONEAPP_VLLM_CUDA_VERSION   = env :ONEAPP_VLLM_CUDA_VERSION, '129'
INSTALL_DRIVERS            = env :INSTALL_DRIVERS, 'true'

# ------------------------------------------------------------------------------
# Configuration parameters for API
# ------------------------------------------------------------------------------
#  ONEAPP_VLLM_API_PORT port number the API will listen for incoming requests
#
#  ONEAPP_VLLM_API_WEB <YES|NO> deploy web application to interact with the model
#
# ------------------------------------------------------------------------------
ONEAPP_VLLM_API_PORT   = env :ONEAPP_RAY_API_PORT, '8000'
ONEAPP_VLLM_API_WEB    = env :ONEAPP_VLLM_API_WEB, 'YES'

# ------------------------------------------------------------------------------
# Model Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_VLLM_MODEL_ID: Name of the model in Hugging Face.
#
#  ONEAPP_VLLM_MODEL_TOKEN: Hugging Face API token.
#
#  ONEAPP_VLLM_MODEL_QUANTIZATION 0,4 Use quantization for the LLM weights.
#  (0 = No quantization)
#
#  ONEAPP_VLLM_MODEL_MAX_LENGTH Model context length for prompt and output.
#  Defaults to "1024".
#
#  ONEAPP_VLLM_ENFORCE_EAGER <YES|NO> Whether to always use eager-mode
#  PyTorch in vllm.
#
#  ONEAPP_VLLM_SLEEP_MODE <YES|NO> Whether to enable sleep mode when GPU is used.
#
#  ONEAPP_VLLM_GPU_MEMORY_UTILIZATION Float (0.0, 1.0] Fraction of GPU memory to use.
#  Defaults to "0.9".
# ------------------------------------------------------------------------------
ONEAPP_VLLM_MODEL_ID    = env :ONEAPP_VLLM_MODEL_ID, 'Qwen/Qwen2.5-1.5B-Instruct'
ONEAPP_VLLM_MODEL_TOKEN = env :ONEAPP_VLLM_MODEL_TOKEN, ''

ONEAPP_VLLM_MODEL_QUANTIZATION      = env :ONEAPP_VLLM_MODEL_QUANTIZATION, 0
ONEAPP_VLLM_MODEL_MAX_LENGTH        = env :ONEAPP_VLLM_MODEL_MAX_LENGTH, 1024
ONEAPP_VLLM_ENFORCE_EAGER           = env :ONEAPP_VLLM_ENFORCE_EAGER, 'NO'
ONEAPP_VLLM_SLEEP_MODE              = env :ONEAPP_VLLM_SLEEP_MODE, 'NO'
ONEAPP_VLLM_GPU_MEMORY_UTILIZATION  = env :ONEAPP_VLLM_GPU_MEMORY_UTILIZATION, DEFAULT_GPU_MEMORY_UTILIZATION

def gen_web_config
    config = <<~CONFIG
      base_url: "http://localhost:#{ONEAPP_VLLM_API_PORT}#{VLLM_API_ROUTE}"
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
