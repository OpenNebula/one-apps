# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require 'socket'
require 'open3'
require 'rbconfig'
require 'fileutils'
require 'base64'
require 'json'
require_relative 'config'

# Base module for OpenNebula services
module Service

    # SlurmWorker service implmentation
    module SlurmWorker

        extend self

        DEPENDS_ON = []

        def install
            msg(:info, 'SlurmWorker::install')
            bash('apt update && apt install munge libmunge-dev slurmd slurm-wlm-basic-plugins -y')
            install_nvidia_drivers
            bash('systemctl disable slurmd')
            msg(:info, 'Installation completed successfully')
        end

        def install_nvidia_drivers
            return unless INSTALL_DRIVERS == 'true'

            install_nvidia_packages
        end

        def install_nvidia_packages
            # NVIDIA CUDA repo branch #{NVIDIA_DRIVER_BRANCH}; required for recent
            # datacenter GPUs such as H200 and GB200.
            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                ARCH=$(uname -m)
                CUDA_ARCH=${ARCH}
                if [ "${ARCH}" = "aarch64" ]; then
                    CUDA_ARCH=sbsa
                fi
                wget https://developer.download.nvidia.com/compute/cuda/repos/debian13/${CUDA_ARCH}/cuda-keyring_1.1-1_all.deb
                dpkg -i cuda-keyring_1.1-1_all.deb
                apt update
                apt install -y nvidia-driver-pinning-#{NVIDIA_DRIVER_BRANCH}
                apt install -y linux-headers-$(uname -r) build-essential dkms
                apt install -y cuda-drivers
            SCRIPT
        end

        def configure
            msg(:info, 'SlurmWorker::configure')

            # Check for required configuration constants
            controller_ip = ONEAPP_SLURM_CONTROLLER_IP
            munge_key_b64 = ONEAPP_MUNGE_KEY_BASE64

            if controller_ip.empty?
                raise 'FATAL: Parameter ONEAPP_SLURM_CONTROLLER_IP must be set via contextualization.'
            end

            if munge_key_b64.empty?
                raise 'FATAL: Parameter ONEAPP_MUNGE_KEY_BASE64 must be set via contextualization.'
            end

            msg(:info, "Controller IP specified: #{controller_ip}")

            # Check if the controller is reachable on the slurmctld port, with retries
            msg(:info, "Checking for controller reachability at #{controller_ip}:6817...")
            port_open = false
            5.times do |i|
                if tcp_port_open?(controller_ip, 6817)
                    port_open = true
                    break
                end
                msg(:warn, "Controller not reachable, retrying in 10s (#{i + 1}/5)...")
                sleep 10
            end

            unless port_open
                raise "FATAL: Cannot connect to Slurm controller at #{controller_ip}:6817 after 5 attempts."
            end
            msg(:info, 'Successfully connected to Slurm controller port.')

            # Configure hostname
            if ENV['SET_HOSTNAME'].to_s.empty?
                msg(:info, 'SET_HOSTNAME not set, configuring default hostname...')

                vm_id = nil
                10.times do |i|
                    begin
                        msg(:info, "Attempting to get VM info from onegate (#{i + 1}/10)")
                        vm_info_json = bash('onegate vm show -j')
                        vm_info = JSON.parse(vm_info_json)
                        vm_id = vm_info['VM']['ID']
                        break # Success, exit retry loop
                    rescue StandardError => e
                        if i + 1 < 10
                            sleep 15
                        else
                            raise "FATAL: Failed to get VM ID from onegate after 10 attempts: #{e.message}"
                        end
                    end
                end

                new_hostname = "slurm-one-worker-#{vm_id}"
                msg(:info, "Setting hostname to #{new_hostname}")
                bash("hostnamectl set-hostname #{new_hostname}")
            end

            hostname = Socket.gethostname.split('.').first

            # Add worker and controller to /etc/hosts
            ip = Socket.ip_address_list
                       .find { |a| a.ipv4? && !a.ipv4_loopback? }
                       .ip_address
            hosts_entries = [
                "#{ip}\t#{hostname}",
                "#{controller_ip}\tslurm-one-controller"
            ]
            hosts = File.read('/etc/hosts')
            File.open('/etc/hosts', 'a') do |f|
                hosts_entries.each do |hosts_entry|
                    next if hosts.include?(hosts_entry)

                    msg(:info, "Adding '#{hosts_entry}' to /etc/hosts")
                    f.puts(hosts_entry)
                end
            end

            # Decode and install the munge key from the controller
            msg(:info, 'Installing munge key from controller')
            munge_key = Base64.decode64(munge_key_b64)
            File.write('/etc/munge/munge.key', munge_key, mode: 'wb')
            FileUtils.chmod(0600, '/etc/munge/munge.key')

            # Enable and restart the munge service
            bash('systemctl enable munge')
            bash('systemctl restart munge')
            msg(:info, 'Verifying munge service connectivity')
            bash('munge -n | unmunge >/dev/null 2>&1')
            msg(:info, 'Munge verification successful')

            # Wait and start the slurmd service
            sleep 5
            msg(:info, 'Starting slurmd and registering with controller')
            conf = "CPUs=#{cpu_count} RealMemory=#{real_memory_mb} Feature=one"
            gpus = gpu_count
            conf += " Gres=gpu:#{gpus}" if gpus > 0
            slurmd_unit = <<~UNIT
                [Unit]
                Description=Slurm node daemon
                After=munge.service network-online.target
                Wants=network-online.target
                Documentation=man:slurmd(8)

                [Service]
                Type=notify
                EnvironmentFile=-/etc/default/slurmd
                RuntimeDirectory=slurm
                RuntimeDirectoryMode=0755
                ExecStart=/usr/sbin/slurmd --systemd --conf-server slurm-one-controller:6817 -N #{hostname} -Z --conf "#{conf}"
                ExecReload=/bin/kill -HUP $MAINPID
                KillMode=process
                LimitNOFILE=131072
                LimitMEMLOCK=infinity
                LimitSTACK=infinity
                Delegate=yes
                TasksMax=infinity

                [Install]
                WantedBy=multi-user.target
            UNIT
            File.write('/etc/systemd/system/slurmd.service', slurmd_unit)
            bash('systemctl daemon-reload')
            bash('systemctl enable slurmd')
            bash('systemctl restart slurmd')
            bash('systemctl is-active slurmd')
            msg(:info, 'slurmd started')

            msg(:info, 'Configuration completed successfully')
        end

        def bootstrap
            # No bootstrap actions defined for the worker.
        end

        def gpu_count
            stdout, _stderr, status = Open3.capture3('nvidia-smi --query-gpu=count' \
                                                     ' --format=csv,noheader')
            unless status.success?
                msg(:warn, 'nvidia-smi command failed, assuming 0 GPUs')
                return 0
            end
            stdout.strip.to_i
        rescue StandardError => e
            msg(:warn, "Error detecting GPU count: #{e.message}")
            0
        end

        def cpu_count
            bash('nproc').strip.to_i
        end

        def real_memory_mb
            meminfo = File.read('/proc/meminfo')
            if meminfo =~ /^MemTotal:\s+(\d+)\s+kB/m
                ($1.to_i / 1024).to_i
            else
                raise 'FATAL: Unable to read MemTotal from /proc/meminfo'
            end
        end

    end
end
