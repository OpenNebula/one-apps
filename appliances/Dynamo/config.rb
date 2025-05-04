# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end


PYTHON_VENV = "/root/dynamo_venv"
DYNAMO_API_ROUTE  = '/v1/chat/completions'
DYNAMO_LISTEN_HOST = '0.0.0.0'
DYNAMO_EXTRA_ARGS_FILE_PATH = '/tmp/engine_extra_args.json'

# These variables are not exposed to the user and only used during install
ONEAPP_DYNAMO_RELEASE_VERSION = env :ONEAPP_DYNAMO_RELEASE_VERSION, '0.1.1'

# Dynamo configuration parameters

# ------------------------------------------------------------------------------
# Dynamo API Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_DYNAMO_API_PORT: Port where the Dynamo API will be exposed
# ------------------------------------------------------------------------------
ONEAPP_DYNAMO_API_PORT   = env :ONEAPP_DYNAMO_API_PORT, '8000'

# ------------------------------------------------------------------------------
# Model Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_DYNAMO_MODEL_ID: Name of the model in Hugging Face
#
#  ONEAPP_DYNAMO_MODEL_TOKEN: HF API token
# ------------------------------------------------------------------------------
ONEAPP_DYNAMO_MODEL_ID  = env :ONEAPP_DYNAMO_MODEL_ID, 'Qwen/Qwen2.5-1.5B-Instruct'
ONEAPP_DYNAMO_MODEL_TOKEN = env :ONEAPP_DYNAMO_MODEL_TOKEN, ''

# ------------------------------------------------------------------------------
# Engine Parameters
# ------------------------------------------------------------------------------
#  ONEAPP_DYNAMO_ENGINE_NAME: Name of the dynamo engine to use.
#       Available engines: mistralrs|sglang|llamacpp|vllm|trtllm|echo_full|echo_core
#
#  ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON: Engine extra args set in JSON format.
#
#   ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64: Engine extra args set in JSON
#       and encoded in base64.
# ------------------------------------------------------------------------------
ONEAPP_DYNAMO_ENGINE_NAME = env :ONEAPP_DYNAMO_ENGINE_NAME, 'vllm'
ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON = env :ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON, nil
ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64 = env :ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64, nil
