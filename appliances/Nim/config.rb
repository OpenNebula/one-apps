# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

load_env

NIM_HOST_PORT      = '8000'
NIM_API_PORT       = NIM_HOST_PORT
NIM_CONTAINER_PORT = '8000'
NIM_API_ROUTE      = '/v1'
NIM_READY_ROUTE    = '/v1/health/ready'
NIM_CONTAINER_NAME = 'nim'

ETH0_IP = env(:ETH0_IP, '0.0.0.0')

NVIDIA_REGISTRY      = env(:NVIDIA_REGISTRY, '')
NVIDIA_REGISTRY_USER = env(:NVIDIA_REGISTRY_USER, '')
NVIDIA_REGISTRY_KEY  = env(:NVIDIA_REGISTRY_KEY, '')
NVIDIA_IMAGE_REF     = env(:NVIDIA_IMAGE_REF, '')

NIM_CACHE_HOST_DIR      = '/var/lib/nim/.cache'
NIM_CACHE_CONTAINER_DIR = '/opt/nim/.cache'
NIM_SHM_SIZE            = '16GB'
NIM_EXTRA_ENV           = ''
NIM_EXTRA_RUN_ARGS      = ''

NIM_RUNTIME_NOTE = 'Nim runtime is deployed from OpenNebula deployment-time context using NVIDIA_REGISTRY, NVIDIA_REGISTRY_KEY, and NVIDIA_IMAGE_REF. NVIDIA_REGISTRY_USER is additionally required only for non-nvcr.io registries.'
