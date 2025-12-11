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

    # VllmEngine service implementation (disk-mounted models only)
    module VllmEngine

        extend self

        DEPENDS_ON    = []

        def install
            msg :info, 'VllmEngine::install'
            install_dependencies
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'VllmEngine::configure'

            run_vllm

            if ONEAPP_VLLM_API_WEB
                run_api_web
            end

            msg :info, 'Configuration completed successfully'
        end

        def bootstrap
            msg :info, 'VllmEngine::bootstrap'
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
        # Removed: install_llm_benchmark_tool (not needed for disk-only appliance)

        # Cleanup build artifacts to reduce image size
        cleanup_build_artifacts
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
            uv venv #{PYTHON_VENV_CPU_PATH} --python 3.12 --seed

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

    def cleanup_build_artifacts
        puts bash <<~SCRIPT
            # Remove vLLM source code
            rm -rf /root/vllm_source

            # Clean pip/uv caches
            rm -rf /root/.cache/pip
            rm -rf /root/.cache/uv

            # Clean apt cache
            apt-get clean
            rm -rf /var/lib/apt/lists/*

            # Remove Python bytecode caches
            find /root -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
            find /root -type f -name '*.pyc' -delete 2>/dev/null || true

            # Remove documentation
            rm -rf /usr/share/doc/*
            rm -rf /usr/share/man/*

            # Remove locale files (keep only en_US)
            find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en_US' -exec rm -rf {} + 2>/dev/null || true

            # Clean logs
            rm -rf /var/log/*.log
            rm -rf /var/log/*.gz

            # Remove temporary files
            rm -rf /tmp/*
            rm -rf /var/tmp/*

            # Remove build dependencies that are not needed at runtime (if not already removed)
            # Keep only runtime dependencies
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

        # Detect and mount model disk (mandatory for vllm-engine)
        model_path = detect_and_mount_model_disk

        # vllm-engine requires a model disk - no HuggingFace fallback
        unless model_path && File.directory?(model_path) && !Dir.empty?(model_path)
            msg :error, "No model disk detected. vllm-engine requires a model disk to be attached."
            raise "Model disk is required but not found"
        end

        model_source = model_path
        msg :info, "Using model from disk: #{model_source}"

        # Build vLLM command (no HF_TOKEN needed)
        vllm_cmd = "vllm serve #{model_source} #{vllm_arguments}"

        pid = spawn(
            {},
            "/usr/bin/bash",
            "-c",
            "#{source_python_venv_str}; #{vllm_cmd} 2>&1 >> #{VLLM_LOG_FILE}",
            :pgroup => true
        )

        Process.detach(pid)
    end

    def run_api_web
        msg :info, "Starting web application..."

        # Detect and mount model disk to get the correct model path for web config
        model_path = detect_and_mount_model_disk

        # Ensure model path is available (mandatory)
        unless model_path && File.directory?(model_path) && !Dir.empty?(model_path)
            msg :error, "No model disk detected. Cannot start web application without model."
            raise "Model disk is required but not found"
        end

        # Generate web config with the detected model path
        gen_web_config(model_path)

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

    # ------------------------------------------------------------------------------
    # Model Disk Detection and Mounting
    # ------------------------------------------------------------------------------

    def detect_and_mount_model_disk
        # Auto-detect model disk (first non-OS disk)
        os_disk = detect_os_disk

        # Find additional disks (both block devices and virtiofs)
        additional_disks = find_additional_disks(os_disk)

        if additional_disks.empty?
            msg :error, "No model disk detected. vllm-engine requires a model disk to be attached."
            return nil
        end

        # Use first additional disk as model disk
        model_disk = additional_disks.first
        mount_path = determine_default_mount_path(model_disk)

        # Detect format for auto-detected disk
        disk_format = detect_disk_format(model_disk)

        msg :info, "Auto-detected model disk: #{model_disk} (format: #{disk_format}), mounting to #{mount_path}"
        return mount_disk_by_format(model_disk, mount_path, disk_format)
    end

    def detect_os_disk
        # Check /proc/partitions or lsblk to find OS disk
        # Typically the first disk (vda, sda, etc.)
        stdout, _stderr, status = Open3.capture3('lsblk -n -o NAME,TYPE | grep disk | head -1 | awk \'{print $1}\'')
        return stdout.strip if status.success?
        'vda'  # Default fallback
    end

    def find_additional_disks(os_disk)
        disks = []

        # Find block devices (qcow2 format)
        stdout, _stderr, status = Open3.capture3('lsblk -n -o NAME,TYPE | grep disk | awk \'{print $1}\'')
        if status.success?
            block_disks = stdout.strip.split("\n").reject { |d| d == os_disk }
            disks.concat(block_disks)
        end

        # Find virtiofs filesystems (dir/SharedFS format)
        # First, check already mounted virtiofs filesystems
        stdout, _stderr, status = Open3.capture3('mount -t virtiofs 2>/dev/null | awk \'{print $3}\' || true')
        if status.success? && !stdout.strip.empty?
            virtiofs_tags = stdout.strip.split("\n").map { |line| line.split('/').last }
            disks.concat(virtiofs_tags)
        end

        # Check /sys/fs/virtiofs/ for available virtiofs tags
        if Dir.exist?('/sys/fs/virtiofs')
            virtiofs_dirs = Dir.entries('/sys/fs/virtiofs').select { |d| d != '.' && d != '..' }
            disks.concat(virtiofs_dirs)
        end

        # Proactively probe for unmounted virtiofs tags
        # Virtiofs tags follow the pattern "disk{N}" where N is the DISK_ID
        # Try common tags (disk1, disk2, etc.) by attempting a test mount
        if File.exist?('/proc/filesystems') && File.read('/proc/filesystems').include?('virtiofs')
            # Try to detect available virtiofs tags by attempting test mounts
            # We'll try disk1 through disk10 (common range)
            (1..10).each do |disk_id|
                tag = "disk#{disk_id}"
                # Try a test mount to see if the tag is available
                # Use a temporary mount point and immediately unmount if successful
                test_mount = "/tmp/test_virtiofs_#{tag}"
                FileUtils.mkdir_p(test_mount)
                stdout, stderr, status = Open3.capture3("mount -t virtiofs #{tag} #{test_mount} 2>&1")
                if status.success?
                    disks << tag
                    # Unmount the test mount
                    Open3.capture3("umount #{test_mount} 2>/dev/null")
                end
                FileUtils.rmdir(test_mount) if Dir.exist?(test_mount)
            end
        end

        disks.uniq
    end

    def detect_disk_format(disk_spec)
        # Check if it's a virtiofs tag (typically starts with "disk" followed by number, e.g., "disk0", "disk1")
        if disk_spec =~ /^disk\d+$/i
            msg :info, "Detected virtiofs format for #{disk_spec}"
            return :virtiofs
        end

        # Check if it's a block device (e.g., vdb, sdb, etc.)
        device_path = "/dev/#{disk_spec}"
        if File.exist?(device_path) && File.blockdev?(device_path)
            msg :info, "Detected block device format (qcow2) for #{disk_spec}"
            return :block
        end

        # Check if virtiofs tag exists in /sys/fs/virtiofs/
        if Dir.exist?("/sys/fs/virtiofs/#{disk_spec}")
            msg :info, "Detected virtiofs format for #{disk_spec} (found in /sys/fs/virtiofs/)"
            return :virtiofs
        end

        # Check if already mounted as virtiofs
        stdout, _stderr, status = Open3.capture3("mount | grep -E 'virtiofs.*#{disk_spec}|#{disk_spec}.*virtiofs'")
        if status.success? && !stdout.strip.empty?
            msg :info, "Detected virtiofs format for #{disk_spec} (already mounted)"
            return :virtiofs
        end

        # Default to block device if device exists
        if File.exist?(device_path)
            msg :info, "Assuming block device format (qcow2) for #{disk_spec}"
            return :block
        end

        # Unknown format
        msg :warn, "Could not determine format for #{disk_spec}, assuming block device"
        return :block
    end

    def mount_disk_by_format(disk_spec, mount_path, format)
        case format
        when :block
            return mount_block_device(disk_spec, mount_path)
        when :virtiofs
            return mount_virtiofs(disk_spec, mount_path)
        else
            msg :error, "Unknown disk format: #{format}"
            return nil
        end
    end

    def mount_block_device(disk_device, mount_path)
        device_path = "/dev/#{disk_device}"

        # Check if device exists
        unless File.exist?(device_path)
            msg :error, "Block device #{device_path} does not exist"
            return nil
        end

        # Create mount point
        FileUtils.mkdir_p(mount_path)

        # Check if already mounted
        stdout, _stderr, status = Open3.capture3("mountpoint -q #{mount_path}")
        if status.success?
            msg :info, "#{mount_path} is already mounted"
            return mount_path
        end

        # Determine filesystem type (try ext4, xfs, or auto-detect)
        fs_type = detect_filesystem_type(device_path)

        # Mount the disk
        mount_cmd = "mount -t #{fs_type} #{device_path} #{mount_path}"
        stdout, stderr, status = Open3.capture3(mount_cmd)

        if status.success?
            msg :info, "Successfully mounted block device #{device_path} to #{mount_path}"
            return mount_path
        else
            msg :error, "Failed to mount block device #{device_path}: #{stderr}"
            return nil
        end
    end

    def mount_virtiofs(virtiofs_tag, mount_path)
        # Create mount point
        FileUtils.mkdir_p(mount_path)

        # Check if already mounted
        stdout, _stderr, status = Open3.capture3("mountpoint -q #{mount_path}")
        if status.success?
            msg :info, "#{mount_path} is already mounted"
            return mount_path
        end

        # Verify virtiofs tag exists
        # Virtiofs tags are typically available in /sys/fs/virtiofs/ or via mount
        virtiofs_available = false
        if Dir.exist?("/sys/fs/virtiofs/#{virtiofs_tag}")
            virtiofs_available = true
        else
            # Check if tag is available via mount command
            stdout, _stderr, status = Open3.capture3("mount -t virtiofs 2>/dev/null | grep #{virtiofs_tag}")
            virtiofs_available = status.success? && !stdout.strip.empty?
        end

        unless virtiofs_available
            msg :warn, "Virtiofs tag #{virtiofs_tag} not found, but attempting mount anyway"
        end

        # Mount virtiofs filesystem
        # The tag is the target directory name from the VM deployment XML
        mount_cmd = "mount -t virtiofs #{virtiofs_tag} #{mount_path}"
        stdout, stderr, status = Open3.capture3(mount_cmd)

        if status.success?
            msg :info, "Successfully mounted virtiofs #{virtiofs_tag} to #{mount_path}"
            return mount_path
        else
            msg :error, "Failed to mount virtiofs #{virtiofs_tag}: #{stderr}"
            return nil
        end
    end

    def determine_default_mount_path(disk_spec)
        # For block devices: /mnt/{device} (e.g., /mnt/vdb)
        # For virtiofs: /mnt/{tag} (e.g., /mnt/disk1)
        "/mnt/#{disk_spec}"
    end

    def detect_filesystem_type(device_path)
        # Try to detect filesystem type
        stdout, _stderr, status = Open3.capture3("blkid -s TYPE -o value #{device_path}")
        return stdout.strip if status.success? && !stdout.strip.empty?

        # Fallback: try common filesystems
        ['ext4', 'xfs', 'ext3'].each do |fs|
            stdout, _stderr, status = Open3.capture3("mount -t #{fs} #{device_path} /tmp/test_mount 2>&1")
            if status.success?
                Open3.capture3("umount /tmp/test_mount")
                return fs
            end
        end

        'auto'  # Let mount auto-detect
    end

end
