# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

load_env

NIM_API_PORT       = '8000'
# Current scaffold assumption for container port mapping.
# Replace only if the final NVIDIA NIM product contract requires a different internal port.
NIM_CONTAINER_PORT = '8000'
NIM_API_ROUTE      = '/v1'
NIM_READY_ROUTE    = '/v1/health/ready'
NIM_CONTAINER_NAME = 'nim'

ETH0_IP = env(:ETH0_IP, '0.0.0.0')

# Temporary public image for scaffold validation only.
# This must be reverted before final NVIDIA NIM integration.
NIM_CONTAINER_IMAGE = 'nginx:stable-alpine'

# Temporary scaffold validation only.
# This must be reverted before final NVIDIA NIM integration.
NIM_DOCKER_RUN_ARGS = '--entrypoint /bin/sh'

NIM_RUNTIME_NOTE = 'Temporary scaffold validation only using a public container; revert before final NVIDIA NIM integration.'
