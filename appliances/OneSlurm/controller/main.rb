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

require_relative '../common/onegate'
require_relative '../common/ldap'
require_relative '../common/munge'
require_relative '../common/slurm'
require_relative '../common/infiniband'
require_relative '../common/accounting'
require_relative 'config'

# Base module for OpenNebula services
module Service

    # SlurmController service implementation
    module SlurmController

        extend self

        include OneSlurm::Ldap
        include OneSlurm::Munge
        include OneSlurm::Slurm
        include OneSlurm::Infiniband
        include OneSlurm::Accounting

        DEPENDS_ON    = []

        def install
            msg :info, 'SlurmController::install'

            # Install dependencies
            bash 'apt update && apt install munge libmunge-dev slurmctld slurm-client slurm-wlm-basic-plugins ldap-utils sssd sssd-ldap libnss-sss libpam-sss nfs-common -y'
            install_infiniband_packages

            # Enable service
            bash 'systemctl enable slurmctld'

            # Bake the scale-down node reconciler (script + systemd units) into
            # the image; the timer is enabled at configure time.
            install_node_reconciler

            msg :info, 'Installation completed successfully'
        end

        def install_infiniband_packages
            return unless INSTALL_INFINIBAND == 'true'

            install_controller_infiniband_packages
        end

        # Writes the reconciler script and systemd service/timer units. The
        # reconciler removes Slurm dynamic nodes whose worker VM is no longer
        # part of the OneFlow service (scale-down / deletion).
        def install_node_reconciler
            msg :info, 'Installing OneSlurm node reconciler'

            reconciler = <<~'RUBY'
                #!/usr/bin/env ruby
                # frozen_string_literal: true
                # OneSlurm controller node reconciler.
                # Deletes Slurm dynamic nodes whose worker VM has left the OneFlow
                # service (scale-down / deletion). Drains instead of deleting when a
                # stale node still has running jobs. Safe no-op for standalone deploys.
                require 'json'
                require 'open3'

                def run(cmd)
                    out, _err, st = Open3.capture3(*cmd)
                    [out, st.success?]
                end

                def log(text)
                    puts "[oneslurm-reconcile] #{text}"
                end

                # 1. Live worker node names from OneGate service membership.
                svc_out, ok = run(['onegate', '--json', 'service', 'show'])
                unless ok
                    log 'OneGate service show failed or unavailable; skipping'
                    exit 0
                end

                begin
                    svc = JSON.parse(svc_out)
                rescue StandardError => e
                    log "Could not parse OneGate service JSON: #{e.message}; skipping"
                    exit 0
                end

                roles = svc.dig('SERVICE', 'roles') || []
                worker_role = roles.find { |r| r['name'] == 'worker' }
                if worker_role.nil?
                    log 'No worker role in OneGate service; skipping'
                    exit 0
                end

                # `service show` only embeds a VM summary (ID/NAME), so fetch each
                # worker VM individually to read its published SLURM_NODENAME.
                vmids = (worker_role['nodes'] || []).map do |n|
                    n.dig('vm_info', 'VM', 'ID')
                end.compact

                live = []
                vmids.each do |vmid|
                    out, ok = run(['onegate', '--json', 'vm', 'show', vmid.to_s])
                    next unless ok

                    begin
                        vm = JSON.parse(out)
                    rescue StandardError
                        next
                    end

                    name = vm.dig('VM', 'USER_TEMPLATE', 'SLURM_NODENAME').to_s.strip
                    live << name unless name.empty?
                end

                # Never act if we cannot resolve any live node names (avoids mass
                # deletion before workers publish SLURM_NODENAME or on transient
                # OneGate errors).
                if live.empty?
                    log 'No live SLURM_NODENAME values resolved yet; skipping'
                    exit 0
                end

                # 2. Registered nodes + state from the controller.
                nodes_out, ok = run(['scontrol', '-o', 'show', 'nodes'])
                exit 0 unless ok

                registered = {}
                nodes_out.each_line do |line|
                    name  = line[/NodeName=(\S+)/, 1]
                    state = line[/State=(\S+)/, 1].to_s
                    registered[name] = state if name
                end

                # 3. Stale = registered, not live, and currently down / not responding.
                stale = registered.select do |name, state|
                    !live.include?(name) && state =~ /DOWN|NOT_RESPONDING/i
                end.keys

                if stale.empty?
                    log 'No stale nodes to reconcile'
                    exit 0
                end

                # 4. Delete stale nodes; drain (keep) if they still hold running jobs.
                stale.each do |name|
                    running, _ = run(['squeue', '-h', '-w', name, '-t', 'RUNNING', '-o', '%i'])
                    if running.strip.empty?
                        _, ok = run(['scontrol', 'delete', "NodeName=#{name}"])
                        log(ok ? "deleted stale node #{name}" : "failed to delete node #{name}")
                    else
                        _, ok = run(['scontrol', 'update', "NodeName=#{name}", 'State=DRAIN',
                                     'Reason=removed from OneFlow service'])
                        log(ok ? "drained node #{name} (still has running jobs)" : "failed to drain node #{name}")
                    end
                end
            RUBY
            file '/usr/local/sbin/oneslurm-reconcile-nodes', reconciler,
                 mode: 'u=rwx,go=rx', overwrite: true

            service_unit = <<~UNIT
                [Unit]
                Description=OneSlurm controller node reconciler
                After=slurmctld.service network-online.target

                [Service]
                Type=oneshot
                ExecStart=/bin/bash -c 'set -a; [ -f /var/run/one-context/one_env ] && . /var/run/one-context/one_env; exec /usr/local/sbin/oneslurm-reconcile-nodes'
            UNIT
            file '/etc/systemd/system/oneslurm-reconcile.service', service_unit,
                 mode: 'u=rw,go=r', overwrite: true

            timer_unit = <<~UNIT
                [Unit]
                Description=Run OneSlurm node reconciler periodically

                [Timer]
                OnBootSec=120s
                OnUnitActiveSec=60s
                Unit=oneslurm-reconcile.service

                [Install]
                WantedBy=timers.target
            UNIT
            file '/etc/systemd/system/oneslurm-reconcile.timer', timer_unit,
                 mode: 'u=rw,go=r', overwrite: true
        end

        def enable_node_reconciler
            msg :info, 'Enabling OneSlurm node reconciler timer'
            bash 'systemctl daemon-reload'
            bash 'systemctl enable --now oneslurm-reconcile.timer'
        end

        def configure
            msg :info, 'SlurmController::configure'
            onegate_vm_update ['READY=NO']
            accounting = discover_accounting

            #
            # Hostname Management
            #
            desired_hostname = 'slurm-one-controller'
            current_hostname = Socket.gethostname.split('.').first

            if current_hostname != desired_hostname
                msg :info, "Hostname is '#{current_hostname}'," \
                          " changing to '#{desired_hostname}'"
                bash "hostnamectl set-hostname #{desired_hostname}"

                # Update /etc/hosts
                ip = controller_ipv4

                hosts_entry = "#{ip}\t#{desired_hostname}"

                unless File.read('/etc/hosts').include?(hosts_entry)
                    msg :info, "Adding '#{hosts_entry}' to /etc/hosts"
                    File.open('/etc/hosts', 'a') { |f| f.puts hosts_entry }
                end
            end

            install_munge_key(accounting.fetch('munge_key_b64'))
            ldap = accounting.fetch('ldap')
            configure_discovered_ldap(ldap)
            write_controller_slurm_config(accounting_host: accounting.fetch('ip'))

            begin
                bash 'systemctl is-active slurmctld'
                apply_slurmctld_config
            rescue StandardError
                bash 'systemctl restart slurmctld'
                bash 'systemctl is-active slurmctld'
            end

            enable_node_reconciler
            publish_coordination
            msg :info, 'Configuration completed successfully'
        end

        def publish_coordination
            with_retries(msg: 'Attempting to update VM data in OneGate...') do
                onegate_vm_update ['READY=YES']
            end
        end

        def bootstrap
            msg :info, 'SlurmController::bootstrap'
            # No bootstrap actions defined for the controller yet.
            msg :info, 'Bootstrap completed successfully'
        end

    end
end
