require 'socket'

module CLITester

    # methods
    class Host

        include RSpec::Matchers

        PIN_POLICIES = %w[NONE PINNED]

        # Min Libvirt Version for Full Backups
        MLVFL = '5.5'

        # Min Libvirt Version for Incremental Backups
        MLVIC = '7.7'

        attr_accessor :id

        def initialize(id)
            @id = id
            info
        end

        def [](key)
            @xml[key]
        end

        def self.private_ip
            address = ''

            Socket.getifaddrs.each do |addr_info|
                next unless addr_info.addr && addr_info.addr.ipv4? && addr_info.name == 'eth1'

                address = addr_info.addr.ip_address
            end

            address
        end

        def pin_policy(policy)
            return false unless PIN_POLICIES.include?(policy)

            cmd = "onehost update #{@id}"
            tpl = "PIN_POLICY = #{policy}"

            cli_update(cmd, tpl, true)
        end

        def pin
            pin_policy(PIN_POLICIES[1])
        end

        def unpin
            pin_policy(PIN_POLICIES[0])
        end

        def state
            info
            OpenNebula::Host::HOST_STATES[@xml['STATE'].to_i]
        end

        def state?(success_state, break_cond = /FAIL/)
            wait_loop(:success => success_state, :break => break_cond,
                      :resource_ref => @id, :resource_type => self.class) { state }
        end

        def monitored?
            state?('MONITORED')
        end

        def disabled?
            state?('DISABLED')
        end

        def info
            @xml = cli_action_xml("onehost show -x #{@id}")
        end

        def xml(refresh = true)
            info if refresh
            @xml
        end

        def ssh(cmd, stderr = false, options = {}, user = 'root')
            stderr ? stderr = '' : stderr = '2>/dev/null'
            params = ["ssh #{VM_SSH_OPTS} #{user}@#{@xml['NAME']} \"#{cmd}\" #{stderr}"]
            params << options[:timeout]
            params.compact!

            SafeExec.run(*params)
        end

        def ssh_safe(cmd)
            ssh(cmd, false, {}, 'oneadmin')
        end

        def scp(src, dst, stderr = false, options = {}, user = 'root')
            stderr ? stderr = '' : stderr = '2>/dev/null'
            params = ["scp #{src} #{user}@#{@xml['NAME']}:#{dst} #{stderr}"]
            params << options[:timeout]
            params.compact!

            SafeExec.run(*params)
        end

        def libvirt_version
            ssh_safe('/usr/sbin/libvirtd -V').stdout.split(' ')[2]
        end

        def incremental_backups?
            Gem::Version.new(libvirt_version) >= Gem::Version.new(MLVIC)
        end

        def full_backups?
            Gem::Version.new(libvirt_version) >= Gem::Version.new(MLVFL)
        end

    end

end
