# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

load_env

NIM_MODE           = env(:NIM_MODE, 'stub')
NIM_PORT           = env(:NIM_PORT, '8000')
NIM_API_PORT       = NIM_PORT
# Current scaffold assumption for container port mapping.
# The container's internal port remains fixed for the current scaffold.
NIM_CONTAINER_PORT = '8000'
NIM_API_ROUTE      = '/v1'
NIM_READY_ROUTE    = '/v1/health/ready'
NIM_CONTAINER_NAME = env(:NIM_CONTAINER_NAME, 'nim')

ETH0_IP = env(:ETH0_IP, '0.0.0.0')

# Stub mode keeps local QEMU validation simple.
# Real mode uses the current NVIDIA NIM default image and requires valid NGC auth.
NIM_CONTAINER_IMAGE = env(:NIM_CONTAINER_IMAGE,
                          NIM_MODE == 'real' ? 'nvcr.io/nim/openai/gpt-oss-120b:latest' : 'nginx:stable-alpine')

# Backward-compatible stub-mode entrypoint override used by the local validation container.
NIM_DOCKER_RUN_ARGS = '--entrypoint /bin/sh'

# Host-side cache directory used by the real NIM runtime bind mount.
# This path and its permission model are implementation choices for this scaffold
# and are not proven repo or NVIDIA requirements.
NIM_CACHE_DIR      = env(:NIM_CACHE_DIR, '/var/lib/nim/.cache')
NIM_SHM_SIZE       = env(:NIM_SHM_SIZE, '16GB')
NIM_EXTRA_ENV      = env(:NIM_EXTRA_ENV, '')
NIM_EXTRA_RUN_ARGS = env(:NIM_EXTRA_RUN_ARGS, '')
NGC_API_KEY        = env(:NGC_API_KEY, '')

NIM_RUNTIME_NOTE = 'Stub mode keeps local validation on a public container; real mode uses NVIDIA NIM and still depends on external NGC auth and GPU runtime availability.'
