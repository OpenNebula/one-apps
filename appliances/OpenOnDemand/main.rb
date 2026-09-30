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
require 'securerandom'
require 'shellwords'
require 'socket'
require 'tempfile'
require 'uri'
require 'yaml'

# Base module for OpenNebula services
module Service

    # Open OnDemand web portal for OneSlurm clusters. The portal runs no Slurm of its own,
    # it sends the Slurm commands of each user over SSH to the controller of the cluster.
    module OpenOnDemand

        extend self

        DEPENDS_ON = []

        SINGLE_LINE = /\A[^\x00-\x1f\x7f]*\z/
        DNS_NAME    = /\A[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?\z/
        IPV4        = /\A\d{1,3}(\.\d{1,3}){3}\z/

        def install
            msg :info, 'OpenOnDemand::install'

            release = "ondemand-release-web_#{OOD_VERSION}.0-#{os_codename}_all.deb"

            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
                apt-get update
                apt-get install -y ca-certificates curl
                curl -fsSL -o /tmp/#{release} https://apt.osc.edu/ondemand/#{OOD_VERSION}/#{release}
                apt-get install -y /tmp/#{release}
                rm -f /tmp/#{release}
                apt-get update
                apt-get install -y ondemand ondemand-dex sssd-ldap libnss-sss libpam-sss \
                                   nfs-common openssh-client certbot
                apt-get clean
            SCRIPT

            # Ubuntu ships mod_ssl disabled, and the portal configuration needs these modules.
            bash 'a2enmod -q ssl auth_openidc lua proxy proxy_http proxy_wstunnel headers rewrite env deflate'

            # Dex has no configuration until the first boot writes it.
            bash 'systemctl disable --now ondemand-dex'

            # Without the NFS home, Apache would serve users an empty local /home, and the
            # mount would later hide what they wrote there. The web servers of the users run
            # under Apache, and the apache2 unit of Ubuntu 26.04 sets MemoryDenyWriteExecute,
            # which stops the JIT of Node.js, so the terminal app of the portal cannot start.
            file '/etc/systemd/system/apache2.service.d/one-appliance.conf', <<~UNIT, overwrite: true
                [Unit]
                RequiresMountsFor=/home

                [Service]
                MemoryDenyWriteExecute=no
            UNIT
            bash 'systemctl daemon-reload'

            # JupyterLab runs from the home of each user, so the app needs nothing on the nodes.
            FileUtils.rm_rf '/var/www/ood/apps/sys/jupyter'
            FileUtils.cp_r "#{__dir__}/apps/jupyter", '/var/www/ood/apps/sys/jupyter'
            bash <<~SCRIPT
                chown -R root:root /var/www/ood/apps/sys/jupyter
                chmod -R u=rwX,go=rX /var/www/ood/apps/sys/jupyter
                chmod 755 /var/www/ood/apps/sys/jupyter/template/script.sh.erb
            SCRIPT

            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'OpenOnDemand::configure'

            validate_inputs

            name     = portal_name
            clusters = slurm_clusters

            remove_desktop_app
            mount_home
            check_shared_home(clusters)
            configure_sssd
            cert, key = configure_certificate(name)
            write_portal_config(name, cert, key)
            write_pun_prehook
            write_clusters(clusters)
            update_known_hosts(clusters)
            write_shell_config(clusters)
            write_ssh_client_config(clusters)
            resolve_portal_name(name)

            msg :info, 'Configuration completed successfully'
        rescue StandardError => e
            onegate_update 'OOD_ERROR', error_line(e)
            raise
        end

        def bootstrap
            msg :info, 'OpenOnDemand::bootstrap'

            name = portal_name

            # The web servers of the users keep the old clusters until they restart, so they stop
            # here and start again with the next request of each user.
            bash <<~SCRIPT
                /opt/ood/ood-portal-generator/sbin/update_ood_portal
                /opt/ood/nginx_stage/sbin/nginx_stage nginx_clean --force || true
                systemctl enable ondemand-dex apache2
                systemctl restart ondemand-dex
                systemctl restart apache2
            SCRIPT

            check_portal(name)

            onegate_update 'OOD_URL', "https://#{name}/"
            onegate_erase 'OOD_ERROR'

            msg :info, "Portal ready at https://#{name}/"
        rescue StandardError => e
            onegate_update 'OOD_ERROR', error_line(e)
            raise
        end

        # --- inputs ------------------------------------------------------------------ #

        def validate_inputs
            {
                'ONEAPP_PORTAL_HOST_NAME'         => OOD_PORTAL_HOST_NAME,
                'ONEAPP_LDAP_SERVER_URL'          => OOD_LDAP_URL,
                'ONEAPP_LDAP_SERVER_DOMAIN'       => OOD_LDAP_DOMAIN,
                'ONEAPP_LDAP_BIND_USER'           => OOD_LDAP_BIND_USER,
                'ONEAPP_LDAP_BIND_PASSWORD'       => OOD_LDAP_BIND_PASSWORD,
                'ONEAPP_HOME_NFS_EXPORT'          => OOD_HOME_NFS_EXPORT,
                'ONEAPP_SLURM_CLUSTERS_LIST'      => OOD_SLURM_CLUSTERS
            }.each do |input, value|
                raise "#{input} must be a single line" unless value.match?(SINGLE_LINE)
            end

            unless OOD_PORTAL_HOST_NAME.empty? || OOD_PORTAL_HOST_NAME.match?(DNS_NAME)
                raise 'ONEAPP_PORTAL_HOST_NAME must be a DNS name or an IPv4 address'
            end

            if OOD_PORTAL_LETSENCRYPT && OOD_PORTAL_CERTIFICATE
                raise 'Turn on ONEAPP_PORTAL_LETSENCRYPT_ENABLED or ONEAPP_PORTAL_CERTIFICATE_ENABLED, not both'
            end

            if OOD_PORTAL_LETSENCRYPT && (OOD_PORTAL_HOST_NAME.empty? || OOD_PORTAL_HOST_NAME.match?(IPV4))
                raise 'Let\'s Encrypt needs ONEAPP_PORTAL_HOST_NAME, a public DNS name of this VM'
            end

            if OOD_PORTAL_CERTIFICATE && (OOD_PORTAL_CERTIFICATE_CHAIN.empty? || OOD_PORTAL_CERTIFICATE_KEY.empty?)
                raise 'ONEAPP_PORTAL_CERTIFICATE_ENABLED needs ONEAPP_PORTAL_CERTIFICATE_CHAIN and ' \
                      'ONEAPP_PORTAL_CERTIFICATE_KEY'
            end

            if OOD_LDAP_URL.empty?
                raise 'ONEAPP_LDAP_SERVER_URL is required, for example ldap://10.0.0.5'
            end

            unless OOD_LDAP_URL.match?(%r{\Aldaps?://[A-Za-z0-9.:\[\]-]+/?\z})
                raise 'ONEAPP_LDAP_SERVER_URL must look like ldap://host, ldaps://host or ldap://host:port'
            end

            raise 'ONEAPP_LDAP_SERVER_DOMAIN is required, for example slurm.local' if OOD_LDAP_DOMAIN.empty?

            if !OOD_LDAP_BIND_USER.empty? && OOD_LDAP_BIND_PASSWORD.empty?
                raise 'ONEAPP_LDAP_BIND_USER needs ONEAPP_LDAP_BIND_PASSWORD'
            end

            unless OOD_HOME_NFS_EXPORT.empty? || OOD_HOME_NFS_EXPORT.match?(%r{\A[A-Za-z0-9.\[\]:-]+:/\S*\z})
                raise 'ONEAPP_HOME_NFS_EXPORT must look like host:/export'
            end

            slurm_clusters
        end

        # "name:host" pairs, for example "gpu:10.0.0.10 cpu:10.0.0.20".
        def slurm_clusters
            clusters = OOD_SLURM_CLUSTERS.split.map do |pair|
                name, host = pair.split(':', 2)

                unless name.to_s.match?(/\A[A-Za-z0-9][A-Za-z0-9_-]{0,62}\z/) && host.to_s.match?(DNS_NAME)
                    raise 'ONEAPP_SLURM_CLUSTERS_LIST must be name:host pairs separated by spaces, ' \
                          "for example cpu:10.0.0.20, and #{pair} is not"
                end

                [name, host]
            end

            duplicated = clusters.map(&:first).tally.select { |_, count| count > 1 }.keys
            raise "ONEAPP_SLURM_CLUSTERS_LIST repeats #{duplicated.join(', ')}" unless duplicated.empty?

            clusters
        end

        # --- portal name and addresses ---------------------------------------------------- #

        def os_codename
            File.read('/etc/os-release')[/^VERSION_CODENAME=(.*)$/, 1].to_s.delete('"')
        end

        def portal_addresses
            Socket.ip_address_list.select { |a| a.ipv4? && !a.ipv4_loopback? }.map(&:ip_address)
        end

        # Without a host name the portal answers on the address of its first NIC.
        def portal_name
            return OOD_PORTAL_HOST_NAME unless OOD_PORTAL_HOST_NAME.empty?

            address = ENV.fetch('ETH0_IP', '')
            address = portal_addresses.first.to_s if address.empty?
            raise 'ONEAPP_PORTAL_HOST_NAME is empty and the VM has no IPv4 address' if address.empty?

            address
        end

        # mod_auth_openidc reads the Dex metadata through the portal name, and a public name
        # or a public address behind NAT can point to a place that does not route back to this
        # VM. A local route is not an address of the VM, so it stays out of the key origin.
        def resolve_portal_name(name)
            hosts = File.readlines('/etc/hosts').reject { |line| line.include?(OOD_MANAGED_MARK) }
            hosts << "127.0.0.1 #{name} # #{OOD_MANAGED_MARK}\n" unless name.match?(IPV4)
            File.write('/etc/hosts', hosts.join)

            return unless name.match?(IPV4) && !portal_addresses.include?(name)

            bash "ip route replace local #{name}/32 dev lo table local"
        end

        # The package ships a remote desktop app that needs a VNC server on the nodes, which the
        # OneSlurm workers do not have. It runs on every boot because a package upgrade puts it back.
        def remove_desktop_app
            FileUtils.rm_rf '/var/www/ood/apps/sys/bc_desktop'
        end

        # --- home over NFS ------------------------------------------------------------------ #

        # As OneSlurm does, an empty export leaves an NFS home mounted before as it is.
        def mount_home
            if OOD_HOME_NFS_EXPORT.empty?
                msg :info, 'ONEAPP_HOME_NFS_EXPORT is empty, no NFS home is mounted or changed'
                return
            end

            fstab = File.readlines('/etc/fstab').reject do |line|
                fields = line.split
                !line.start_with?('#') && fields[1] == '/home' && fields[2].to_s.start_with?('nfs')
            end
            fstab << "#{OOD_HOME_NFS_EXPORT} /home nfs4 #{OOD_NFS_MOUNT_OPTIONS} 0 0\n"
            File.write('/etc/fstab', fstab.join)

            current = bash('findmnt -n -o SOURCE /home || true', chomp: true)

            if current == OOD_HOME_NFS_EXPORT
                msg :info, "/home already mounted from #{current}"
                return
            end

            unless current.empty?
                raise "/home is already mounted from #{current}, which is not NFS" unless current.include?(':')

                # The web servers of the users stop without waiting, so the old home is detached
                # lazily instead of failing as busy.
                bash <<~SCRIPT
                    /opt/ood/nginx_stage/sbin/nginx_stage nginx_clean --force || true
                    umount -l /home
                SCRIPT
            end

            begin
                bash <<~SCRIPT
                    systemctl daemon-reload
                    mount /home
                SCRIPT
            rescue StandardError
                bash 'systemctl stop apache2'
                raise "Cannot mount #{OOD_HOME_NFS_EXPORT} on /home, the portal stays closed until it can"
            end

            msg :info, "/home mounted from #{OOD_HOME_NFS_EXPORT}"
        end

        # The controllers find the portal key of each user in the home they share with the
        # portal, so a cluster without that home can never run a command.
        def check_shared_home(clusters)
            return if clusters.empty?
            return unless bash('findmnt -n -o SOURCE /home || true', chomp: true).empty?

            raise 'ONEAPP_SLURM_CLUSTERS_LIST needs ONEAPP_HOME_NFS_EXPORT, the home the clusters share'
        end

        # --- users from LDAP ------------------------------------------------------------------ #

        # Same rules as OneSlurm: a DNS style domain becomes dc= parts, a DN stays as it is.
        def ldap_base_dn
            return OOD_LDAP_DOMAIN if OOD_LDAP_DOMAIN.include?('=')

            OOD_LDAP_DOMAIN.split('.').map { |part| "dc=#{part}" }.join(',')
        end

        def ldap_bind_dn
            return '' if OOD_LDAP_BIND_USER.empty?
            return OOD_LDAP_BIND_USER if OOD_LDAP_BIND_USER.include?('=')

            "cn=#{OOD_LDAP_BIND_USER},#{ldap_base_dn}"
        end

        # The system resolves the LDAP users, so each session runs as its Unix user with the
        # same uid and home as on the Slurm clusters. Dex checks the passwords, not PAM.
        def configure_sssd
            unless OOD_LDAP_URL.start_with?('ldaps://')
                msg :warn, "#{OOD_LDAP_URL} has no TLS, so the passwords of the users travel in clear text"
            end

            bind = ''
            unless ldap_bind_dn.empty?
                bind = <<~BIND
                    ldap_default_bind_dn = #{ldap_bind_dn}
                    ldap_default_authtok_type = password
                    ldap_default_authtok = #{OOD_LDAP_BIND_PASSWORD}
                BIND
            end

            file '/etc/sssd/sssd.conf', <<~SSSD, mode: 'u=rw,go=', overwrite: true
                # #{OOD_MANAGED_MARK}
                [sssd]
                services = nss
                config_file_version = 2
                domains = ldap

                [domain/ldap]
                id_provider = ldap
                auth_provider = none
                ldap_uri = #{OOD_LDAP_URL}
                ldap_search_base = #{ldap_base_dn}
                ldap_user_search_base = ou=People,#{ldap_base_dn}
                ldap_group_search_base = ou=Groups,#{ldap_base_dn}
                cache_credentials = True
                enumerate = False
                ldap_id_use_start_tls = false
                ldap_tls_reqcert = demand
                #{bind}
            SSSD

            nsswitch = File.readlines('/etc/nsswitch.conf').map do |line|
                next line unless line =~ /^(passwd|group|shadow):/

                fields = line.split
                fields.include?('sss') ? line : "#{fields.first}\t#{(fields[1..] + ['sss']).join(' ')}\n"
            end
            File.write('/etc/nsswitch.conf', nsswitch.join)

            bash <<~SCRIPT
                systemctl enable sssd
                systemctl restart sssd
            SCRIPT
        end

        # Dex checks the user password against the same directory. Many directories have no
        # mail attribute, so the email Dex needs is built from the user name.
        def dex_ldap_connector
            uri    = URI.parse(OOD_LDAP_URL)
            ldaps  = uri.scheme == 'ldaps'
            port   = uri.port || (ldaps ? 636 : 389)
            suffix = if OOD_LDAP_DOMAIN.include?('=')
                         OOD_LDAP_DOMAIN.scan(/dc=([^,]+)/i).flatten.join('.')
                     else
                         OOD_LDAP_DOMAIN
                     end

            config = { 'host' => "#{uri.host}:#{port}" }
            config['insecureNoSSL'] = true unless ldaps

            unless ldap_bind_dn.empty?
                config['bindDN'] = ldap_bind_dn
                config['bindPW'] = OOD_LDAP_BIND_PASSWORD
            end

            config['userSearch'] = {
                'baseDN'                => "ou=People,#{ldap_base_dn}",
                'filter'                => '(objectClass=posixAccount)',
                'username'              => 'uid',
                'idAttr'                => 'uid',
                'emailSuffix'           => suffix.empty? ? 'ldap.local' : suffix,
                'nameAttr'              => 'cn',
                'preferredUsernameAttr' => 'uid'
            }

            { 'type' => 'ldap', 'id' => 'ldap', 'name' => 'LDAP', 'config' => config }
        end

        # --- certificate ---------------------------------------------------------------------- #

        def configure_certificate(name)
            cert = File.join(OOD_CERT_DIR, "#{name}.crt")
            key  = File.join(OOD_CERT_DIR, "#{name}.key")
            FileUtils.mkdir_p OOD_CERT_DIR

            if OOD_PORTAL_CERTIFICATE
                install_own_certificate(cert, key)
            elsif OOD_PORTAL_LETSENCRYPT && !request_letsencrypt(name) && !letsencrypt_valid?(name)
                msg :warn, "Let's Encrypt failed for #{name}, the portal uses a self-signed certificate"
            end

            # A failed renewal keeps a certificate that is still valid, and a portal that never got
            # one keeps the same self-signed certificate across boots.
            if OOD_PORTAL_LETSENCRYPT && letsencrypt_valid?(name)
                link_letsencrypt(name, cert, key)
            elsif File.symlink?(cert) || !(File.exist?(cert) && File.exist?(key))
                issue_selfsigned(name, cert, key)
            end

            remove_stale_letsencrypt(cert)
            trust_certificate(cert) unless File.symlink?(cert)

            [cert, key]
        end

        def issue_selfsigned(name, cert, key)
            msg :info, "Generating a self-signed certificate for #{name}"

            san = name.match?(IPV4) ? "IP:#{name}" : "DNS:#{name}"
            FileUtils.rm_f [cert, key]

            bash <<~SCRIPT
                openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
                    -keyout '#{key}' -out '#{cert}' \
                    -subj '/CN=#{name}/O=OpenNebula Open OnDemand' \
                    -addext 'subjectAltName=#{san}'
                chmod 600 '#{key}'
            SCRIPT
        end

        # The wizard gives the certificate and the key as base64 PEM (text64 inputs). A value
        # that already starts with the PEM header is taken as it is.
        def install_own_certificate(cert, key)
            pem = ->(value) { value.start_with?('-----BEGIN') ? "#{value}\n" : Base64.decode64(value) }

            # Only the certificates of the chain, so a private key pasted with them never lands
            # in a file that everyone reads.
            chain = pem.call(OOD_PORTAL_CERTIFICATE_CHAIN).scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m)
            raise 'ONEAPP_PORTAL_CERTIFICATE_CHAIN has no PEM certificate' if chain.empty?

            Tempfile.create('cert') do |tmp_cert|
                Tempfile.create('key') do |tmp_key|
                    File.write(tmp_cert.path, "#{chain.join("\n")}\n")
                    File.write(tmp_key.path, pem.call(OOD_PORTAL_CERTIFICATE_KEY))

                    cert_pub = bash("openssl x509 -noout -pubkey -in '#{tmp_cert.path}' | sha256sum", chomp: true)
                    key_pub  = bash("openssl pkey -pubout -in '#{tmp_key.path}' | sha256sum", chomp: true)
                    raise 'ONEAPP_PORTAL_CERTIFICATE_KEY is not the key of ONEAPP_PORTAL_CERTIFICATE_CHAIN' \
                        unless cert_pub == key_pub

                    FileUtils.rm_f [cert, key]
                    FileUtils.install tmp_cert.path, cert, mode: 0o644
                    FileUtils.install tmp_key.path, key, mode: 0o600
                end
            end

            msg :info, "Own certificate installed at #{cert}"
        rescue RuntimeError => e
            raise e if e.message.start_with?('ONEAPP_')

            raise 'ONEAPP_PORTAL_CERTIFICATE_CHAIN and ONEAPP_PORTAL_CERTIFICATE_KEY must be PEM, ' \
                  'as they are or in base64'
        end

        # The hooks stop Apache to free port 80 for the challenge, and certbot keeps them for
        # the renewals of its timer.
        def request_letsencrypt(name)
            msg :info, "Requesting a Let's Encrypt certificate for #{name}"

            # Let's Encrypt no longer sends expiry emails, so the account needs no address.
            args = ['certbot', 'certonly', '--standalone', '--non-interactive', '--agree-tos',
                    '--register-unsafely-without-email', '--keep-until-expiring',
                    '--cert-name', name, '-d', name,
                    '--pre-hook', 'systemctl stop apache2', '--post-hook', 'systemctl start apache2']

            output, status = Open3.capture2e(*args)
            puts output
            status.success?
        end

        def letsencrypt_valid?(name)
            fullchain = "/etc/letsencrypt/live/#{name}/fullchain.pem"
            File.exist?(fullchain) && system('openssl', 'x509', '-checkend', '0', '-noout', '-in', fullchain)
        end

        def link_letsencrypt(name, cert, key)
            return if File.symlink?(cert) && File.readlink(cert).start_with?("/etc/letsencrypt/live/#{name}/")

            FileUtils.rm_f [cert, key]
            FileUtils.ln_s "/etc/letsencrypt/live/#{name}/fullchain.pem", cert
            FileUtils.ln_s "/etc/letsencrypt/live/#{name}/privkey.pem", key
        end

        # A certificate the portal no longer uses would still run its renewal hooks, which stop
        # Apache twice a day.
        def remove_stale_letsencrypt(cert)
            active = File.symlink?(cert) ? File.readlink(cert)[%r{\A/etc/letsencrypt/live/([^/]+)/}, 1] : nil

            Dir['/etc/letsencrypt/renewal/*.conf'].each do |conf|
                lineage = File.basename(conf, '.conf')
                next if lineage == active

                msg :info, "Removing the Let's Encrypt certificate #{lineage}, the portal does not use it"
                Open3.capture2e('certbot', 'delete', '--non-interactive', '--cert-name', lineage)
            end
        end

        # mod_auth_openidc fetches the Dex metadata over HTTPS through the portal name, so the
        # system must trust a self-signed certificate or every login ends in a 500.
        def trust_certificate(cert)
            trusted = '/usr/local/share/ca-certificates/open-ondemand-portal.crt'
            return if File.exist?(trusted) && FileUtils.identical?(cert, trusted)

            FileUtils.install cert, trusted, mode: 0o644
            bash 'update-ca-certificates'
        end

        # --- portal ----------------------------------------------------------------------------- #

        def write_portal_config(name, cert, key)
            passphrase = '/etc/ood/config/.oidc_crypto_passphrase'
            file passphrase, SecureRandom.hex(32), mode: 'u=rw,go=', overwrite: true unless File.size?(passphrase)

            portal = {
                'servername'             => name,
                'ssl'                    => ["SSLCertificateFile \"#{cert}\"",
                                             "SSLCertificateKeyFile \"#{key}\""],
                # The claim is the uid, and this keeps the part before an at sign if any.
                'user_map_match'         => '^([^@]+)',
                'oidc_crypto_passphrase' => File.read(passphrase).strip,
                # Five minutes to fill the login form are not enough for everyone.
                'oidc_settings'          => {
                    'OIDCStateTimeout' => 3600,
                    'OIDCDefaultURL'   => "https://#{name}/"
                },
                'pun_pre_hook_root_cmd'  => "#{OOD_BIN_DIR}/pun_prehook",
                # The interactive sessions run on the nodes, and the portal reaches them through
                # /node/<host>/<port>, only on private addresses.
                'node_uri'               => '/node',
                'rnode_uri'              => '/rnode',
                'host_regex'             => '(?:10|172\.(?:1[6-9]|2\d|3[01])|192\.168)\.\d+\.\d+',
                'dex'                    => { 'connectors' => [dex_ldap_connector] }
            }

            # It holds the bind password, so only root reads it.
            file OOD_PORTAL_YML, "# #{OOD_MANAGED_MARK}\n#{YAML.dump(portal)}", mode: 'u=rw,go=', overwrite: true
        end

        # nginx_stage runs the hook as root before it starts the web server of a user. The root
        # part creates a missing home. The user part runs as the user, because an NFS export with
        # root_squash does not let root write inside a home.
        def write_pun_prehook
            FileUtils.mkdir_p OOD_BIN_DIR

            file "#{OOD_BIN_DIR}/pun_prehook", <<~'HOOK', mode: 'u=rwx,go=rx', overwrite: true
                #!/usr/bin/env bash
                # Runs as root before the web server of a user starts. nginx_stage discards its
                # output and its exit code, so it logs to syslog with the tag ood-prehook.
                set -uo pipefail

                user=""
                while (( $# )); do
                    case "$1" in
                        --user) user="${2:-}"; shift 2 ;;
                        --user=*) user="${1#--user=}"; shift ;;
                        *) [[ -z "$user" ]] && user="$1"; shift ;;
                    esac
                done
                [[ -z "$user" || "$user" == "root" ]] && exit 0

                home="$(getent passwd "$user" | cut -d: -f6)"
                if [[ -z "$home" ]]; then
                    logger -t ood-prehook "${user} is not a user of the LDAP directory"
                    exit 0
                fi

                if [[ ! -d "$home" ]]; then
                    if install -d -m 0700 -o "$user" -g "$(id -gn "$user")" "$home"; then
                        logger -t ood-prehook "home of ${user} created at ${home}"
                    else
                        logger -t ood-prehook "the home of ${user} at ${home} is missing and root cannot create it"
                        exit 1
                    fi
                fi

                runuser -u "$user" -- "$(dirname "$0")/pun_prehook_user" "$home"
            HOOK

            file "#{OOD_BIN_DIR}/pun_prehook_user", <<~'HOOK'.sub('@@ORIGIN@@', portal_addresses.join(',')),
                #!/usr/bin/env bash
                # Runs as the user from pun_prehook. $1 is the home of the user.
                set -uo pipefail
                umask 077

                home="$1"
                sshdir="${home}/.ssh"
                key="${sshdir}/id_ed25519_portal"
                origin='from="@@ORIGIN@@"'

                # The Slurm commands and the terminal reach the controllers with this key, which
                # /etc/ood/ssh/ssh_config names for them. The controllers read
                # authorized_keys from the same NFS home, and the from= option limits the key to
                # the addresses of this portal.
                if [[ ! -f "$key" ]]; then
                    mkdir -p "$sshdir"
                    if ssh-keygen -q -t ed25519 -N "" -C "open-ondemand-portal" -f "$key" </dev/null; then
                        logger -t ood-prehook "portal key created for $(id -un)"
                    else
                        logger -t ood-prehook "could not create the portal key of $(id -un)"
                    fi
                fi

                # One line per key, with the current addresses of the portal, also when the user
                # removed it or the portal addresses changed.
                if [[ -f "${key}.pub" ]]; then
                    keys="${sshdir}/authorized_keys"
                    pub="$(cut -d' ' -f2 "${key}.pub")"
                    line="${origin} $(cat "${key}.pub")"
                    touch "$keys"
                    if ! grep -qxF "$line" "$keys"; then
                        { grep -vF "$pub" "$keys"; printf '%s\n' "$line"; } > "${keys}.new" \
                            && mv "${keys}.new" "$keys"
                        logger -t ood-prehook "portal key of $(id -un) authorized from the portal"
                    fi
                fi

                # Open OnDemand 4.2 creates the Job Composer database empty and does not migrate
                # it, so every page of the composer returns a 500 until this runs once.
                app=/var/www/ood/apps/sys/myjobs
                db="${home}/ondemand/data/sys/myjobs/production.sqlite3"
                if [[ -x "${app}/bin/rake" ]] && ! python3 -c '
                import sqlite3, sys
                sqlite3.connect("file:%s?mode=ro" % sys.argv[1], uri=True).execute("select 1 from workflows")
                ' "$db" 2>/dev/null; then
                    mkdir -p "$(dirname "$db")"
                    if (cd "$app" && env \
                            GEM_PATH="/opt/ood/gems:$(ruby -e 'print Gem.default_path.join(":")')" \
                            RAILS_ENV=production SECRET_KEY_BASE="$(openssl rand -hex 32)" \
                            ./bin/rake db:migrate) >/dev/null 2>&1; then
                        logger -t ood-prehook "job composer database of $(id -un) migrated"
                    else
                        logger -t ood-prehook "could not migrate the job composer database of $(id -un)"
                    fi
                fi
            HOOK
                 mode: 'u=rwx,go=rx', overwrite: true
        end

        # --- Slurm clusters ------------------------------------------------------------------------ #

        # Each cluster has a directory with one link per Slurm command, all to the same proxy,
        # which reads the controller from the file host next to the links.
        def write_clusters(clusters)
            proxy = "#{OOD_BIN_DIR}/slurm-proxy"
            root  = "#{OOD_BIN_DIR}/slurm"

            file proxy, <<~'PROXY', mode: 'u=rwx,go=rx', overwrite: true
                #!/usr/bin/env bash
                # Runs the Slurm command this link is named after on the controller of the
                # cluster its directory is named after, as the user, over SSH. Each argument is
                # quoted for the remote shell, and sbatch reads the job script from stdin.
                set -u
                dir="$(dirname "$0")"
                host="$(cat "${dir}/host" 2>/dev/null)"
                [[ -n "$host" ]] || { echo "the cluster $(basename "$dir") has no controller" >&2; exit 1; }
                command="$(basename "$0")"

                # Open OnDemand passes sbatch the values of the variables that --export names in the
                # environment, and SSH does not carry them, so they go before the remote command.
                if [[ "$command" == sbatch ]]; then
                    exports=""
                    previous=""
                    for arg in "$@"; do
                        [[ "$previous" == --export ]] && exports="$arg"
                        [[ "$arg" == --export=* ]] && exports="${arg#--export=}"
                        previous="$arg"
                    done
                    IFS=, read -ra names <<< "$exports"
                    for name in "${names[@]}"; do
                        [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ && "$name" != ALL && "$name" != NONE ]] || continue
                        [[ -v "$name" ]] && command="${name}=$(printf '%q' "${!name}") ${command}"
                    done
                fi

                for arg in "$@"; do command+=" $(printf '%q' "$arg")"; done
                exec "$(dirname "$(readlink -f "$0")")/ssh" -o BatchMode=yes -o ConnectTimeout=15 \
                    -o LogLevel=ERROR "$host" "$command"
            PROXY

            FileUtils.mkdir_p OOD_CLUSTERS_DIR

            clusters.each do |name, host|
                dir = "#{root}/#{name}"
                FileUtils.mkdir_p dir
                file "#{dir}/host", "#{host}\n", mode: 'u=rw,go=r', overwrite: true
                OOD_SLURM_COMMANDS.each { |command| FileUtils.ln_sf '../../slurm-proxy', "#{dir}/#{command}" }

                cluster = {
                    'v2' => {
                        'metadata' => { 'title' => name },
                        'login'    => { 'host' => host },
                        'job'      => {
                            'adapter'       => 'slurm',
                            'bin_overrides' => OOD_SLURM_COMMANDS.to_h { |command| [command, "#{dir}/#{command}"] }
                        }
                    }
                }

                file "#{OOD_CLUSTERS_DIR}/#{name}.yml", "# #{OOD_MANAGED_MARK}\n#{YAML.dump(cluster)}",
                     mode: 'u=rw,go=r', overwrite: true

                msg :info, "Cluster #{name} with controller #{host}"
            end

            names = clusters.map(&:first)

            Dir["#{OOD_CLUSTERS_DIR}/*.yml"].each do |path|
                next if names.include?(File.basename(path, '.yml'))

                FileUtils.rm_f path if File.read(path).include?(OOD_MANAGED_MARK)
            end

            Dir["#{root}/*"].each do |path|
                FileUtils.rm_rf path unless names.include?(File.basename(path))
            end
        end

        # The proxy and the terminal check the host key of every controller against this file.
        # The first key a controller shows stays, so a host that later shows another key is
        # refused. To accept a new key, remove the old one with
        # "ssh-keygen -R <host> -f /etc/ood/ssh/known_hosts" and reconfigure the portal.
        def update_known_hosts(clusters)
            pinned = File.exist?(OOD_KNOWN_HOSTS) ? File.readlines(OOD_KNOWN_HOSTS).map(&:strip) : []

            keys = clusters.map(&:last).uniq.flat_map do |host|
                known = pinned.select { |line| line.split.first.to_s.split(',').include?(host) }
                known.empty? ? scan_host_keys(host) : known
            end

            FileUtils.mkdir_p OOD_SSH_DIR
            file OOD_KNOWN_HOSTS, keys.map { |line| "#{line}\n" }.join, mode: 'u=rw,go=r', overwrite: true
        end

        def scan_host_keys(host)
            6.times do
                found = bash("ssh-keyscan -T 5 #{host} 2>/dev/null || true").lines.map(&:strip)
                found = found.reject { |line| line.empty? || line.start_with?('#') }
                return found unless found.empty?

                sleep 5
            end

            msg :warn, "The controller #{host} does not answer on port 22, reconfigure the portal when it does"
            []
        end

        # The proxy and the terminal run ssh through this wrapper with the configuration of the
        # portal. The controllers use their pinned host keys. The other nodes of their networks
        # come and go as the clusters scale, so their key is accepted the first time and kept in
        # the home of the user.
        def write_ssh_client_config(clusters)
            FileUtils.mkdir_p OOD_SSH_DIR

            hosts = ''
            unless clusters.empty?
                controllers = clusters.map(&:last).uniq
                nodes       = node_patterns(clusters) + controllers.map { |c| "!#{c}" }
                hosts = <<~HOSTS
                    Host #{controllers.join(' ')}
                        IdentityFile ~/.ssh/id_ed25519_portal
                        GlobalKnownHostsFile #{OOD_KNOWN_HOSTS}
                        UserKnownHostsFile /dev/null
                        StrictHostKeyChecking yes
                    Host #{nodes.join(' ')}
                        IdentityFile ~/.ssh/id_ed25519_portal
                        UserKnownHostsFile ~/.ssh/known_hosts_portal
                        StrictHostKeyChecking accept-new
                HOSTS
            end

            file OOD_SSH_CONFIG, <<~SSH, mode: 'u=rw,go=r', overwrite: true
                # #{OOD_MANAGED_MARK}
                #{hosts}Host *
                    GlobalKnownHostsFile #{OOD_KNOWN_HOSTS}
                    UserKnownHostsFile /dev/null
                    StrictHostKeyChecking yes
            SSH

            file "#{OOD_BIN_DIR}/ssh", <<~WRAPPER, mode: 'u=rwx,go=rx', overwrite: true
                #!/bin/sh
                # #{OOD_MANAGED_MARK}
                exec ssh -F #{OOD_SSH_CONFIG} "$@"
            WRAPPER
        end

        # The nodes of a cluster share the network of its controller, 10.0.0.* for 10.0.0.5.
        def node_patterns(clusters)
            clusters.map(&:last).uniq.map { |host| host.match?(IPV4) ? host.sub(/\.\d+\z/, '.*') : host }.uniq
        end

        # The terminal of the portal opens an SSH session on a controller, or on the node of an
        # interactive session from its card.
        def write_shell_config(clusters)
            path = '/etc/ood/config/apps/shell/env'

            if clusters.empty?
                FileUtils.rm_f path
                return
            end

            hosts = clusters.map(&:last)
            file path, <<~ENV, mode: 'u=rw,go=r', overwrite: true
                # #{OOD_MANAGED_MARK}
                OOD_DEFAULT_SSHHOST=#{hosts.first}
                OOD_SSHHOST_ALLOWLIST=#{(hosts + node_patterns(clusters)).uniq.join(':')}
                OOD_SSH_WRAPPER=#{OOD_BIN_DIR}/ssh
            ENV
        end

        # --- checks and OneGate ------------------------------------------------------------------- #

        def check_portal(name)
            12.times do
                code = bash("curl -sk -o /dev/null -w '%{http_code}' --max-time 10 https://#{name}/ || true",
                            chomp: true)
                dex  = bash("curl -sk --max-time 10 https://#{name}/dex/.well-known/openid-configuration || true")

                return if %w[200 301 302 303].include?(code) && dex.include?('issuer')

                sleep 5
            end

            raise "The portal does not answer on https://#{name}/, read journalctl -u apache2 -u ondemand-dex"
        end

        # bash() puts the trace of the whole script in the message, and the error is the last
        # line that is not part of the trace.
        def error_line(error)
            lines = error.message.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('+') }
            (lines.last || error.message).to_s.strip
        end

        # OneGate refuses commas and equal signs in a value even when quoted, and it needs the
        # quotes for spaces.
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
