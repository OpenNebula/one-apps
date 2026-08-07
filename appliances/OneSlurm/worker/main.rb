# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../../lib/helpers'
end

require 'socket'
require 'open3'
require 'rbconfig'
require 'fileutils'
require 'base64'
require 'json'

require_relative '../common/onegate'
require_relative '../common/ldap'
require_relative '../common/munge'
require_relative '../common/slurm'
require_relative '../common/infiniband'
require_relative 'config'

# Base module for OpenNebula services
module Service

    # SlurmWorker service implementation
    module SlurmWorker

        extend self

        include OneSlurm::Ldap
        include OneSlurm::Munge
        include OneSlurm::Slurm
        include OneSlurm::Infiniband

        DEPENDS_ON = []

        def install
            msg(:info, 'SlurmWorker::install')
            bash('apt update && apt install munge libmunge-dev slurmd slurm-client slurm-wlm-basic-plugins sssd sssd-ldap libnss-sss libpam-sss ldap-utils nfs-common -y')
            install_infiniband_packages
            install_nvidia_drivers
            bash('systemctl disable slurmd')
            msg(:info, 'Installation completed successfully')
        end

        def install_infiniband_packages
            return unless INSTALL_INFINIBAND == 'true'

            install_worker_infiniband_packages
        end

        def install_nvidia_drivers
            return unless INSTALL_DRIVERS == 'true'

            install_nvidia_packages
        end

        def install_nvidia_packages
            # Use Ubuntu's packaged server-open driver for recent datacenter GPUs.
            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                apt update
                apt install -y linux-headers-$(uname -r) build-essential dkms
                apt install -y nvidia-driver-#{NVIDIA_DRIVER_BRANCH}-server-open
                apt install -y nvidia-utils-#{NVIDIA_DRIVER_BRANCH}-server
            SCRIPT
        end

        def configure
            msg(:info, 'SlurmWorker::configure')

            # Discover the controller and coordination data through OneGate.
            controller_ip, munge_key_b64, ldap = discover_controller

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

            if infiniband_enabled?
                configure_ipoib(ip)
            else
                msg(:info, 'InfiniBand support disabled, skipping IPoIB configuration')
            end

            # Decode and install the munge key from the controller
            install_munge_key(munge_key_b64)

            # Wait and start the slurmd service
            sleep 5
            msg(:info, 'Starting slurmd and registering with controller')
            write_slurmd_unit(hostname)
            msg(:info, 'slurmd started')

            # Publish the Slurm node name so the controller reconciler has a
            # reliable VM -> node mapping (avoids replicating SET_HOSTNAME
            # sanitization). Best-effort: discovery already succeeded above.
            publish_node_name(hostname)

            # Install the shutdown hook so a graceful scale-down removes this
            # node from the controller immediately.
            install_self_drain_hook

            configure_worker_ldap(ldap)

            msg(:info, 'Configuration completed successfully')
        end

        def publish_node_name(hostname)
            with_retries(msg: 'Attempting to publish Slurm node name to OneGate...') do
                msg(:info, "Publishing Slurm node name '#{hostname}' to OneGate")
                onegate_vm_update(["SLURM_NODENAME=#{hostname}"])
            end
        rescue StandardError => e
            msg(:warn, "Could not publish Slurm node name to OneGate: #{e.message}")
        end

        def install_self_drain_hook
            msg(:info, 'Installing OneSlurm worker self-drain shutdown hook')

            drain_script = <<~SCRIPT
                #!/bin/bash
                # Remove this worker from the Slurm controller on graceful shutdown
                # (e.g. OneFlow scale-down). Best-effort; the controller reconciler
                # is the safety net for hard terminations.
                export SLURM_CONF=/run/slurm/conf/slurm.conf
                [ -f "$SLURM_CONF" ] || export SLURM_CONF=/etc/slurm/slurm.conf
                NODE=$(hostname -s)
                timeout 15 scontrol update NodeName="$NODE" State=DOWN Reason="oneflow scale-down" 2>/dev/null || true
                timeout 15 scontrol delete NodeName="$NODE" 2>/dev/null || true
            SCRIPT
            file '/usr/local/sbin/oneslurm-self-drain.sh', drain_script,
                 mode: 'u=rwx,go=rx', overwrite: true

            unit = <<~UNIT
                [Unit]
                Description=OneSlurm worker self-drain on shutdown
                After=slurmd.service munge.service network-online.target

                [Service]
                Type=oneshot
                RemainAfterExit=yes
                ExecStart=/bin/true
                ExecStop=/usr/local/sbin/oneslurm-self-drain.sh

                [Install]
                WantedBy=multi-user.target
            UNIT
            file '/etc/systemd/system/oneslurm-self-drain.service', unit,
                 mode: 'u=rw,go=r', overwrite: true

            bash('systemctl daemon-reload')
            bash('systemctl enable --now oneslurm-self-drain.service')
        end

        def discover_controller(retries = 20, seconds = 15)
            msg(:info, 'Discovering Slurm controller through OneGate')

            retries.downto(0).each do |retry_num|
                begin
                    controller_vm = role_vm_show('controller')
                    user_template = controller_vm.dig('VM', 'USER_TEMPLATE') || {}

                    ready = user_template['READY'] == 'YES'
                    ip    = vm_nic_ipv4(controller_vm)
                    key   = user_template['SLURM_MUNGE_KEY'].to_s

                    if ready && !ip.empty? && !key.empty?
                        # The controller is the authority for cluster LDAP and
                        # publishes its effective config through OneGate. The
                        # worker consumes only these values and ignores the
                        # ONEAPP_LDAP_* context OneFlow injects into every role.
                        ldap = {
                            'url'           => user_template['LDAP_URL'].to_s,
                            'domain'        => user_template['LDAP_DOMAIN'].to_s,
                            'bind_user'     => user_template['LDAP_BIND_USER'].to_s,
                            'bind_password' => user_template['LDAP_BIND_PASSWORD'].to_s
                        }
                        return [ip, key, ldap]
                    end

                    msg(:warn, "Controller not ready yet (READY=#{user_template['READY']}), retrying in #{seconds}s...")
                rescue StandardError => e
                    msg(:warn, "OneGate controller discovery failed: #{e.message}. Retrying in #{seconds}s...")
                end

                raise 'FATAL: Could not discover Slurm controller through OneGate.' if retry_num.zero?

                sleep seconds
            end
        end

        def configure_worker_ldap(ldap)
            url    = ldap['url'].to_s
            domain = ldap['domain'].to_s

            if url.empty? || domain.empty?
                msg(:info, 'No LDAP published by controller, skipping SSSD setup')
                return
            end

            if url =~ %r{//(127\.0\.0\.1|localhost|\[?::1\]?)(:|/|$)}
                msg(:warn, "Refusing to configure worker SSSD against loopback LDAP URL '#{url}'; skipping")
                return
            end

            msg(:info, 'Configuring SSSD LDAP client from OneGate metadata')
            apply_sssd_ldap_client(url, domain, ldap['bind_user'].to_s, ldap['bind_password'].to_s)
            msg(:info, 'SSSD LDAP client configured successfully')
        end

        def bootstrap
            # No bootstrap actions defined for the worker.
        end

    end
end
