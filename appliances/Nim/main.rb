# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'shellwords'
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

            validate_runtime_context!
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

            api_url = url_for(ip, NIM_API_PORT, NIM_API_ROUTE)
            health_url = url_for(ip, NIM_API_PORT, NIM_READY_ROUTE)

            bash "onegate vm update --data \"ONEAPP_NIM_API=#{api_url}\""
            bash "onegate vm update --data \"ONEAPP_NIM_HEALTH=#{health_url}\""

            msg :info, 'Bootstrap completed successfully'
        end

        def install_runtime_dependencies
            puts bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                apt-get update
                apt-get install -y ca-certificates curl gnupg docker.io nvidia-driver-590-server-open nvidia-utils-590-server

                install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                    | gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg

                curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
                    | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' \
                    > /etc/apt/sources.list.d/nvidia-container-toolkit.list

                apt-get update
                apt-get install -y nvidia-container-toolkit

                nvidia-ctk runtime configure --runtime=docker
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
            puts bash <<~SCRIPT
                install -d -m 0777 #{sh_escape(NIM_CACHE_HOST_DIR)}

                set +x
                if ! printf '%s' "$NVIDIA_REGISTRY_KEY" | docker login "$NVIDIA_REGISTRY" -u #{sh_escape(registry_username)} --password-stdin; then
                    echo "ERROR: Docker login failed for NVIDIA registry '$NVIDIA_REGISTRY'." >&2
                    exit 1
                fi
                set -x

                if ! docker pull "$NVIDIA_IMAGE_REF"; then
                    echo "ERROR: Failed to pull NVIDIA image '$NVIDIA_IMAGE_REF'." >&2
                    exit 1
                fi

                if ! docker run -d \
                    --name #{sh_escape(NIM_CONTAINER_NAME)} \
                    --runtime=nvidia \
                    --gpus all \
                    --shm-size=#{sh_escape(NIM_SHM_SIZE)} \
                    -e NGC_API_KEY="$NVIDIA_REGISTRY_KEY" \
                    #{NIM_EXTRA_ENV} \
                    -v #{sh_escape(NIM_CACHE_HOST_DIR)}:#{sh_escape(NIM_CACHE_CONTAINER_DIR)} \
                    -u $(id -u) \
                    -p #{sh_escape(NIM_HOST_PORT)}:#{sh_escape(NIM_CONTAINER_PORT)} \
                    #{NIM_EXTRA_RUN_ARGS} \
                    "$NVIDIA_IMAGE_REF"
                then
                    echo "ERROR: Failed to start NVIDIA container '$NVIDIA_IMAGE_REF'." >&2
                    exit 1
                fi
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
            health = container_health_status

            return true if health == 'healthy'
            return false unless health == 'none'

            ready_via_http?
        end

        def service_state
            return :container_not_running unless container_running?
            return :container_unhealthy if container_health_status == 'unhealthy'
            return :container_running_not_ready if container_health_status == 'starting'
            return :ready if ready?

            :container_running_not_ready
        end

        def wait_service_available(timeout: 600, check_interval: 5)
            msg :info, readiness_wait_message

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
                when :container_unhealthy
                    status = container_status
                    logs   = container_logs_tail

                    raise <<~ERROR
                        Nim container became unhealthy during readiness polling.
                        Container status: #{status}
                        Container health: #{container_health_status}
                        Recent logs:
                        #{logs}
                    ERROR
                when :container_running_not_ready
                    msg :info, readiness_pending_message
                end

                if Time.now - start_time > timeout
                    raise "Nim service did not become ready in #{timeout} seconds"
                end

                sleep check_interval
            end
        end

        def validate_runtime_context!
            missing = []
            missing << 'NVIDIA_REGISTRY' if NVIDIA_REGISTRY.empty?
            missing << 'NVIDIA_REGISTRY_KEY' if NVIDIA_REGISTRY_KEY.empty?
            missing << 'NVIDIA_IMAGE_REF' if NVIDIA_IMAGE_REF.empty?
            missing << 'NVIDIA_REGISTRY_USER' if require_registry_user? && NVIDIA_REGISTRY_USER.empty?

            return if missing.empty?

            raise "Missing required OpenNebula context variable(s): #{missing.join(', ')}"
        end

        def require_registry_user?
            normalized_registry != 'nvcr.io'
        end

        def registry_username
            return '$oauthtoken' unless require_registry_user?

            NVIDIA_REGISTRY_USER
        end

        def normalized_registry
            NVIDIA_REGISTRY.strip
        end

        def container_health_status
            bash <<~SCRIPT, chomp: true
                docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' #{NIM_CONTAINER_NAME}
            SCRIPT
        rescue StandardError
            'unknown'
        end

        def ready_via_http?
            bash <<~SCRIPT
                curl -fsS http://localhost:#{NIM_API_PORT}#{NIM_READY_ROUTE}
            SCRIPT
            true
        rescue StandardError
            false
        end

        def readiness_wait_message
            health = container_health_status

            return 'Waiting for Nim Docker HEALTHCHECK to report healthy' unless health == 'none'
            "Waiting for Nim readiness at http://localhost:#{NIM_API_PORT}#{NIM_READY_ROUTE}"
        end

        def readiness_pending_message
            health = container_health_status

            return 'Nim container is running but Docker HEALTHCHECK is not healthy yet' unless health == 'none'
            'Nim container is running but readiness endpoint is not ready yet'
        end

        def url_for(ip, port, path)
            normalized = path.to_s
            normalized = '' if normalized == '/'
            normalized = "/#{normalized}" unless normalized.empty? || normalized.start_with?('/')

            "http://#{ip}:#{port}#{normalized}"
        end

        def sh_escape(value)
            Shellwords.escape(value.to_s)
        end
    end
end
