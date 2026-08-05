# frozen_string_literal: true

# Shared Slurm configuration helpers: the controller writes the cluster
# configuration files, the worker builds its configless slurmd unit. The
# controller_ipv4 helper is used by both roles.
module OneSlurm

    module Slurm

        def controller_ipv4
            Socket.ip_address_list
                  .find { |a| a.ipv4? && !a.ipv4_loopback? }
                  .ip_address
        end

        def write_controller_slurm_config
            infiniband_config = slurm_infiniband_enabled? ? <<~CONF : ''
                MpiDefault=pmix
                PropagateResourceLimitsExcept=MEMLOCK
            CONF

            # Create slurm.conf
            slurm_conf = <<~CONF
                ClusterName=one
                SlurmctldHost=slurm-one-controller
                AuthType=auth/munge
                ProctrackType=proctrack/cgroup
                SchedulerType=sched/backfill
                SelectType=select/cons_tres
                GresTypes=gpu
                TaskPlugin=task/cgroup,task/affinity

                SlurmUser=slurm
                StateSaveLocation=/var/spool/slurmctld
                SlurmdSpoolDir=/var/spool/slurmd

                SlurmctldPidFile=/var/run/slurm/slurmctld.pid
                SlurmdPidFile=/var/run/slurm/slurmd.pid

                SlurmctldParameters=enable_configless
                #{infiniband_config}

                MaxNodeCount=100

                Nodeset=one Feature=one

                PartitionName=all  Nodes=ALL Default=yes
            CONF

            File.write('/etc/slurm/slurm.conf', slurm_conf)

            gres_conf = <<~CONF
                AutoDetect=nvidia
            CONF
            File.write('/etc/slurm/gres.conf', gres_conf)

            cgroup_conf = <<~CONF
                CgroupAutomount=yes
                ConstrainDevices=yes
            CONF
            File.write('/etc/slurm/cgroup.conf', cgroup_conf)

            # Create directories and set permissions
            FileUtils.mkdir_p('/var/spool/slurmd')
            FileUtils.mkdir_p('/var/spool/slurmctld')
            FileUtils.chown_R('slurm', 'slurm', '/var/spool/slurmd')
            FileUtils.chown_R('slurm', 'slurm', '/var/spool/slurmctld')
            FileUtils.chmod(0700, '/var/spool/slurmd')
            FileUtils.chmod(0700, '/var/spool/slurmctld')
        end

        def slurm_infiniband_enabled?
            return false unless defined?(ONEAPP_SLURM_INFINIBAND_ENABLE)

            ONEAPP_SLURM_INFINIBAND_ENABLE == true ||
                ONEAPP_SLURM_INFINIBAND_ENABLE.to_s.casecmp('YES').zero? ||
                ONEAPP_SLURM_INFINIBAND_ENABLE.to_s == '1'
        end

        def apply_slurmctld_config
            msg :info, 'Applying updated slurm.conf to running slurmctld'
            bash 'systemctl is-active slurmctld'
            bash 'scontrol reconfigure'
        rescue StandardError => e
            msg :warn, "Could not apply slurmctld reconfigure: #{e.message}"
        end

        def write_slurmd_unit(hostname)
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
