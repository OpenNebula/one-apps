# frozen_string_literal: true

require 'securerandom'
require 'ipaddr'
require 'base64'
require_relative 'onegate'
require_relative 'ldap'

module OneSlurm

    # Shared Accounting discovery, SlurmDBD bootstrap and remote client settings.
    module Accounting

        include Ldap

        SLURMDBD_CONF_PATH = '/etc/slurm/slurmdbd.conf'

        def discover_accounting(attempts: 20, delay: 15)
            raise ArgumentError, 'Accounting discovery requires positive attempts' unless attempts.is_a?(Integer) && attempts.positive?

            attempts.times do |i|
                begin
                    vm = role_vm_show('accounting')
                    metadata = vm.dig('VM', 'USER_TEMPLATE') || {}
                    ip = vm_nic_ipv4(vm)
                    raise 'Accounting Service-network IPv4 is missing' if ip.empty? || !IPAddr.new(ip).ipv4? || ip.include?('/')

                    key = metadata['SLURM_MUNGE_KEY']
                    raise 'Accounting key is missing' unless key.is_a?(String) && !key.empty?
                    raise 'Accounting key is empty' if Base64.strict_decode64(key).empty?

                    raise 'Accounting identity metadata is missing' unless %w[LDAP_URL LDAP_DOMAIN].all? { |field| metadata[field].is_a?(String) }

                    ldap = {'url' => metadata['LDAP_URL'], 'domain' => metadata['LDAP_DOMAIN'],
                            'bind_user' => metadata.fetch('LDAP_BIND_USER', ''),
                            'bind_password' => metadata.fetch('LDAP_BIND_PASSWORD', '')}
                    validate_discovered_ldap(ldap)
                    return {'ip' => ip, 'munge_key_b64' => key, 'ldap' => ldap}
                rescue StandardError
                    raise "Accounting discovery failed after #{attempts} attempts", cause: nil if i + 1 == attempts

                    msg :warn, "Accounting metadata unavailable (#{i + 1}/#{attempts}); retrying in #{delay}s"
                    sleep delay
                end
            end
        end

        def slurm_accounting_db_name
            value = ONEAPP_SLURM_ACCOUNTING_DB_NAME.to_s.strip
            value.empty? ? 'slurm_acct_db' : value
        end

        def slurm_accounting_db_user
            value = ONEAPP_SLURM_ACCOUNTING_DB_USER.to_s.strip
            value.empty? ? 'slurm' : value
        end

        def slurmdbd_conf_path
            SLURMDBD_CONF_PATH
        end

        def stored_slurmdbd_password
            return nil unless File.exist?(slurmdbd_conf_path)

            File.readlines(slurmdbd_conf_path).each do |line|
                next unless line.chomp =~ /\A[ \t]*StoragePass=(.*)\z/

                password = Regexp.last_match(1)
                next if password.empty?

                validate_slurmdbd_password(password)
                return password
            end

            nil
        end

        def slurm_accounting_password
            configured = ONEAPP_SLURM_ACCOUNTING_DB_PASSWORD.to_s
            return configured unless configured.empty?

            stored_slurmdbd_password || SecureRandom.base64(32)
        end

        def slurmdbd_conf(password = slurm_accounting_password, accounting_ip:)
            validate_accounting_ipv4(accounting_ip)
            validate_slurmdbd_password(password)
            <<~CONF
                AuthType=auth/munge
                DbdHost=slurm-one-accounting
                DbdAddr=#{accounting_ip}
                DbdPort=6819
                SlurmUser=slurm
                LogFile=/var/log/slurm/slurmdbd.log
                PidFile=/var/run/slurmdbd.pid
                StorageType=accounting_storage/mysql
                StorageHost=localhost
                StorageLoc=#{mysql_identifier(slurm_accounting_db_name)}
                StorageUser=#{mysql_identifier(slurm_accounting_db_user)}
                StoragePass=#{password}
            CONF
        end

        def mysql_identifier(value)
            identifier = value.to_s.strip
            unless identifier.match?(/\A[A-Za-z0-9_]+\z/)
                raise ArgumentError, "Invalid MySQL identifier: #{value}"
            end

            identifier
        end

        def mysql_string(value)
            value.to_s.gsub('\\', '\\\\\\').gsub("'", "\\\\'")
        end

        def slurm_accounting_config(accounting_host:)
            validate_accounting_ipv4(accounting_host)
            <<~CONF
                AccountingStorageType=accounting_storage/slurmdbd
                AccountingStorageHost=#{accounting_host}
                AccountingStoragePort=6819
                JobAcctGatherType=jobacct_gather/cgroup
                JobAcctGatherFrequency=30
            CONF
        end

        def configure_slurm_accounting(accounting_ip:)
            validate_accounting_ipv4(accounting_ip)
            db_name     = mysql_identifier(slurm_accounting_db_name)
            db_user     = mysql_identifier(slurm_accounting_db_user)
            password    = slurm_accounting_password
            validate_slurmdbd_password(password)
            db_password = mysql_string(password)

            bash <<~SCRIPT
                systemctl enable mariadb
                systemctl restart mariadb
                systemctl is-active mariadb
                mysql -uroot <<'SQL'
                CREATE DATABASE IF NOT EXISTS `#{db_name}`;
                CREATE USER IF NOT EXISTS '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}';
                ALTER USER '#{db_user}'@'localhost' IDENTIFIED BY '#{db_password}';
                GRANT ALL PRIVILEGES ON `#{db_name}`.* TO '#{db_user}'@'localhost';
                FLUSH PRIVILEGES;
                SQL
                install -d -o slurm -g slurm -m 0755 /var/log/slurm
            SCRIPT

            write_accounting_config(slurmdbd_conf_path,
                                    slurmdbd_conf(password, accounting_ip: accounting_ip))

            write_accounting_client_config(accounting_ip: accounting_ip)

            bash <<~SCRIPT
                systemctl enable slurmdbd
                systemctl restart slurmdbd
                systemctl is-active slurmdbd
                for _ in $(seq 1 30); do
                    sacctmgr -n show cluster >/dev/null 2>&1 && break
                    sleep 1
                done
                sacctmgr -n show cluster >/dev/null
                sacctmgr -i add cluster one || sacctmgr -n show cluster one | awk '{print $1}' | grep -qx one
                sacctmgr -n show cluster one | awk '{print $1}' | grep -qx one
            SCRIPT
            nil
        end

        def write_accounting_client_config(accounting_ip:)
            conf = <<~CONF
                ClusterName=one
                SlurmctldHost=localhost
                SlurmUser=slurm
                AuthType=auth/munge
                #{slurm_accounting_config(accounting_host: accounting_ip)}
            CONF
            write_accounting_config('/etc/slurm/slurm.conf', conf)
            nil
        end

        def write_accounting_config(path, content)
            previous_umask = File.umask(0o077)
            file path, content, owner: 'slurm', group: 'slurm',
                 mode: 'u=rw,go=', overwrite: true
        ensure
            File.umask(previous_umask) unless previous_umask.nil?
        end

        def validate_accounting_ipv4(value)
            unless value.is_a?(String) && value.match?(/\A[0-9]+(?:\.[0-9]+){3}\z/) && IPAddr.new(value).ipv4?
                raise ArgumentError, 'Accounting requires a valid IPv4 address'
            end
        rescue IPAddr::InvalidAddressError
            raise ArgumentError, 'Accounting requires a valid IPv4 address'
        end

        def validate_slurmdbd_password(password)
            value = password.to_s
            if value.empty? || value.match?(/[#\r\n\x00]/) || value.match?(/\A[[:space:]]|[[:space:]]\z/)
                raise ArgumentError, 'Invalid SlurmDBD password'
            end
        end

    end

end
