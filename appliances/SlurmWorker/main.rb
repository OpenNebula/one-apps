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
            bash('apt update && apt install munge libmunge-dev slurmd -y')
            msg(:info, 'Installation completed successfully')
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
            if !Socket.gethostname.include?('worker')
                msg(:info, 'Hostname does not contain "worker", configuring it...')

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

            # Add controller to /etc/hosts for name resolution
            hosts_entry = "#{controller_ip}\tslurm-one-controller"
            unless File.read('/etc/hosts').include?(hosts_entry)
                msg(:info, "Adding '#{hosts_entry}' to /etc/hosts")
                File.open('/etc/hosts', 'a') { |f| f.puts(hosts_entry) }
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
            cpus = bash('nproc').chomp
            mem_mb = bash("free -m | awk '/^Mem:/ {print $2}'").chomp
            bash("slurmd -Z --conf \"CPUs=#{cpus} RealMemory=#{mem_mb} Feature=one\" --conf-server #{controller_ip}")
            msg(:info, 'slurmd started')

            msg(:info, 'Configuration completed successfully')
        end

        def bootstrap
            # No bootstrap actions defined for the worker.
        end

    end
end