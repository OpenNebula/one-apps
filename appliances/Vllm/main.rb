# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'

require 'socket'
require 'open3'
require 'rbconfig'

# Base module for OpenNebula services
module Service

    # Vllm service implmentation
    module Vllm

        extend self

        DEPENDS_ON    = []

        def install
            msg :info, 'Vllm::install'
            install_dependencies
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'Vllm::configure'

            run_vllm

            if ONEAPP_VLLM_API_WEB
                run_api_web
            end

            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'Vllm::bootstrap'
            begin
                wait_service_available

                msg :info, 'Updating VM with inference endpoint'

                ip  = env('ETH0_IP', '0.0.0.0')
                url = "http://#{ip}:#{ONEAPP_VLLM_API_PORT}#{VLLM_API_ROUTE}"

                bash "onegate vm update --data \"ONEAPP_VLLM_CHATBOT_API=#{url}\""

                if ONEAPP_VLLM_API_WEB
                    url = "http://#{ip}:5000"
                    bash "onegate vm update --data \"ONEAPP_VLLM_CHATBOT_WEB=#{url}\""
                end

                msg :info, 'Bootstrap completed successfully'
            rescue StandardError => e
                msg :error, "Error during bootstrap: #{e.message}"
            end
        end

    end

    def install_dependencies

        install_common_dependencies

        install_gpu_dependencies

        if RbConfig::CONFIG['host_cpu'] =~ /arm64|aarch64/
            install_cpu_aarch64_dependencies
            build_llvm_cpu_aarch64
            install_llvm_gpu_aarch64
        else
            install_cpu_dependencies
            build_llvm_cpu
            install_llvm_gpu
        end

        install_web_dependencies
    end

    def install_common_dependencies
        puts bash <<~SCRIPT
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y
            apt-get install -y python3 python3-pip curl

            curl -LsSf https://astral.sh/uv/install.sh | sh
        SCRIPT
    end

    def install_cpu_aarch64_dependencies
        #dependencies for building vllm in aarch64: https://docs.vllm.ai/en/stable/getting_started/installation/cpu.html#arm-aarch64
        puts bash <<~SCRIPT
            export DEBIAN_FRONTEND=noninteractive
            sudo apt-get update  -y
            sudo apt-get install -y --no-install-recommends ccache git curl wget ca-certificates gcc-12 g++-12 libtcmalloc-minimal4 libnuma-dev ffmpeg libsm6 libxext6 libgl1 jq lsof
            sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10 --slave /usr/bin/g++ g++ /usr/bin/g++-12
        SCRIPT
    end

    def build_llvm_cpu_aarch64
        puts bash <<~SCRIPT
            cd /root
            uv venv vllm_cpu --python 3.12 --seed

            source #{PYTHON_VENV_CPU_PATH}/bin/activate

            git clone --branch v#{ONEAPP_VLLM_RELEASE_VERSION} https://github.com/vllm-project/vllm.git vllm_source
            cd vllm_source

            uv pip install -r requirements/cpu-build.txt --torch-backend cpu --index-strategy unsafe-best-match
            uv pip install -r requirements/cpu.txt --torch-backend cpu

            VLLM_TARGET_DEVICE=cpu python setup.py install
        SCRIPT
    end

    def install_cpu_dependencies
        #dependencies for building vllm in x86_64: https://docs.vllm.ai/en/stable/getting_started/installation/cpu.html#intelamd-x86
        puts bash <<~SCRIPT
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y gcc g++ libnuma-dev
        SCRIPT
    end

    def build_llvm_cpu
        puts bash <<~SCRIPT
            cd /root
            uv venv #{PYTHON_VENV_CPU_PATH} --python 3.12 --seed

            source #{PYTHON_VENV_CPU_PATH}/bin/activate

            git clone --branch v#{ONEAPP_VLLM_RELEASE_VERSION} https://github.com/vllm-project/vllm.git vllm_source
            cd vllm_source

            uv pip install -r requirements/cpu-build.txt --torch-backend cpu --index-strategy unsafe-best-match
            uv pip install -r requirements/cpu.txt --torch-backend cpu --index-strategy unsafe-best-match

            VLLM_TARGET_DEVICE=cpu uv pip install . --no-build-isolation
        SCRIPT
    end

    def install_gpu_dependencies
        # return if drivers were already provided in the base image
        return if INSTALL_DRIVERS != 'true'

        # Installing 570 branch drivers as they are available with CUDA 12.8
        # which are necessary for running on NVIDIA Blackwell GPUs
        # https://docs.vllm.ai/en/latest/getting_started/installation/gpu.html#pre-built-wheels
        puts bash <<~SCRIPT
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt install nvidia-driver-570-server nvidia-utils-570-server -y
        SCRIPT
    end

    def install_llvm_gpu
        puts bash <<~SCRIPT
            cd /root
            uv venv #{PYTHON_VENV_GPU_PATH} --python 3.12 --seed

            source #{PYTHON_VENV_GPU_PATH}/bin/activate

            export VLLM_VERSION=#{ONEAPP_VLLM_RELEASE_VERSION}
            export CUDA_VERSION=#{ONEAPP_VLLM_CUDA_VERSION}
            uv pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cu${CUDA_VERSION}-cp38-abi3-manylinux1_x86_64.whl  \
                --extra-index-url https://download.pytorch.org/whl/cu${CUDA_VERSION} \
                --index-strategy unsafe-best-match
        SCRIPT
    end

    def install_llvm_gpu_aarch64
        puts bash <<~SCRIPT
            cd /root
            uv venv #{PYTHON_VENV_GPU_PATH} --python 3.12 --seed

            source #{PYTHON_VENV_GPU_PATH}/bin/activate

            export VLLM_VERSION=#{ONEAPP_VLLM_RELEASE_VERSION}
            export CUDA_VERSION=#{ONEAPP_VLLM_CUDA_VERSION}
            uv pip install https://github.com/vllm-project/vllm/releases/download/v${VLLM_VERSION}/vllm-${VLLM_VERSION}+cu${CUDA_VERSION}-cp38-abi3-manylinux2014_aarch64.whl  \
                --extra-index-url https://download.pytorch.org/whl/cu${CUDA_VERSION} \
                --index-strategy unsafe-best-match
        SCRIPT
    end


    def install_web_dependencies
        puts bash <<~SCRIPT
            cd /root
            uv venv #{PYTHON_VENV_WEB_PATH} --python 3.12 --seed

            source #{PYTHON_VENV_WEB_PATH}/bin/activate
            pip install flask pyyaml openai
        SCRIPT
    end


    def source_python_venv_str
        gpus = Service.gpu_count
        if gpus > 0
            msg :info, "GPU(s) detected: #{gpus}, using GPU Python environment"
            return "source #{PYTHON_VENV_GPU_PATH}/bin/activate"
        else
            msg :info, "No GPU detected, using CPU Python environment"
            return "source #{PYTHON_VENV_CPU_PATH}/bin/activate"
        end
    end

    def run_vllm
        msg :info, "Serving vLLM application..."

        pid = spawn(
            { "HF_TOKEN" => ONEAPP_VLLM_MODEL_TOKEN },
            "/usr/bin/bash",
            "-c",
            "#{source_python_venv_str}; vllm serve #{ONEAPP_VLLM_MODEL_ID}  #{vllm_arguments} 2>&1 >> #{VLLM_LOG_FILE}",
            :pgroup => true
        )

        Process.detach(pid)
    end

    def run_api_web
        msg :info, "Starting web application..."

        gen_web_config

        pid = spawn(
            {},
            "/usr/bin/bash",
            "-c",
            "source #{PYTHON_VENV_WEB_PATH}/bin/activate; cd #{WEB_PATH}; python3 web_client_openai.py",
            :pgroup => true
        )

        Process.detach(pid)
    end

    def listening?
        Socket.tcp('localhost', ONEAPP_VLLM_API_PORT, connect_timeout: 5) do |s|
            s.close
            true
        end
    rescue StandardError
        false
    end

    def wait_service_available(timeout: 600, check_interval: 5)
        msg :info, "Waiting for service at http://localhost:#{ONEAPP_VLLM_API_PORT}..."

        start_time = Time.now

        loop do
            break if listening?

            if Time.now - start_time > timeout
                raise "Service did not become available in #{timeout} seconds"
            end

            sleep check_interval
        end
    end

    def vllm_arguments
        arguments = String.new

        gpus = Service.gpu_count

        if gpus > 0
            arguments << " --tensor-parallel-size #{gpus}"
            arguments << " --gpu-memory-utilization #{gpu_memory_utilization}"
            if ONEAPP_VLLM_SLEEP_MODE
                arguments << " --enable-sleep-mode"
            end
        end

        if quantization == 4
            arguments << " --quantization bitsandbytes --load-format bitsandbytes"
        end

        if ONEAPP_VLLM_ENFORCE_EAGER
            arguments << " --enforce-eager"
        end

        arguments << " --max-model-len #{model_length}"

        arguments << " --host 0.0.0.0 --port #{ONEAPP_VLLM_API_PORT}"

        arguments
    end

    def gpu_memory_utilization
        mem = Float(ONEAPP_VLLM_GPU_MEMORY_UTILIZATION)
        return (mem > 1.0 || mem <= 0.0) ? DEFAULT_GPU_MEMORY_UTILIZATION : mem
    rescue StandardError => e
        msg :warn, "Error parsing GPU memory utilization: #{e.message}. Defaulting to #{DEFAULT_GPU_MEMORY_UTILIZATION}."
        DEFAULT_GPU_MEMORY_UTILIZATION
    end

    def model_length
        Integer(ONEAPP_VLLM_MODEL_MAX_LENGTH)
    rescue StandardError
        1024
    end

    def quantization
        Integer(ONEAPP_VLLM_MODEL_QUANTIZATION)
    rescue StandardError
        0
    end

    def self.gpu_count
        stdout, _stderr, status = Open3.capture3('nvidia-smi --query-gpu=count' \
                                                 ' --format=csv,noheader')
        unless status.success?
            msg :warn, "nvidia-smi command failed, assuming 0 GPUs"
            return 0
        end
        stdout.strip.to_i
    rescue StandardError => e
        msg :warn, "Error detecting GPU count: #{e.message}"
        0
    end

end
