require 'tempfile'

module CLITester

    # TODO: Inherit from OneObject
    class VM

        include RSpec::Matchers

        attr_accessor :id, :ip, :backup_ds_id

        def initialize(id)
            @id = id
            @defaults = RSpec.configuration.defaults

            info
            get_ip
        end

        def [](key)
            @xml[key]
        end

        #
        # Instantiates a VM template and validates VM RUNNING status
        #
        # @param [String] template VM Template name or ID
        # @param [Bool] ssh Validate VM SSH access from the FE
        # @param [String] CLI options
        #
        # @return [CLITester::VM]
        #
        def self.instantiate(template, ssh = false, options = '')
            cmd = "onetemplate instantiate #{template} #{options}"
            deploy(cmd, ssh)
        end

        #
        # Creates VM with infra resources and validates VM RUNNING status
        #
        # @param [String] desired VM name
        # @param [String] options custom CLI options
        # @param [Bool] ssh Validate VM SSH access from the FE
        #
        # @return [CLITester::VM]
        #
        def self.create(name, options = '', ssh = false)
            cmd = "onevm create --name #{name} #{options}"
            deploy(cmd, ssh)
        end

        def self.deploy(cmd, ssh = false)
            id = cli_create_lite(cmd)

            vm = new(id)
            vm.running?
            vm.reachable? if ssh

            vm
        end

        def state
            info
            state     = VirtualMachine::VM_STATE[@xml['STATE'].to_i]
            lcm_state = VirtualMachine::LCM_STATE[@xml['LCM_STATE'].to_i]
            state == 'ACTIVE' ? lcm_state : state
        end

        def state?(success_state, break_cond = /FAIL/, options = {})
            args = {
                :success => success_state,
                :break => break_cond,
                :resource_ref => @id,
                :resource_type => self.class
            }.merge!(options)
            wait_loop(args) { state }
        end

        def running?(options = {})
            state?('RUNNING', /FAIL/, options)
        end

        def pending?(options = {})
            state?('PENDING', /FAIL/, options)
        end

        def backing_up?(status_previous)
            if status_previous == 'POWEROFF'
                state?('BACKUP_POWEROFF')
            else
                state?('BACKUP')
            end
        end

        def flatten_inactive?(timeout = 60)
            wait_loop(:success => false,
                      :break => nil,
                      :timeout => timeout,
                      :resource_ref => self.class) do
                info
                backup_config['ACTIVE_FLATTEN'] == 'YES'
            end
        end

        def stopped?
            state?('POWEROFF')
        end

        alias poweroff? stopped?

        def failed?
            state?('FAILURE')
        end

        def done?(options = {})
            state?('DONE', /FAIL/, options)
        end

        def undeployed?
            state?('UNDEPLOYED')
        end

        def reachable?(user = 'root', timeout = DEFAULT_TIMEOUT, ssh_timeout = 11)
            options = {}
            options[:timeout] = timeout
            options[:resource_ref] = @id
            options[:resource_type] = self.class

            wait_loop(options) do
                cmd = ssh('echo', true, { :timeout => ssh_timeout, :quiet => true }, user)
                get_ip
                cmd.success?
            end
        end

        def ready?(success = 'YES')
            wait_loop(:timeout => 30) do
                expect(xml['USER_TEMPLATE/READY']).to eq(success)
            end
        end

        def wait_ping(ip = @ip)
            err = 'wait_ping: Missing IP to ping'
            expect(ip).not_to be_nil, err
            expect(ip).not_to be_empty, err

            wait_loop do
                system("ping -q -W1 -c1 #{ip} >/dev/null")
            end
        end

        def wait_no_ping(ip = @ip)
            err = 'wait_no_ping: Missing IP to ping'
            expect(ip).not_to be_nil, err
            expect(ip).not_to be_empty, err

            wait_loop do
                !system("ping -q -W1 -c1 #{ip} >/dev/null")
            end
        end

        def wait_context
            wait_loop do
                ssh('test -f /var/run/one-context/context.sh.network').success?
            end

            wait_loop do
                ssh('test -e /var/run/one-context/one-context.lock').fail?
            end
        end

        def info
            @xml = cli_action_xml("onevm show -x #{@id}")
        end

        def xml(refresh = true)
            info if refresh
            @xml
        end

        def get_ip
            @ip = @xml["#{@defaults[:xpath_pub_nic]}/IP"]
        end

        def get_vlan_ip
            @ip = @xml["#{@defaults[:xpath_vlan_nic]}/IP"]
        end

        def sequences
            xml['HISTORY_RECORDS/HISTORY[last()]/SEQ'].to_i
        end

        # TODO: Call xml instead of @xml for these helpers to get an up to date VM Template.
        # This might cause unwanted effects in already existing tests but is worth noting that calling @xml will
        # not necessarily yield an up to date VM XML entry. An explicit info call is necessary.

        def hostname
            @xml['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']
        end

        alias host hostname

        def host_id
            @xml['HISTORY_RECORDS/HISTORY[last()]/HID']
        end

        def cluster_id
            @xml['HISTORY_RECORDS/HISTORY[last()]/CID']
        end

        def vnet_id(nic_id)
            @xml["TEMPLATE/NIC[NIC_ID=\"#{nic_id}\"]/NETWORK_ID"]
        end

        def stime
            @xml['HISTORY_RECORDS/HISTORY[last()]/STIME']
        end

        def backup_config
            @xml.retrieve_xmlelements('BACKUPS/BACKUP_CONFIG')[0]
        end

        def backup_ids
            info

            ids = @xml.retrieve_elements('BACKUPS/BACKUP_IDS/ID')

            return [] if ids.nil?

            ids
        end

        def backup_id(index = -1)
            backup_ids[index]
        end

        def disks
            @xml.retrieve_xmlelements('TEMPLATE/DISK')
        end

        def nic_ids
            ids = []

            @xml.retrieve_xmlelements('TEMPLATE/NIC/NIC_ID').each do |nic_xml|
                ids << nic_xml['//NIC_ID']
            end

            ids
        end

        def networking?
            !nic_ids.nil?
        end

        def file_write(path = '/var/tmp/asdf', content = 'asdf')
            cmds = []
            cmds << "echo '#{content}' > #{path}"
            cmds << 'sync' # actually necesary or file being written is a coinflip
            cmds << "cat #{path} "

            cmds.each do |c|
                ssh(c)
            end

            host = Host.new host_id
            host.ssh('sync')

            `sync` # sync the front-end (e.g. shared FS, and Backup repo)
        end

        def file_check_contents(path, contents)
            cmd = ssh("cat #{path}")

            cmd.expect_success

            expect(cmd.stdout.strip).to eq contents.strip
        end

        def file_check(path = '/var/tmp/asdf', expect_success = true)
            cmd = ssh("cat #{path}")

            if expect_success
                cmd.expect_success
            else
                cmd.expect_fail
            end
        end

        def debug_ssh_cmd(dcmd)
            cmd = ssh(dcmd)

            pp "stdout: #{cmd.stdout}"
            pp "status: #{cmd.exitstatus}"
            pp "stderr: #{cmd.stdout}"

            expect(cmd.success?).to be(true)
        end

        def routes
            case os_type
            # default via 172.20.0.1 dev eth0 proto static
            # 169.254.16.9 dev eth0 scope link
            # 172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
            # 172.20.0.0/16 dev eth0 proto kernel scope link src 172.20.7.16
            # 192.168.110.0/24 dev br1 proto kernel scope link src 192.168.110.1 metric 425 linkdown
            # 192.168.150.0/24 dev br0 proto kernel scope link src 192.168.150.1 metric 426
            when 'Linux'
                ssh('ip r').stdout.chomp
            # TODO: Update parsing for BSD to match Linux
            # Destination        Gateway            Flags     Netif Expire
            # default            192.168.150.1      UGS      vtnet0
            # 127.0.0.1          link#2             UH          lo0
            # 192.168.150.0/24   link#1             U        vtnet0
            # 192.168.150.100    link#1             UHS         lo0
            when 'FreeBSD'
                ssh('netstat -rn -f inet | tail -n +4').stdout.chomp
            else
                STDERR.puts "OS type: #{os_type} not known"
                nil
            end
        end

        def os_type
            ssh('uname').stdout.chomp
        end

        # rubocop:disable Metrics/ParameterLists
        def ssh(cmd, _stderr = false, options = {}, user = 'root', xpath_ip = '')
            # stderr ? stderr = '' : stderr = '2>/dev/null'
            xpath_ip.empty? ? ip = @ip : ip = @xml[xpath_ip]
            # params = ["ssh #{VM_SSH_OPTS} #{user}@#{ip} \"#{cmd}\" #{stderr}"]
            params = ["ssh #{VM_SSH_OPTS} #{user}@#{ip} \"#{cmd}\""]
            params << options[:timeout]
            params << 1 # one try
            params << options[:quiet]

            SafeExec.run(*params)
        end

        # Method enforces the SSH control master (possibly configured via
        # VM_SSH_OPTS) for particular host to stop and close connection.
        def ssh_stop_control_master(stderr = false, options = {}, user = 'root', xpath_ip = '')
            stderr ? stderr = '' : stderr = '2>/dev/null'
            xpath_ip.empty? ? ip = @ip : ip = @xml[xpath_ip]
            params = ["ssh #{VM_SSH_OPTS} -O stop #{user}@#{ip} #{stderr}"]
            params << options[:timeout]
            params.compact!

            SafeExec.run(*params)
        end

        def scp(src, dst, stderr = false, options = {}, user = 'root', xpath_ip = '')
            stderr ? stderr = '' : stderr = '2>/dev/null'
            xpath_ip.empty? ? ip = @ip : ip = @xml[xpath_ip]
            params = ["scp #{VM_SSH_OPTS} #{src} #{user}@#{ip}:#{dst} #{stderr}"]
            params << options[:timeout]
            params.compact!

            SafeExec.run(*params)
        end
        # rubocop:enable Metrics/ParameterLists

        def resume
            cli_action("onevm resume #{@id}")
            running?
        end

        def safe_poweroff
            cli_action("onevm poweroff #{@id}")

            # just in case the VM has no ACPI...
            ssh("PATH=#{DEFAULT_PATH} poweroff") if @defaults[:emulate_acpi]

            state?('POWEROFF')
        end

        alias poweroff safe_poweroff

        def poweroff_hard
            cli_action("onevm poweroff --hard #{@id}")
            stopped?
        end

        def backup(datastore = @backup_ds_id, options = {})
            opts = { :args => '', :wait => true }.merge!(options)

            status = state

            if datastore.nil?
                cli_action("onevm backup #{@id} #{opts[:args]}")
            else
                cli_action("onevm backup #{@id} -d #{datastore} #{opts[:args]}")
            end

            return unless opts[:wait]

            backing_up?(status)
            state?(status)

            info
            backup_id
        end

        def backup_cancel(status_previous = nil, options = {})
            opts = { :args => '' }.merge!(options)

            status_previous = state if status_previous.nil?

            backing_up?(status_previous)

            wait_loop(:success => status_previous,
                      :resource_ref => @id,
                      :resource_type => self.class) do
                status = state
                if ['BACKUP', 'BACKUP_POWEROFF'].include?(status)
                    cli_action("onevm backup-cancel #{@id} #{opts[:args]}", nil, true)
                end
                status
            end
        end

        def backup_fail(datastore = @backup_ds_id, options = {})
            opts = { :args => '' }.merge!(options)
            cli_action("onevm backup #{@id} -d #{datastore} #{opts[:args]}", false)
        end

        def backups?
            !backup_ids.empty?
        end

        def set_backup_mode(mode, keep_last = nil, imode = nil)
            bkp_cfg = []
            bkp_cfg << %(MODE="#{mode}")
            bkp_cfg << %(KEEP_LAST="#{keep_last}") unless keep_last.nil?
            bkp_cfg << %(INCREMENT_MODE="#{imode}") unless imode.nil?

            updateconf %(BACKUP_CONFIG = [#{bkp_cfg.join(',')}])
        end

        def updateconf(template_str, options = '')
            file = Tempfile.new('vm_conf')
            file.write(template_str)
            file.close

            cmd = "onevm updateconf #{@id} #{file.path} #{options}"
            cli_action(cmd)

            file.unlink

            @xml
        end

        def update(template, append = false)
            cmd = "echo #{template} | onevm update #{@id}"
            cmd << ' -a' if append
            cli_action(cmd)
        end

        def recontextualize(context_param)
            context_template = "CONTEXT=[ #{context_param} ]"

            if state == 'RUNNING'
                was_running = true
                cmd1 = ssh('stat -c "%Y" /var/run/one-context/context.sh.network')
                cmd1.success?
            end

            updateconf(context_template, '-a')

            return unless was_running

            # wait context.sh.network is newer now -> context started
            wait_loop do
                cmd2 = ssh('stat -c "%Y" /var/run/one-context/context.sh.network')
                cmd2.stdout.to_i > cmd1.stdout.to_i
            end

            wait_context
        end

        def safe_undeploy
            cli_action("onevm undeploy #{@id}")

            # just in case the VM has no ACPI...
            ssh("PATH=#{DEFAULT_PATH} poweroff") if @defaults[:emulate_acpi]

            state?('UNDEPLOYED')
        end

        def resched_running
            cli_action("onevm resched #{@id}")
            state?('RUNNING')
        end

        def resched
            verify_action("onevm resched #{@id}")
        end

        alias undeploy safe_undeploy

        def undeploy_hard
            cli_action("onevm undeploy --hard #{@id}")
            undeployed?
        end

        def safe_reboot
            cli_action("onevm reboot #{@id}")

            # just in case the VM has no ACPI...
            ssh("PATH=#{DEFAULT_PATH} reboot") if @defaults[:emulate_acpi]

            state?('RUNNING')
        end

        def hard_reboot
            cli_action("onevm reboot --hard #{@id}")

            state?('RUNNING')
        end

        alias reboot safe_reboot

        def halt
            ssh("PATH=#{DEFAULT_PATH} halt")
            sleep 10
        end

        def terminate(options = {})
            cli_action("onevm terminate #{@id}")
            state?('DONE', /FAIL/, options)
        end

        def terminate_hard
            cli_action("onevm terminate --hard #{@id}")
            state?('DONE')
        end

        def migrate_live(host_next = nil)
            running?
            migrate(host_next, '--live')
        end

        def migrate(host_next = nil, options = '')
            if !host_next
                all_hosts = cli_action_json('onehost list -j')
                all_ids   = all_hosts.dig('HOST_POOL', 'HOST').map {|h| h['ID'].to_i }
                host_next = (all_ids - [host_id.to_i]).first
            end

            pp "migrate to host: #{host_next}"

            verify_action("onevm migrate #{@id} #{host_next} #{options}")
        end

        def nic_attach(net_id, options = {})
            status = state

            cmd = "onevm nic-attach #{@id} --network #{net_id} " \
                      "#{options.map {|k, v| "--#{k} #{v}" }.join(' ')}"

            cli_action(cmd)

            state?(status)
        end

        def nic_detach(nic_id)
            status = state

            cmd = "onevm nic-detach #{@id} #{nic_id}"
            cli_action(cmd)

            state?(status)
        end

        def disk_attach(img_id, options = {})
            status = state

            cmd = "onevm disk-attach #{@id} --image #{img_id} " \
                      "#{options.map {|k, v| "--#{k} #{v}" }.join(' ')}"

            cli_action(cmd)

            state?(status)
        end

        def disk_detach(disk_id)
            status = state

            cmd = "onevm disk-detach #{@id} #{disk_id}"
            cli_action(cmd)

            state?(status)
        end

        def disk_snapshot_create(id_disk, name_snap, options = '')
            cmd = "onevm disk-snapshot-create #{@id} #{id_disk} #{name_snap} #{options}"
            verify_action(cmd)
        end

        def snapshot_create(options = '')
            verify_action("onevm snapshot-create #{@id} #{options}")
        end

        def snapshot_delete(snap_id, options = '')
            verify_action("onevm snapshot-delete #{@id} #{snap_id} #{options}")
        end

        def vmware_tools_running?
            wait_loop do
                info
                @xml['MONITORING/VCENTER_VMWARETOOLS_RUNNING_STATUS'] == 'guestToolsRunning'
            end
        end

        def wait_monitoring_info(att)
            wait_loop do
                info
                if !(ip = @xml["MONITORING/#{att}"]).nil?
                    return ip
                end
            end
        end

        # execute remote command on a windows VM using openssh
        def winrm(command, user = 'oneadmin')
            cmd = ssh(command, false, {}, user, '')

            o = cmd.stdout.chomp
            e = cmd.stderr.chomp
            s = cmd.success?

            lines = []

            # remove windows stinky \r\n on each line
            o.lines.each do |l|
                lines << l.chomp
            end

            o = lines.join("\n")
            lines = []

            # remove windows stinky \r\n on each line
            e.lines.each do |l|
                lines << l.chomp
            end

            e = lines.join("\n")

            if s == false
                pp command
                pp o
                pp e
            end

            [o, e, s]
        end

        def powershell(command, user = 'oneadmin')
            winrm("powershell -Command \\\"#{command}\\\"", user)
        end

        def clear_ready
            Tempfile.open('tmpl') do |tmpl|
                tmpl << 'READY=""'
                tmpl.close

                cli_action("onevm update --append #{@id} #{tmpl.path}")
            end
        end

        def instance_name
            "one-#{@id}"
        end

        alias name instance_name

        private

        #
        # Checks if the initial VM state is restored after performing certain VM action
        #
        # @param [Proc] action VM action code: cli_action("onevm terminate --hard #{@id}")
        #
        # @return [Bool] True if status after performing action is the same as the inital status
        #
        def verify_state(action)
            raise "Expected #{Proc} type object, not #{action.class}" if action.class != Proc

            info

            state     = VirtualMachine::VM_STATE[@xml['STATE'].to_i]
            lcm_state = VirtualMachine::LCM_STATE[@xml['LCM_STATE'].to_i]

            action.call

            wait_loop(
                :break => /FAIL/,
                :resource_ref => @id,
                :resource_type => self.class
            ) do
                info

                cstate     = VirtualMachine::VM_STATE[@xml['STATE'].to_i]
                clcm_state = VirtualMachine::LCM_STATE[@xml['LCM_STATE'].to_i]

                cstate == state && clcm_state == lcm_state
            end
        end

        #
        # Wrapper for verify state, intented for an individual action
        #
        # @param [String] cmd opennebula command to be run
        #
        # @return [Bool] True if the previous state is returned to
        #
        def verify_action(cmd)
            action = proc { cli_action(cmd) }
            verify_state(action)
        end

    end

end
