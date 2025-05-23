# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'

# Base module for OpenNebula services
module Service


    # Dynamo service implementation
    module Dynamo

        extend self

        DEPENDS_ON = []

        def install
            msg :info, 'Dynamo::install'
            install_dependencies
            install_web_dependencies
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'Dynamo::configure'
            generate_engine_extra_args_file
            start_dynamo

            if ONEAPP_DYNAMO_API_WEB
                generate_web_config
                start_web_app
            end
            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'Dynamo::bootstrap'
            begin
                wait_service_available

                msg :info, 'Updating VM with inference endpoint'

                ip  = env('ETH0_IP', '0.0.0.0')
                url = "http://#{ip}:#{ONEAPP_DYNAMO_API_PORT}#{DYNAMO_API_ROUTE}"

                bash "onegate vm update --data \"ONEAPP_DYNAMO_CHATBOT_URL=#{url}\""

                if ONEAPP_DYNAMO_API_WEB
                    url = "http://#{ip}:#{DYNAMO_WEB_APP_PORT}"
                    bash "onegate vm update --data \"ONEAPP_DYNAMO_CHATBOT_WEB=#{url}\""
                end

                msg :info, 'Bootstrap completed successfully'
            rescue StandardError => e
                msg :error, "Error during bootstrap: #{e.message}"
            end
        end
        msg :info, 'Bootstrap completed successfully'
    end

    def install_dependencies
        puts bash <<~SCRIPT
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -yq python3-dev python3-pip python3-venv libucx0
            python3 -m venv #{PYTHON_VENV}
            source #{PYTHON_VENV}/bin/activate
            pip install ai-dynamo[all]==#{ONEAPP_DYNAMO_RELEASE_VERSION}
        SCRIPT
    end

    def install_web_dependencies
        puts bash <<~SCRIPT
            source #{PYTHON_VENV}/bin/activate
            cd /etc/one-appliance/service.d/Dynamo/client
            pip install -r requirements.txt
        SCRIPT
    end

    def start_dynamo
        msg :info, 'Starting Dynamo...'
        pid = spawn(
            { "HF_TOKEN" => ONEAPP_DYNAMO_MODEL_TOKEN },
            "/usr/bin/bash",
            "-c",
            "source #{PYTHON_VENV}/bin/activate; #{dynamo_cmd}",
            :pgroup => true
        )

        Process.detach(pid)
    end

    def start_web_app
        msg :info, 'Starting Dynamo Web App...'
        web_app = 'web_client.py'
        pid = spawn(
            {},
            "/usr/bin/bash",
            "-c",
            "source #{PYTHON_VENV}/bin/activate; cd #{DYNAMO_WEB_APP_DIR}; python3 #{web_app} #{DYNAMO_WEB_APP_PORT}",
            :pgroup => true
        )
        Process.detach(pid)
        msg :info, "Dynamo web app running at http://localhost:#{DYNAMO_WEB_APP_PORT}"
    end

    def dynamo_cmd
        cmd = +"dynamo run"
        cmd << " in=http"
        cmd << " out=#{ONEAPP_DYNAMO_ENGINE_NAME}"
        cmd << " --http-port #{ONEAPP_DYNAMO_API_PORT}"
        cmd << " #{ONEAPP_DYNAMO_MODEL_ID}"
        cmd << " --extra-engine-args #{DYNAMO_EXTRA_ARGS_FILE_PATH}" if (ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON || ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64)
        cmd
    end

    def generate_engine_extra_args_file
        # Prioritize JSON_BASE64 over JSON
        if ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64
            decoded_json = Base64.decode64(ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON_BASE64)
            File.write(DYNAMO_EXTRA_ARGS_FILE_PATH, decoded_json)
        elsif ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON
            File.write(DYNAMO_EXTRA_ARGS_FILE_PATH, ONEAPP_DYNAMO_ENGINE_EXTRA_ARGS_JSON)
        end
    end

    def generate_web_config
        model_without_prefix = ONEAPP_DYNAMO_MODEL_ID.split('/', 2).last
        config = <<~CONFIG
        base_url: "http://localhost:#{ONEAPP_DYNAMO_API_PORT}/#{DYNAMO_API_ROUTE}"
        model: "#{model_without_prefix}"
        CONFIG

        File.write(File.join(DYNAMO_WEB_APP_DIR, 'config.yaml'), config)
    end

    def listening?
        Socket.tcp(DYNAMO_LISTEN_HOST, ONEAPP_DYNAMO_API_PORT, connect_timeout: 5) do |s|
            s.close
            true
        end
    rescue StandardError
        false
    end

    def wait_service_available(timeout: 600, check_interval: 5)
        msg :info, "Waiting for service at http://localhost:#{ONEAPP_DYNAMO_API_PORT}..."

        start_time = Time.now

        loop do
            break if listening?

            if Time.now - start_time > timeout
                raise "Service did not become available in #{timeout} seconds"
            end

            sleep check_interval
        end
    end
end
