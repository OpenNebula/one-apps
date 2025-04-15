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


ONEAPP_DYNAMO_ENGINE = env :ONEAPP_DYNAMO_ENGINE, 'vllm' # available: mistralrs|sglang|llamacpp|vllm|trtllm|echo_full|echo_core
ONEAPP_DYNAMO_API_PORT   = env :ONEAPP_DYNAMO_API_PORT, '8000'
ONEAPP_DYNAMO_MODEL_ID  = env :ONEAPP_DYNAMO_MODEL_ID, 'Qwen/Qwen2.5-1.5B-Instruct'
ONEAPP_DYNAMO_MODEL_TOKEN = env :ONEAPP_DYNAMO_MODEL_TOKEN, ''
ONEAPP_DYNAMO_MODEL_EXTRA_ARGS_JSON = env :ONEAPP_DYNAMO_MODEL_EXTRA_ARGS_JSON, nil
ONEAPP_DYNAMO_MODEL_EXTRA_ARGS_JSON_BASE64 = env :ONEAPP_DYNAMO_MODEL_EXTRA_ARGS_JSON_BASE64, nil
