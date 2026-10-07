# frozen_string_literal: true

# ---------------------------------------------------------------------------- #
# Copyright 2026, OpenNebula Project, OpenNebula Systems                       #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
# ---------------------------------------------------------------------------- #

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../lib/helpers'
end

require_relative 'config'
require 'fileutils'
require 'open3'
require 'securerandom'
require 'shellwords'
require 'uri'
require 'yaml'

# Base module for OpenNebula services
module Service

    # Open OnDemand web portal for OneSlurm clusters. The portal runs no Slurm of its own.
    # Open OnDemand sends the Slurm commands of each user to the controller of a cluster over
    # SSH (submit_host), with a key of the user that the controller reads from the shared home.
    module OpenOnDemand

        extend self

        DEPENDS_ON = []

        SINGLE_LINE = /\A[^\x00-\x1f\x7f]*\z/

        def install
            msg :info, 'OpenOnDemand::install'

            install_packages
            install_files

            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'OpenOnDemand::configure'

            validate_inputs
            configure_home
            configure_ldap
            configure_certificate
            configure_portal
            configure_clusters

            msg :info, 'Configuration completed successfully'
        rescue StandardError => e
            report_error(e)
            raise
        end

        def bootstrap
            msg :info, 'OpenOnDemand::bootstrap'

            # nginx_clean stops the web servers of the users, so each one reads the new
            # configuration with its next request.
            bash <<~SCRIPT
                /opt/ood/ood-portal-generator/sbin/update_ood_portal
                /opt/ood/nginx_stage/sbin/nginx_stage nginx_clean --force || true
                systemctl enable ondemand-dex apache2
                systemctl restart ondemand-dex apache2
            SCRIPT

            check_portal

            onegate_update 'OOD_URL', portal_url
            onegate_erase 'OOD_ERROR'

            msg :info, "Portal ready at #{portal_url}"
        rescue StandardError => e
            report_error(e)
            raise
        end

        # --- install ------------------------------------------------------------------ #

        def install_packages
            release = "ondemand-release-web_#{OOD_VERSION}.0-#{os_codename}_all.deb"

            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
                apt-get update
                apt-get install -y ca-certificates curl
                curl -fsSL -o /tmp/#{release} https://apt.osc.edu/ondemand/#{OOD_VERSION}/#{release}
                apt-get install -y /tmp/#{release}
                rm -f /tmp/#{release}
                apt-get update
                apt-get install -y ondemand ondemand-dex sssd-ldap libnss-sss ldap-utils \
                                   nfs-common openssh-client
                apt-get clean
            SCRIPT

            # Ubuntu ships mod_ssl disabled, and the portal configuration needs these modules.
            bash 'a2enmod -q ssl auth_openidc lua proxy proxy_http proxy_wstunnel headers rewrite env deflate'

            # The portal is the only site, also on port 80 for any host name.
            bash 'a2dissite -q 000-default'

            # Nothing answers until the first boot configures the portal. NFSv4 needs no rpcbind,
            # which would listen on port 111 of every interface.
            bash <<~SCRIPT
                systemctl disable --now apache2 ondemand-dex
                systemctl mask --now rpcbind.socket rpcbind.service
            SCRIPT

            # The remote desktop app of the package needs a VNC server on the nodes, and the
            # OneSlurm workers have none. A package upgrade puts it back.
            FileUtils.rm_rf '/var/www/ood/apps/sys/bc_desktop'

            # An upload uses temporary files of about three times its size. /tmp is a small RAM disk
            # on Ubuntu, so they go to /var/tmp. With the limit, three uploads at the same time use
            # about 2.3 GB of the 5 GB free on the disk. Bigger files go to a cluster with scp or rsync.
            File.open('/etc/ood/config/nginx_stage.yml', 'a') do |f|
                f.puts "\n# #{OOD_MANAGED_MARK}"
                f.puts "nginx_file_upload_max: '268435456'"
                f.puts 'pun_custom_env:'
                f.puts '  TMPDIR: /var/tmp'
            end

            # mod_auth_openidc keeps the sessions in a directory, so they survive the reload of
            # Apache that logrotate runs every night.
            bash 'install -d -o www-data -g www-data -m 700 /var/cache/apache2/mod_auth_openidc'
        end

        # The files directory holds the files of the appliance at the paths they take in the VM.
        def install_files
            FileUtils.cp_r "#{__dir__}/files/.", '/'

            bash <<~SCRIPT
                chmod 755 #{OOD_BIN_DIR}/*
                systemctl daemon-reload
            SCRIPT
        end

        def os_codename
            File.read('/etc/os-release')[/^VERSION_CODENAME=(.*)$/, 1].to_s.delete('"')
        end

        # --- inputs ------------------------------------------------------------------- #

        def validate_inputs
            {
                'ONEAPP_LDAP_SERVER_URL'     => OOD_LDAP_URL,
                'ONEAPP_LDAP_SERVER_DOMAIN'  => OOD_LDAP_DOMAIN,
                'ONEAPP_HOME_NFS_EXPORT'     => OOD_HOME_NFS_EXPORT,
                'ONEAPP_SLURM_CLUSTERS_LIST' => OOD_SLURM_CLUSTERS
            }.each do |input, value|
                raise "#{input} is required" if value.empty?
            end

            # The domain goes into sssd.conf as it is, the other inputs have a strict format.
            raise 'ONEAPP_LDAP_SERVER_DOMAIN must be a single line' unless OOD_LDAP_DOMAIN.match?(SINGLE_LINE)

            unless OOD_LDAP_URL.match?(%r{\Aldap://[A-Za-z0-9.-]+(:\d+)?/?\z})
                raise 'ONEAPP_LDAP_SERVER_URL must look like ldap://10.0.0.5 or ldap://10.0.0.5:389'
            end

            unless OOD_HOME_NFS_EXPORT.match?(%r{\A[A-Za-z0-9.-]+:/\S*\z})
                raise 'ONEAPP_HOME_NFS_EXPORT must look like 10.0.0.5:/export/home'
            end

            slurm_clusters
            portal_ip
        end

        # "name:IP" pairs separated by spaces or newlines, for example "cpu:10.0.0.20 gpu:10.0.0.30".
        def slurm_clusters
            clusters = OOD_SLURM_CLUSTERS.split.map do |pair|
                name, ip = pair.split(':', 2)

                unless name.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]{0,62}\z/) && ipv4?(ip)
                    raise 'ONEAPP_SLURM_CLUSTERS_LIST must be name:IP pairs like cpu:10.0.0.20 and ' \
                          "#{pair} is not one"
                end

                [name, ip]
            end

            repeated = clusters.map(&:first).tally.select { |_, count| count > 1 }.keys
            raise "ONEAPP_SLURM_CLUSTERS_LIST repeats the name #{repeated.join(' ')}" unless repeated.empty?

            clusters
        end

        def portal_ip
            raise 'The first NIC of the VM has no IPv4 address (ETH0_IP)' unless ipv4?(OOD_PORTAL_IP)

            OOD_PORTAL_IP
        end

        def portal_url
            "https://#{portal_ip}/"
        end

        # --- home --------------------------------------------------------------------- #

        # The homes come from the same NFS export as on the clusters, and the clusters read the
        # portal key of each user from them. Apache waits for this mount (RequiresMountsFor),
        # so the portal stays closed without it.
        def configure_home
            msg :info, "Mounting #{OOD_HOME_NFS_EXPORT} on /home"

            mount_nfs OOD_HOME_NFS_EXPORT, '/home', options: OOD_NFS_MOUNT_OPTIONS
        end

        # --- LDAP --------------------------------------------------------------------- #

        # SSSD gives the system the users of the directory, so the web server of each user runs
        # as its Unix user, with the same uid and home as on the clusters. The package adds sss
        # to /etc/nsswitch.conf. Dex checks the passwords against the same directory.
        def configure_ldap
            msg :info, "Reading the users from #{OOD_LDAP_URL}, under #{ldap_people_dn}"

            check_ldap

            sssd_ldap_client OOD_LDAP_URL, ldap_base_dn(OOD_LDAP_DOMAIN), header: OOD_MANAGED_MARK

            bash <<~SCRIPT
                systemctl enable sssd
                systemctl restart sssd
            SCRIPT
        end

        # A directory that does not answer, or a wrong domain, stops the configuration here and
        # not at the first login.
        def check_ldap
            output, status = Open3.capture2e('ldapsearch', '-x', '-LLL', '-o', 'nettimeout=10',
                                             '-H', OOD_LDAP_URL, '-b', ldap_people_dn, '-s', 'base', 'dn')
            return if status.success?

            raise "Cannot read the users of #{OOD_LDAP_DOMAIN} from #{OOD_LDAP_URL}: #{output.lines.first.to_s.strip}"
        end

        def ldap_people_dn
            "ou=People,#{ldap_base_dn(OOD_LDAP_DOMAIN)}"
        end

        # Dex needs an email for each user, and many directories have no mail attribute, so the
        # email is the user name with the domain of the directory.
        def dex_ldap_connector
            uri    = URI.parse(OOD_LDAP_URL)
            domain = if OOD_LDAP_DOMAIN.include?('=')
                         OOD_LDAP_DOMAIN.scan(/dc=([^,]+)/i).flatten.join('.')
                     else
                         OOD_LDAP_DOMAIN
                     end

            {
                'type'   => 'ldap',
                'id'     => 'ldap',
                'name'   => 'LDAP',
                'config' => {
                    'host'          => "#{uri.host}:#{uri.port}",
                    'insecureNoSSL' => true,
                    'userSearch'    => {
                        'baseDN'                => ldap_people_dn,
                        'filter'                => '(objectClass=posixAccount)',
                        'username'              => 'uid',
                        'idAttr'                => 'uid',
                        'emailSuffix'           => domain.empty? ? 'ldap.local' : domain,
                        'nameAttr'              => 'cn',
                        'preferredUsernameAttr' => 'uid'
                    }
                }
            }
        end

        # --- certificate -------------------------------------------------------------- #

        # A self-signed certificate for the IP of the portal. It stays across boots, so browsers
        # do not see a new one each time. The system trusts it, because mod_auth_openidc reads
        # the Dex metadata over HTTPS through the same address.
        def configure_certificate
            cert, key = certificate_files

            unless File.exist?(key) && File.exist?(cert) &&
                   system('openssl', 'x509', '-checkend', '2592000', '-noout', '-in', cert, out: File::NULL)
                msg :info, "Creating a self-signed certificate for #{portal_ip}"

                FileUtils.mkdir_p OOD_CERT_DIR
                bash <<~SCRIPT
                    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
                        -keyout '#{key}' -out '#{cert}' \
                        -subj '/CN=#{portal_ip}/O=OpenNebula Open OnDemand' \
                        -addext 'subjectAltName=IP:#{portal_ip}'
                    chmod 600 '#{key}'
                SCRIPT
            end

            trusted = '/usr/local/share/ca-certificates/open-ondemand-portal.crt'
            return if File.exist?(trusted) && FileUtils.identical?(cert, trusted)

            FileUtils.install cert, trusted, mode: 0o644
            bash 'update-ca-certificates'
        end

        def certificate_files
            ["#{OOD_CERT_DIR}/#{portal_ip}.crt", "#{OOD_CERT_DIR}/#{portal_ip}.key"]
        end

        # --- portal ------------------------------------------------------------------- #

        def configure_portal
            msg :info, "Writing the portal configuration for #{portal_url}"

            passphrase = '/etc/ood/config/.oidc_crypto_passphrase'
            file passphrase, SecureRandom.hex(32), mode: 'u=rw,go=', overwrite: true unless File.size?(passphrase)

            cert, key = certificate_files
            portal = {
                'servername'             => portal_ip,
                'ssl'                    => ["SSLCertificateFile \"#{cert}\"",
                                             "SSLCertificateKeyFile \"#{key}\""],
                'oidc_crypto_passphrase' => File.read(passphrase).strip,
                # The login form expires after five minutes by default, too short for some users,
                # and an expired form goes back to the portal instead of an error page.
                'oidc_settings'          => {
                    'OIDCStateTimeout' => 3600,
                    'OIDCDefaultURL'   => portal_url,
                    'OIDCCacheType'    => 'file',
                    'OIDCCacheDir'     => '/var/cache/apache2/mod_auth_openidc'
                },
                'pun_pre_hook_root_cmd'  => "#{OOD_BIN_DIR}/pun_prehook",
                'dex'                    => { 'connectors' => [dex_ldap_connector] }
            }

            # It holds the OIDC passphrase, so only root reads it.
            file OOD_PORTAL_YML, "# #{OOD_MANAGED_MARK}\n#{YAML.dump(portal)}", mode: 'u=rw,go=', overwrite: true
        end

        # --- Slurm clusters ----------------------------------------------------------- #

        # One file per cluster in clusters.d. Open OnDemand runs the Slurm commands of each user
        # on the controller of the cluster over SSH (submit_host), and the terminal opens there.
        def configure_clusters
            clusters = slurm_clusters
            save_host_keys(clusters)

            clusters.each do |name, ip|
                msg :info, "Cluster #{name} with controller #{ip}"

                cluster = {
                    'v2' => {
                        'metadata' => { 'title' => name },
                        'login'    => { 'host' => ip },
                        'job'      => { 'adapter' => 'slurm', 'submit_host' => ip }
                    }
                }
                file "#{OOD_CLUSTERS_DIR}/#{name}.yml", "# #{OOD_MANAGED_MARK}\n#{YAML.dump(cluster)}",
                     mode: 'u=rw,go=r', overwrite: true
            end

            # A cluster removed from the list leaves the portal.
            Dir["#{OOD_CLUSTERS_DIR}/*.yml"].each do |path|
                next if clusters.map(&:first).include?(File.basename(path, '.yml'))

                FileUtils.rm_f path if File.read(path).include?(OOD_MANAGED_MARK)
            end

            controllers = clusters.map(&:last).uniq
            file OOD_SHELL_ENV, <<~ENV, mode: 'u=rw,go=r', overwrite: true
                # #{OOD_MANAGED_MARK}
                OOD_DEFAULT_SSHHOST=#{controllers.first}
                OOD_SSHHOST_ALLOWLIST=#{controllers.join(':')}
            ENV
        end

        # Open OnDemand checks the host key of each controller against this file. The first key
        # a controller shows stays, so a controller that later shows another key is refused.
        # To accept a new key, run "ssh-keygen -R <IP> -f /etc/ood/ssh/known_hosts" and
        # "ssh-keyscan <IP> >> /etc/ood/ssh/known_hosts".
        def save_host_keys(clusters)
            saved = File.exist?(OOD_KNOWN_HOSTS) ? File.readlines(OOD_KNOWN_HOSTS, chomp: true) : []

            keys = clusters.map(&:last).uniq.flat_map do |ip|
                known = saved.select { |line| line.split.first == ip }
                known.empty? ? scan_host_keys(ip) : known
            end

            file OOD_KNOWN_HOSTS, keys.map { |line| "#{line}\n" }.join, mode: 'u=rw,go=r', overwrite: true
        end

        # A controller that is still booting has one minute to answer.
        def scan_host_keys(ip)
            with_retries(attempts: 12, delay: 5, msg: "Waiting for the SSH port of #{ip}") do
                raise "The controller #{ip} does not answer on the SSH port" unless tcp_port_open?(ip, 22)

                keys = bash("ssh-keyscan -T 5 #{ip} 2>/dev/null || true").lines.map(&:strip)
                keys = keys.reject { |line| line.empty? || line.start_with?('#') }
                raise "The controller #{ip} gives no SSH host key" if keys.empty?

                keys
            end
        end

        # --- checks and OneGate ------------------------------------------------------- #

        # Without -k, curl also checks that the system trusts the certificate of the portal.
        def check_portal
            with_retries(attempts: 12, delay: 5, msg: "Waiting for the portal on #{portal_url}") do
                code = bash("curl -s -o /dev/null -w '%{http_code}' --max-time 10 #{portal_url} || true",
                            chomp: true)
                dex  = bash("curl -s --max-time 10 #{portal_url}dex/.well-known/openid-configuration || true")

                unless %w[200 301 302 303].include?(code) && dex.include?('issuer')
                    raise "The portal does not answer on #{portal_url}. Read journalctl -u apache2 -u ondemand-dex"
                end
            end
        end

        # A failed boot must not keep the READY of the previous boot next to the error.
        def report_error(error)
            onegate_update 'OOD_ERROR', error_line(error)
            onegate_erase 'READY'
        end

        # bash() puts the trace of the whole script in the message, and the error is the last
        # line that is not part of the trace.
        def error_line(error)
            lines = error.message.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('+') }
            (lines.last || error.message).to_s.strip
        end

        # OneGate refuses commas and equal signs in a value even when quoted, and it needs the
        # quotes for spaces. The messages of this appliance avoid both.
        def onegate_update(key, value)
            quoted = value.to_s.tr(',=', ';:').gsub('\\', '\\\\').gsub('"', '\\"')
            bash "onegate vm update --data #{Shellwords.escape("#{key}=\"#{quoted}\"")}"
        rescue StandardError => e
            msg :warn, "OneGate did not accept #{key}: #{error_line(e)}"
        end

        # OneGate answers with an error when the attribute does not exist.
        def onegate_erase(attribute)
            bash "onegate vm update --erase #{attribute} || true"
        rescue StandardError
            nil
        end

    end

end
