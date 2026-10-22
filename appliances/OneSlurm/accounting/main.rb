# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers'
rescue LoadError
    require_relative '../../lib/helpers'
end

require 'shellwords'
require_relative '../common/onegate'
require_relative '../common/ldap'
require_relative '../common/munge'
require_relative '../common/accounting'
require_relative 'config'

module Service

    module SlurmAccounting

        extend self

        include OneSlurm::Ldap
        include OneSlurm::Munge
        include OneSlurm::Accounting

        DEPENDS_ON = []

        def install
            msg :info, 'SlurmAccounting::install'
            bash 'apt update && apt install munge libmunge-dev slurm-client slurm-wlm-basic-plugins slurmdbd slurm-wlm-mysql-plugin mariadb-server ldap-utils sssd sssd-ldap libnss-sss libpam-sss -y'
            install_ldap_server
            msg :info, 'Installation completed successfully'
        end

        def configure
            msg :info, 'SlurmAccounting::configure'
            with_retries { onegate_vm_update ['READY=NO'] }

            ip = accounting_ipv4
            hosts_entry = Shellwords.escape("#{ip}\tslurm-one-accounting")
            bash <<~SCRIPT
                hostnamectl set-hostname slurm-one-accounting
                grep -Fqx -- #{hosts_entry} /etc/hosts || printf '%s\n' #{hosts_entry} >> /etc/hosts
            SCRIPT

            if munge_key_generated?
                unless File.file?(OneSlurm::Munge::MUNGE_KEY_PATH) && File.size?(OneSlurm::Munge::MUNGE_KEY_PATH)
                    raise 'Accounting MUNGE key is missing; restore the original cluster key'
                end
            else
                generate_munge_key
            end
            bash <<~SCRIPT
                systemctl enable munge
                systemctl restart munge
                systemctl is-active munge
                munge -n | unmunge >/dev/null 2>&1
            SCRIPT

            ldap = configure_accounting_ldap
            validate_accounting_identity(ldap)
            configure_slurm_accounting(accounting_ip: ip)
            publish_accounting_coordination(ldap)
            msg :info, 'Configuration completed successfully'
            nil
        end

        def accounting_ipv4
            ip = vm_nic_ipv4(onegate_vm_show)
            validate_accounting_ipv4(ip)
            ip
        end

        def accounting_ldap_metadata(ldap)
            return { 'url' => '', 'domain' => '', 'bind_user' => '', 'bind_password' => '' } if ldap == :clear

            unless ldap.is_a?(String) && !ldap.empty? && !ONEAPP_LDAP_DOMAIN.to_s.strip.empty?
                raise ArgumentError, 'Invalid Accounting LDAP metadata'
            end
            bind_user = ONEAPP_LDAP_BIND_USER.to_s.strip
            metadata = {
                'url' => ldap,
                'domain' => ONEAPP_LDAP_DOMAIN.to_s.strip,
                'bind_user' => bind_user,
                'bind_password' => bind_user.empty? ? '' : ONEAPP_LDAP_BIND_PASSWORD.to_s
            }
            validate_discovered_ldap(metadata)
            metadata
        end

        def validate_accounting_identity(ldap)
            metadata = accounting_ldap_metadata(ldap)
            unless metadata['url'].empty?
                verify_ldap_client(metadata['url'], metadata['domain'],
                                   metadata['bind_user'], metadata['bind_password'])
                bash 'systemctl is-active sssd'
            end

            bash <<~SCRIPT
                getent passwd slurm >/dev/null
                getent group slurm >/dev/null
                getent passwd munge >/dev/null
                getent group munge >/dev/null
                getent passwd mysql >/dev/null
                getent group mysql >/dev/null
            SCRIPT
            if ONEAPP_LDAP_ENABLE
                bash <<~SCRIPT
                    getent passwd openldap >/dev/null
                    getent group openldap >/dev/null
                SCRIPT
            end
            nil
        end

        def publish_accounting_coordination(ldap)
            metadata = accounting_ldap_metadata(ldap)
            key = munge_key_base64
            begin
                raise ArgumentError if Base64.strict_decode64(key).empty?
            rescue ArgumentError
                raise ArgumentError, 'Invalid Accounting MUNGE key'
            end
            with_retries do
                onegate_vm_update [
                    "SLURM_MUNGE_KEY=#{key}",
                    "LDAP_URL=#{metadata['url']}",
                    "LDAP_DOMAIN=#{metadata['domain']}",
                    "LDAP_BIND_USER=#{metadata['bind_user']}",
                    "LDAP_BIND_PASSWORD=#{metadata['bind_password']}"
                ]
            end
            with_retries { onegate_vm_update ['READY=YES'] }
            nil
        end

        def bootstrap
            msg :info, 'SlurmAccounting::bootstrap'
            nil
        end

    end

end
