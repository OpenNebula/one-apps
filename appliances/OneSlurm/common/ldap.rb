# frozen_string_literal: true

require 'shellwords'

# LDAP / SSSD helpers for both Slurm roles.
#
module OneSlurm

    module Ldap

        def ldap_simple_bind_enabled?
            !ONEAPP_LDAP_ADMIN_PASSWORD.empty?
        end

        def ldap_base_dn(domain = ONEAPP_LDAP_DOMAIN)
            domain = domain.to_s.strip
            return '' if domain.empty?

            domain.include?('=') ? domain : domain.split('.').map { |p| "dc=#{p}" }.join(',')
        end

        def ldap_bind_dn(domain = ONEAPP_LDAP_DOMAIN, bind_user = ONEAPP_LDAP_BIND_USER)
            name = bind_user.to_s.strip
            return '' if name.empty?

            name.include?('=') ? name : "cn=#{name},#{ldap_base_dn(domain)}"
        end

        def ldap_admin_dn
            name = ONEAPP_LDAP_ADMIN_USER.to_s.strip
            return '' if name.empty?

            name.include?('=') ? name : "cn=#{name},#{ldap_base_dn}"
        end

        def ldap_client_enabled?
            !ONEAPP_LDAP_ENABLE && !ONEAPP_LDAP_URL.to_s.empty? && !ONEAPP_LDAP_DOMAIN.to_s.empty?
        end

        def ldap_base_object_ldif
            attr, value = ldap_base_dn.split(',', 2).first.split('=', 2)
            attr = attr.downcase
            domain = ONEAPP_LDAP_DOMAIN.to_s.strip
            organization = if domain.empty?
                               'Slurm'
                           elsif domain.include?('=')
                               domain.split(',', 2).first.split('=', 2).last.capitalize
                           else
                               domain.split('.').first.capitalize
                           end

            case attr
            when 'dc'
                <<~LDIF
                    objectClass: dcObject
                    objectClass: organization
                    o: #{organization}
                    dc: #{value}
                LDIF
            when 'o'
                <<~LDIF
                    objectClass: organization
                    o: #{value}
                LDIF
            when 'ou'
                <<~LDIF
                    objectClass: organizationalUnit
                    ou: #{value}
                LDIF
            when 'c'
                <<~LDIF
                    objectClass: country
                    c: #{value}
                LDIF
            else
                <<~LDIF
                    objectClass: extensibleObject
                    #{attr}: #{value}
                LDIF
            end
        end

        def install_ldap_server
            FileUtils.mkdir_p('/etc/ldap')

            debconf = <<~DEBCONF
                slapd slapd/no_configuration boolean true
            DEBCONF
            debconf_file = '/etc/ldap/.one_slurm_ldap_debconf'
            file debconf_file, debconf, mode: 'u=rw,go=', overwrite: true

            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                debconf-set-selections < #{debconf_file}
                apt update
                apt install slapd -y
                rm -f #{debconf_file}
            SCRIPT
        end

        def ensure_slapd_active
            bash 'systemctl enable slapd'
            bash 'systemctl restart slapd'
            bash 'systemctl is-active slapd'
        end

        def setup_ldap_database
            if File.exist?(LDAP_CONFIGURED_MARKER)
                msg :info, 'LDAP database already configured, ensuring slapd is active'
                return ensure_slapd_active
            end

            msg :info, 'Configuring OpenLDAP database'

            root_pw_line = ''
            if ldap_simple_bind_enabled?
                hash = bash("slappasswd -s #{ONEAPP_LDAP_ADMIN_PASSWORD}", chomp: true)
                root_pw_line = "olcRootPW: #{hash}\n"
            end

            database_ldif = <<~LDIF
                dn: olcDatabase=mdb,cn=config
                objectClass: olcDatabaseConfig
                objectClass: olcMdbConfig
                olcDatabase: mdb
                olcSuffix: #{ldap_base_dn}
                olcRootDN: #{ldap_admin_dn}
                #{root_pw_line}olcDbDirectory: /var/lib/ldap
                olcDbIndex: objectClass eq
                olcDbIndex: uid,cn eq
                olcDbIndex: uidNumber,gidNumber eq
                olcDbIndex: member,memberUid eq
                olcAccess: to attrs=userPassword by dn.exact="#{LDAP_EXTERNAL_ADMIN_DN}" manage by anonymous auth by * none
                olcAccess: to dn.subtree="ou=People,#{ldap_base_dn}" by dn.exact="#{LDAP_EXTERNAL_ADMIN_DN}" manage by dn.exact="#{ldap_admin_dn}" write by * read
                olcAccess: to dn.subtree="ou=Groups,#{ldap_base_dn}" by dn.exact="#{LDAP_EXTERNAL_ADMIN_DN}" manage by dn.exact="#{ldap_admin_dn}" write by * read
                olcAccess: to * by dn.exact="#{LDAP_EXTERNAL_ADMIN_DN}" manage by dn.exact="#{ldap_admin_dn}" write by * read
            LDIF

            base_ldif = <<~LDIF
                dn: #{ldap_base_dn}
                objectClass: top
                #{ldap_base_object_ldif}

                dn: ou=People,#{ldap_base_dn}
                objectClass: organizationalUnit
                ou: People

                dn: ou=Groups,#{ldap_base_dn}
                objectClass: organizationalUnit
                ou: Groups
            LDIF

            if ldap_simple_bind_enabled?
                verify_cmd = "ldapwhoami -x -D #{ldap_admin_dn} -w #{ONEAPP_LDAP_ADMIN_PASSWORD} >/dev/null"
            else
                verify_cmd = 'ldapwhoami -Y EXTERNAL -H ldapi:/// >/dev/null'
            end

            bootstrap_ldif_file = '/etc/ldap/.one_slurm_ldap_bootstrap.ldif'

            bash <<~SCRIPT
                install -d -o openldap -g openldap -m 0750 /etc/ldap/slapd.d
                if [ ! -f /etc/ldap/slapd.conf ]; then
                    printf 'CONFIGDBDIR\\t/etc/ldap/slapd.d\\n' > /etc/ldap/slapd.conf
                fi
                if [ ! -e /etc/ldap/slapd.d/cn=config.ldif ]; then
                    {
                        echo 'dn: cn=config'
                        echo 'objectClass: olcGlobal'
                        echo 'cn: config'
                        echo 'olcAllows: bind_v2'
                        echo ''
                        echo 'dn: olcDatabase={0}config,cn=config'
                        echo 'objectClass: olcDatabaseConfig'
                        echo 'objectClass: olcConfig'
                        echo 'olcDatabase: {0}config'
                        echo 'olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * none'
                        echo 'olcAccess: to attrs=userPassword,olcRootPW by anonymous auth by * none'
                        echo 'olcAccess: to * by * read'
                        echo 'olcLastMod: TRUE'
                        echo 'olcRootDN: cn=admin,cn=config'
                        echo ''
                        echo 'dn: cn=schema,cn=config'
                        echo 'objectClass: olcSchemaConfig'
                        echo 'cn: schema'
                        echo ''
                        echo 'include: file:///etc/ldap/schema/core.ldif'
                        echo 'include: file:///etc/ldap/schema/cosine.ldif'
                        echo 'include: file:///etc/ldap/schema/nis.ldif'
                        echo 'include: file:///etc/ldap/schema/inetorgperson.ldif'
                        echo ''
                        echo 'dn: cn=module{0},cn=config'
                        echo 'objectClass: olcModuleList'
                        echo 'cn: module{0}'
                        echo 'olcModulePath: /usr/lib/ldap'
                        echo 'olcModuleLoad: back_mdb.so'
                    } > #{bootstrap_ldif_file}
                    slapadd -n 0 -F /etc/ldap/slapd.d -l #{bootstrap_ldif_file}
                    chown -R openldap:openldap /etc/ldap/slapd.d
                    rm -f #{bootstrap_ldif_file}
                fi
            SCRIPT

            ensure_slapd_active

            bash <<~SCRIPT
                install -d -o openldap -g openldap -m 0700 /var/lib/ldap
                ldapadd -Y EXTERNAL -H ldapi:/// <<'LDIF'
                #{database_ldif}
                LDIF
                ldapadd -Y EXTERNAL -H ldapi:/// <<'LDIF'
                #{base_ldif}
                LDIF
                #{verify_cmd}
            SCRIPT

            FileUtils.touch(LDAP_CONFIGURED_MARKER)
            FileUtils.chmod(0o644, LDAP_CONFIGURED_MARKER)
            msg :info, 'OpenLDAP server configured successfully'
        end

        def configure_accounting_ldap
            if ONEAPP_LDAP_ENABLE
                unless ONEAPP_LDAP_URL.to_s.empty?
                    msg :info, 'ONEAPP_LDAP_ENABLE=YES; external LDAP URL inputs are ignored'
                end
                configure_local_ldap
                "ldap://#{accounting_ipv4}"
            elsif ldap_client_enabled?
                stop_local_ldap
                configure_external_ldap_client
                ONEAPP_LDAP_URL
            else
                stop_local_ldap
                stop_sssd
                :clear
            end
        end

        def configure_discovered_ldap(ldap)
            validate_discovered_ldap(ldap)
            if ldap.fetch('url').empty?
                stop_sssd
            else
                apply_sssd_ldap_client(*ldap.values_at('url', 'domain', 'bind_user', 'bind_password'))
            end
        end

        def validate_discovered_ldap(ldap)
            fields = %w[url domain bind_user bind_password]
            unless ldap.is_a?(Hash) && fields.all? { |field| ldap[field].is_a?(String) }
                raise ArgumentError, 'Invalid Accounting LDAP metadata'
            end
            return if fields.all? { |field| ldap[field].empty? }

            if ldap['url'].empty? || ldap['domain'].empty?
                raise ArgumentError, 'Incomplete Accounting LDAP metadata'
            end
            if ldap['url'] =~ %r{//(127\.0\.0\.1|localhost|\[?::1\]?)(:|/|$)}
                raise ArgumentError, 'Accounting LDAP endpoint must be remotely reachable'
            end
        end

        def configure_local_ldap
            msg :info, 'LDAP enabled, configuring Accounting local LDAP'
            install_ldap_server
            setup_ldap_database
            setup_ldap_client
        end

        def stop_local_ldap
            msg :info, 'Ensuring local slapd is stopped'
            bash 'systemctl disable --now slapd 2>/dev/null || true'
        end

        def stop_sssd
            msg :info, 'LDAP identity disabled, ensuring sssd is stopped'
            bash 'systemctl disable --now sssd 2>/dev/null || true'
        end

        def configure_external_ldap_client
            msg :info, 'Configuring Accounting external LDAP client'
            apply_sssd_ldap_client(ONEAPP_LDAP_URL)
            msg :info, 'SSSD external LDAP client configured successfully on Accounting'
        end

        def setup_ldap_client
            msg :info, 'Configuring SSSD LDAP client on Accounting'
            apply_sssd_ldap_client('ldap://127.0.0.1')
            msg :info, 'SSSD LDAP client configured successfully on Accounting'
        end

        def apply_sssd_ldap_client(ldap_uri, domain = ONEAPP_LDAP_DOMAIN,
                                   bind_user = ONEAPP_LDAP_BIND_USER,
                                   bind_password = ONEAPP_LDAP_BIND_PASSWORD)
            base_dn = ldap_base_dn(domain)
            bind_dn = ldap_bind_dn(domain, bind_user)

            bind_lines = ''
            unless bind_dn.empty?
                bind_lines = <<~BIND
                    ldap_default_bind_dn = #{bind_dn}
                    ldap_default_authtok_type = password
                BIND
                bind_lines += "ldap_default_authtok = #{bind_password}\n" unless bind_password.to_s.empty?
            end

            sssd_conf = <<~SSSD
                [sssd]
                services = nss, pam
                config_file_version = 2
                domains = slurm

                [domain/slurm]
                id_provider = ldap
                auth_provider = ldap
                ldap_uri = #{ldap_uri}
                ldap_search_base = #{base_dn}
                ldap_user_search_base = ou=People,#{base_dn}
                ldap_group_search_base = ou=Groups,#{base_dn}
                cache_credentials = True
                enumerate = False
                #{bind_lines}ldap_id_use_start_tls = false
                ldap_tls_reqcert = never
            SSSD

            FileUtils.mkdir_p('/etc/sssd')
            File.write('/etc/sssd/sssd.conf', sssd_conf)
            FileUtils.chmod(0o600, '/etc/sssd/sssd.conf')

            ensure_nsswitch_sss

            bash <<~SCRIPT
                export DEBIAN_FRONTEND=noninteractive
                pam-auth-update --enable mkhomedir
            SCRIPT

            bash 'systemctl enable sssd'
            bash 'systemctl restart sssd'
            bash 'systemctl is-active sssd'
        end

        def verify_ldap_client(ldap_uri, domain, bind_user, bind_password, attempts: 10, delay: 3)
            raise ArgumentError, 'LDAP health check requires positive attempts' unless attempts.is_a?(Integer) && attempts.positive?

            args = ['timeout', '10', 'ldapsearch', '-x', '-H', ldap_uri, '-o', 'nettimeout=5',
                    '-l', '5', '-LLL', '-b', ldap_base_dn(domain), '-s', 'base']
            bind_dn = ldap_bind_dn(domain, bind_user)
            args.concat ['-D', bind_dn, '-w', bind_password] unless bind_dn.empty?
            args.concat ['(objectClass=*)', 'dn']
            attempts.times do |i|
                begin
                    result = bash(args.shelljoin, chomp: true)
                    raise 'LDAP base is unavailable' unless result.match?(/^dn:[: ]/)

                    return nil
                rescue StandardError
                    raise "LDAP client health check failed after #{attempts} attempts", cause: nil if i + 1 == attempts

                    sleep delay
                end
            end
        end

        def ensure_nsswitch_sss
            nsswitch_path = '/etc/nsswitch.conf'
            lines = File.readlines(nsswitch_path)
            databases = %w[passwd group shadow]

            databases.each do |db|
                lines.map! do |line|
                    next line unless line =~ /^#{db}:/

                    fields = line.strip.split(/\s+/)
                    next line if fields.include?('sss')

                    "#{db}:\t#{fields[1..].join(' ')} sss\n"
                end
            end

            File.write(nsswitch_path, lines.join)
        end

    end

end
