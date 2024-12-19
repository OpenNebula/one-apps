# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require 'yaml'

require_relative 'config'

RSpec.describe 'generate_config_yaml_from_template' do
    it 'generate template from user inputs' do
        stub_const 'ONE_APP_RAY_SERVE_PORT', '8888'
        stub_const 'ONE_APP_RAY_MODEL_ID', 'meta-llama/Llama-3.3-1C'
        stub_const 'ONE_APP_RAY_TOKEN', '**REDACTED**'
        stub_const 'ONE_APP_RAY_TEMPERATURE', '0.4'
        stub_const 'ONE_APP_RAY_CHATBOT_CPUS', '4.0'
        stub_const 'ONE_APP_RAY_CHATBOT_REPLICAS', 2

        output = YAML.load_stream <<~CONFIG
            proxy_location: EveryNode

            http_options:
              host: 0.0.0.0
              port: 8888

            grpc_options:
              port: 9000
              grpc_servicer_functions: []

            logging_config:
              encoding: TEXT
              log_level: INFO
              logs_dir: null
              enable_access_log: true


            applications:
            - name: app1
              route_prefix: /
              import_path: model:app_builder
              runtime_env:
                pip:
                - transformers
                - fastapi
                - torch
                - torchvision
                - torchaudio
              args:
                model_id: "meta-llama/Llama-3.3-1C"
                token: "**REDACTED**"
                temperature: 0.4
              deployments:
              #- name: Translator
              - name: ChatBot
                num_replicas: 2
                ray_actor_options:
                  num_cpus: 4.0
                  num_gpus: 0.0
        CONFIG
        Dir.mktmpdir do |temp_dir|
            template_path = File.expand_path('config.yaml.template', __dir__)
            gen_template_config template_path, "#{temp_dir}/config.yaml"
            result = YAML.load_stream File.read "#{temp_dir}/config.yaml"
            expect(result).to eq output
        end
    end
end
