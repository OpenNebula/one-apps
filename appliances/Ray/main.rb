# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'

require 'net/http'

module Service

    module Ray

        extend self

        DEPENDS_ON = []

        def install
            msg :info, 'Ray::install'
            install_dependencies
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'Ray::configure'
            load_model_file
            generate_config_file
            start_ray
            run_serve
            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'Ray::bootstrap'
            begin
                wait_service_available
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
            pip3 install ray[#{ONE_APP_RAY_MODULES}]
        SCRIPT
    end

    def start_ray
        msg :info, 'Starting Ray...'
        puts bash "ray start --head --port=#{ONE_APP_RAY_PORT}"
    end

    # The model file should be placed in the same directory where we call serve deploy
    def load_model_file
        if !ONE_APP_RAY_MODEL64.empty?
            msg :info, "Copying model file to #{ONE_APP_RAY_MODEL_DEST_PATH}..."
            write_file(ONE_APP_RAY_MODEL_DEST_PATH, Base64.decode64(ONE_APP_RAY_MODEL64), 0775)
            return
        end
        if !ONE_APP_RAY_MODEL_URL.empty?
            msg :info,
                "Downloading model from #{ONE_APP_RAY_MODEL_URL} to #{ONE_APP_RAY_MODEL_DEST_PATH}"
            puts bash "curl -o #{ONE_APP_RAY_MODEL_DEST_PATH} #{ONE_APP_RAY_MODEL_URL}"
            return
        end
        msg :info, 'No model file provided'
    end

    def generate_config_file
        if !ONE_APP_RAY_CONFIG_FILE.empty?
            msg :info, "Copying config to #{ONE_APP_RAY_CONFIGFILE_DEST_PATH}..."
            config_content = YAML.dump(ONE_APP_RAY_CONFIG)
            write_file(ONE_APP_RAY_CONFIGFILE_DEST_PATH, config_content)
            return
        end
        if !ONE_APP_RAY_CONFIG64.empty?
            msg :info, "Copying base64 config to #{ONE_APP_RAY_CONFIGFILE_DEST_PATH}..."
            config_content = YAML.dump(YAML.safe_load(Base64.decode64(ONE_APP_RAY_CONFIG64)))
            write_file(ONE_APP_RAY_CONFIGFILE_DEST_PATH, config_content)
            return
        end
        msg :info, "Generating config file in #{ONE_APP_RAY_CONFIGFILE_DEST_PATH}..."
        gen_template_config
    end

    def run_serve
        msg :info, "Serving Ray deployments in #{ONE_APP_RAY_CONFIGFILE_DEST_PATH}..."
        puts bash "serve deploy #{ONE_APP_RAY_CONFIGFILE_DEST_PATH}"
    end

    def wait_service_available(timeout: 300, check_interval: 5)
        msg :info, "Waiting service to be available in http://localhost:#{ONE_APP_RAY_SERVE_PORT}..."
        start_time = Time.now
        uri = URI("http://localhost:#{ONE_APP_RAY_SERVE_PORT}")

        loop do
            response = Net::HTTP.get_response(uri)
            break if response.code.to_i == 200 && response.body.include?('OK')

            if Time.now - start_time > timeout
                raise "Service did not become available within #{timeout} seconds"
            end

            sleep check_interval
        end
    end

end
