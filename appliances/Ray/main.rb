# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'

require 'socket'
require 'open3'

# Base module for OpenNebula services
module Service

    # Ray service implmentation
    module Ray

        extend self

        DEPENDS_ON    = []

        VLLM_LOG_FILE = "/var/log/one-appliance/vllm.log"

        def install
            msg :info, 'Ray::install'
            install_dependencies
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'Ray::configure'
            load_application_file
            generate_config_file

            if ONEAPP_RAY_API_OPENAI
                run_vllm
            else
                start_ray
                run_serve
            end

            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'Ray::bootstrap'
            begin
                wait_service_available

                msg :info, 'Updating VM with inference endpoint'

                ip  = env('ETH0_IP', '0.0.0.0')
                url = "http://#{ip}:#{ONEAPP_RAY_API_PORT}#{ONEAPP_RAY_API_ROUTE}"

                bash "onegate vm update --data \"ONEAPP_RAY_CHATBOT_URL=#{url}\""

                msg :info, 'Bootstrap completed successfully'
            rescue StandardError => e
                msg :error, "Error during bootstrap: #{e.message}"
            end
        end

    end

    def install_dependencies
        puts bash <<~SCRIPT
            apt-get update
            apt-get install -y python3 python3-pip
            apt remove -y python3-jinja2
            pip3 install ray[#{ONEAPP_RAY_MODULES}] jinja2==3.1.4 vllm
        SCRIPT
    end

    def start_ray
        msg :info, 'Starting Ray...'
        puts bash "ray start --head --port=#{ONEAPP_RAY_PORT}"
    end

    def load_application_file
        if !ONEAPP_RAY_APPLICATION_FILE64.empty?
            msg :info, "Copying model file to #{RAY_APPLICATION_PATH}..."

            app = Base64.decode64(ONEAPP_RAY_APPLICATION_FILE64)

            write_file(RAY_APPLICATION_PATH, app , 0o775)
        elsif !ONEAPP_RAY_APPLICATION_FILE.empty?
            msg :info, "Copying model file64 to #{RAY_APPLICATION_PATH}..."

            write_file(RAY_APPLICATION_PATH, ONEAPP_RAY_APPLICATION_FILE, 0o775)
        elsif !ONEAPP_RAY_APPLICATION_URL.empty?
            msg :info, "Downloading model from #{ONEAPP_RAY_APPLICATION_URL}..."

            puts bash "curl -o #{RAY_APPLICATION_PATH} #{ONEAPP_RAY_APPLICATION_URL}"
        else
            msg :info, 'No model file provided, using default'

            gen_model
        end
    end

    def generate_config_file
        if !ONEAPP_RAY_CONFIG_FILE.empty?
            msg :info, "Copying config to #{RAY_CONFIG_PATH}..."

            config_content = YAML.dump(ONEAPP_RAY_CONFIG_FILE)

            write_file(RAY_CONFIG_PATH, config_content)
        elsif !ONEAPP_RAY_CONFIG_FILE64.empty?
            msg :info, "Copying config64 to #{ONEAPP_RAY_CONFIGFILE_DEST_PATH}..."

            config = Base64.decode64(ONEAPP_RAY_CONFIG_FILE64)

            config_content = YAML.dump(YAML.safe_load(config))

            write_file(RAY_CONFIG_PATH, config_content)
        else
            msg :info, "Generating config file in #{RAY_CONFIG_PATH}..."

            gen_template_config
        end
    end

    def run_serve
        msg :info, "Serving Ray deployments in #{RAY_CONFIG_PATH}..."
        puts bash "serve deploy #{RAY_CONFIG_PATH}"
    end

    def run_vllm
        msg :info, "Serving vLLM application in #{RAY_APPLICATION_PATH}..."

        ENV["HF_TOKEN"] = ONEAPP_RAY_MODEL_TOKEN

        VLLM_LOG_FILE = "/var/log/one-appliance/vllm.log"

        pid = fork do
            Process.setsid
            bash "vllm serve #{ONEAPP_RAY_MODEL_ID} #{ONEAPP_RAY_MODEL_VLLM_ARGS} 2>&1 >> #{VLLM_LOG_FILE}"
        end
    end

    def listening?
        Socket.tcp('localhost', ONEAPP_RAY_API_PORT, connect_timeout: 5) do |s|
            s.close
            true
        end
    rescue StandardError
        false
    end

    def wait_service_available(timeout: 600, check_interval: 5)
        msg :info, "Waiting for service at http://localhost:#{ONEAPP_RAY_API_PORT}..."

        start_time = Time.now

        loop do
            break if listening?

            if Time.now - start_time > timeout
                raise "Service did not become available in #{timeout} seconds"
            end

            sleep check_interval
        end
    end

    def self.gpu_count
        stdout, _stderr, status = Open3.capture3('nvidia-smi --query-gpu=count' \
                                                 ' --format=csv,noheader')

        return 0 unless status.success?

        stdout.strip.to_i
    rescue StandardError
        return 0
    end

end
