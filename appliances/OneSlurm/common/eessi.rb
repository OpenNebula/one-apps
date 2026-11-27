# frozen_string_literal: true

# EESSI software stack over CernVM-FS, plus Apptainer, for Controller and Workers.
module OneSlurm

    module Eessi

        CVMFS_RELEASE_DEB = 'https://cvmrepo.s3.cern.ch/cvmrepo/apt/cvmfs-release-latest_all.deb'

        # Ubuntu restricts unprivileged user namespaces, which Apptainer needs.
        APPTAINER_APPARMOR = <<~PROFILE
            abi <abi/4.0>,
            include <tunables/global>
            profile apptainer /usr/lib/@{multiarch}/apptainer/bin/starter{,-suid} flags=(unconfined) {
              userns,
              include if exists <local/apptainer>
            }
        PROFILE

        def install_eessi
            msg :info, 'Installing CernVM-FS and Apptainer'
            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                curl -fsSLo /tmp/cvmfs-release.deb #{CVMFS_RELEASE_DEB}
                apt install -y /tmp/cvmfs-release.deb
                rm -f /tmp/cvmfs-release.deb
                apt update
                apt install -y cvmfs apptainer
            SCRIPT
            File.write('/etc/apparmor.d/apptainer', APPTAINER_APPARMOR)
            configure_cvmfs
            bash 'cvmfs_config setup'
        end

        # /cvmfs mounts on first access, so this must run before slurmd starts.
        def configure_cvmfs
            config = <<~CONF
                CVMFS_CLIENT_PROFILE="single"
                CVMFS_QUOTA_LIMIT=#{ONEAPP_SLURM_CVMFS_QUOTA_LIMIT}
            CONF
            unless ONEAPP_SLURM_CVMFS_HTTP_PROXY.to_s.empty?
                config << "CVMFS_HTTP_PROXY=\"#{ONEAPP_SLURM_CVMFS_HTTP_PROXY}\"\n"
            end
            File.write('/etc/cvmfs/default.local', config)
        end

    end

end
