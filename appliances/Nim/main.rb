# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'

module Service
    module Nim
        extend self

        DEPENDS_ON = []

        def install
            msg :info, 'Nim::install'
            msg :info, NIM_RUNTIME_NOTE

            install_runtime_dependencies

            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'Nim::configure'

            validate_placeholders!
            ensure_docker_running
            remove_previous_container
            start_container
            ensure_container_running!

            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'Nim::bootstrap'

            wait_service_available

            ip = env(:ETH0_IP, nil)
            onegate_endpoint = env(:ONEGATE_ENDPOINT, nil)
            vmid = env(:VMID, nil)
            token = env(:TOKENTXT, nil)

            if [ip, onegate_endpoint, vmid, token].any? { |value| value.nil? || value.empty? }
                msg :warn, 'Skipping OneGate publication because ETH0_IP/ONEGATE_ENDPOINT/VMID/TOKENTXT is unavailable in the current environment'
                msg :info, 'Bootstrap completed successfully'
                return
            end

            api_url    = "http://#{ip}:#{NIM_API_PORT}#{NIM_API_ROUTE}"
            health_url = "http://#{ip}:#{NIM_API_PORT}#{NIM_READY_ROUTE}"

            bash "onegate vm update --data \"ONEAPP_NIM_API=#{api_url}\""
            bash "onegate vm update --data \"ONEAPP_NIM_HEALTH=#{health_url}\""

            msg :info, 'Bootstrap completed successfully'
        end

        def install_runtime_dependencies
            puts bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                apt-get update
                apt-get install -y ca-certificates curl docker.io nvidia-driver-590-server-open nvidia-utils-590-server
            SCRIPT
        end

        def ensure_docker_running
            puts bash <<~SCRIPT
                systemctl enable docker
                systemctl start docker
            SCRIPT
        end

        def remove_previous_container
            msg :info, "Removing previous container if present: #{NIM_CONTAINER_NAME}"

            bash <<~SCRIPT
                docker rm -f #{NIM_CONTAINER_NAME} >/dev/null 2>&1 || true
            SCRIPT
        end

        def start_container
            msg :info, "Starting container: #{NIM_CONTAINER_NAME}"

            return start_real_container if NIM_MODE == 'real'

            puts bash <<~SCRIPT
                docker run -d \
                    --name #{NIM_CONTAINER_NAME} \
                    -p #{NIM_API_PORT}:#{NIM_CONTAINER_PORT} \
                    #{NIM_DOCKER_RUN_ARGS} \
                    #{NIM_CONTAINER_IMAGE} \
                    -c "cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 8000;

    location = /v1 {
        default_type text/plain;
        return 200 'ok\n';
    }

    location = /v1/health/ready {
        default_type text/plain;
        return 200 'ok\n';
    }

    location / {
        default_type text/plain;
        return 404 'not found\n';
    }
}
EOF
                        exec nginx -g 'daemon off;'"
            SCRIPT
        end

        def start_real_container
            puts bash <<~SCRIPT
                install -d -m 0777 #{NIM_CACHE_DIR}
                set +x
                echo "$NGC_API_KEY" | docker login nvcr.io --username '$oauthtoken' --password-stdin
                set -x
                docker pull "#{NIM_CONTAINER_IMAGE}"
                docker run -d \
                    --name #{NIM_CONTAINER_NAME} \
                    --runtime=nvidia \
                    --gpus all \
                    --shm-size=#{NIM_SHM_SIZE} \
                    -e NGC_API_KEY \
                    #{NIM_EXTRA_ENV} \
                    -v #{NIM_CACHE_DIR}:/opt/nim/.cache \
                    -u $(id -u) \
                    -p #{NIM_PORT}:#{NIM_CONTAINER_PORT} \
                    #{NIM_EXTRA_RUN_ARGS} \
                    "#{NIM_CONTAINER_IMAGE}"
            SCRIPT
        end

        def container_running?
            stdout = bash <<~SCRIPT, chomp: true
                docker inspect -f '{{.State.Running}}' #{NIM_CONTAINER_NAME}
            SCRIPT

            stdout == 'true'
        rescue StandardError
            false
        end

        def container_status
            bash <<~SCRIPT, chomp: true
                docker inspect -f '{{.State.Status}}' #{NIM_CONTAINER_NAME}
            SCRIPT
        rescue StandardError
            'missing'
        end

        def container_logs_tail(lines: 50)
            bash <<~SCRIPT
                docker logs --tail #{lines} #{NIM_CONTAINER_NAME}
            SCRIPT
        rescue StandardError
            ''
        end

        def ensure_container_running!
            return if container_running?

            status = container_status
            logs   = container_logs_tail

            raise <<~ERROR
                Nim container failed to stay running.
                Container status: #{status}
                Recent logs:
                #{logs}
            ERROR
        end

        def ready?
            bash <<~SCRIPT
                curl -fsS http://localhost:#{NIM_API_PORT}#{NIM_READY_ROUTE}
            SCRIPT
            true
        rescue StandardError
            false
        end

        def service_state
            return :container_not_running unless container_running?
            return :ready if ready?

            :container_running_not_ready
        end

        def wait_service_available(timeout: 600, check_interval: 5)
            msg :info, "Waiting for Nim readiness at http://localhost:#{NIM_API_PORT}#{NIM_READY_ROUTE}"

            start_time = Time.now

            loop do
                case service_state
                when :ready
                    msg :info, 'Nim service is ready'
                    return
                when :container_not_running
                    status = container_status
                    logs   = container_logs_tail

                    raise <<~ERROR
                        Nim container is not running during readiness polling.
                        Container status: #{status}
                        Recent logs:
                        #{logs}
                    ERROR
                when :container_running_not_ready
                    msg :info, 'Nim container is running but readiness endpoint is not ready yet'
                end

                if Time.now - start_time > timeout
                    raise "Nim service did not become ready in #{timeout} seconds"
                end

                sleep check_interval
            end
        end

        def validate_placeholders!
            raise 'NIM container image must not be empty.' if NIM_CONTAINER_IMAGE.empty?
            return unless NIM_MODE == 'real'

            raise 'NGC_API_KEY must not be empty in real mode.' if NGC_API_KEY.empty?
        end
    end
end
