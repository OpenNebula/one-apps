$LOAD_PATH.unshift File.dirname(__FILE__)

class ContainerHost

    CACHE_MODES = [
        nil, # no cache is used. fake mode
        'custom_str', # non-suntone selectable mode. driver ignores this
        'default', # driver ignores this mode not adding --cache to qemu-nbd
        'none',
        'writethrough',
        'writeback',
        'directsync',
        'unsafe'
    ]

    # host is CLITester::Host
    def initialize(hostname)
        @hostname = hostname
    end

    def self.new_host(host)
        xml = host.info
        hostname = xml['NAME']
        hypervisor = xml['VM_MAD']

        case hypervisor
        when 'lxc'
            LXCHost.new(hostname)
        when 'lxd'
            LXDHost.new(hostname)
        end
    end

    def run(cmd)
        SafeExec.run("ssh #{@hostname} #{cmd}")
    end

    # Executes command inside container
    def container_exec(_cmd, _container)
        STDERR.puts 'implement in child class'
        exit 1
    end

    def cache_mode?(vm_id, mode)
        cmd = run('ps -fC qemu-nbd')
        procs = cmd.stdout.split("\n")[1..-1]

        # qemu-nbd --cache=none --fork -c /dev/nbd0 #{mountpoint}"
        procs.each do |proc|
            proc_info = proc.split(' ')
            mountpoint = "/var/lib/one/datastores/0/#{vm_id}/disk.0"

            next unless proc_info.include?(mountpoint)

            case mode
            when CACHE_MODES[0], CACHE_MODES[1], CACHE_MODES[2]
                return true unless proc_info.grep(/--cache=/).any?
            else
                return true if proc_info.include?("--cache=#{mode}")
            end
        end

        false
    end

    private

    def vm_id(container_name)
        container_name.split('-').last
    end

    def container_name(vm_id)
        "one-#{vm_id}"
    end

end

class LXCHost < ContainerHost

    attr_accessor :mounts

    # LXC CLI Commands
    COMMANDS = {
        :attach     => 'sudo lxc-attach',
        :config     => 'sudo lxc-config',
        :console    => 'sudo lxc-console',
        :create     => 'sudo lxc-create',
        :destroy    => 'sudo lxc-destroy',
        :info       => 'sudo lxc-info',
        :execute    => 'sudo lxc-execute',
        :ls         => 'sudo lxc-ls',
        :start      => 'sudo lxc-start',
        :stop       => 'sudo lxc-stop'
    }

    def container_exec(os_cmd, container)
        cmd = "#{COMMANDS[:attach]} -n #{container} -- #{os_cmd}"
        run(cmd)
    end

    def container_conf(container)
        path = "/var/lib/one/datastores/0/#{vm_id(container)}/deployment.file"

        run("cat #{path}").stdout.split("\n")
    end

    ##################################################################
    # mount options
    ##################################################################

    def container_mounts(container)
        vm_id = vm_id(container)

        container_mounts = {
            :bindfs => [],
            :mapper => [],
            :guest => []
        }

        processes = run('mount').stdout.split("\n").select! do |k|
            k.include?("/var/lib/lxc-one/#{vm_id}")
        end

        processes.each do |process|
            container_mounts[:bindfs] << mount_info(process)
        end

        processes = run('mount').stdout.split("\n").select! do |k|
            # k.include?("/var/lib/one/datastores/0/#{vm_id}")
            k.include?("/var/lib/one/datastores/0/#{vm_id}") && k.include?('/dev/')
        end

        processes.each do |process|
            container_mounts[:mapper] << mount_info(process)
        end

        processes = container_exec('mount',
                                   container).stdout.split("\n").select! do |k|
            k.include?("/var/lib/one/datastores/0/#{vm_id}")
        end

        processes.each do |process|
            container_mounts[:guest] << mount_info(process)
        end

        @mounts = {}
        @mounts[container] = container_mounts
    end

    def ro_disk?(container, disk_id)
        mount_has_opt?(container, disk_id, :guest, 'ro')
    end

    def path_okay?(container, disk_id, mountpoint)
        @mounts[container][:guest][disk_id][:target] == mountpoint
    end

    def mount_has_opt?(container, disk_id, type, option)
        type = type.to_sym if type.class == String

        @mounts[container][type][disk_id][:options].include?(option)
    end

    ##################################################################
    # idmap
    ##################################################################

    def privileged?(container)
        cmd = run("#{COMMANDS[:info]} -n #{container} -c lxc.idmap")

        return unless cmd.success?

        cmd.stdout.chomp == 'lxc.idmap ='
    end

    def shift_okay?(container)
        cmd = container_exec('ls -la /root/.bashrc', container)

        return false unless cmd.success?

        # => "-rw-r--r-- 1 root root 570 Jan 31  2010 /root/.bashrc\n"
        cmd.stdout.split(' ')[2] == 'root'
    end

    private

    def mount_info(process)
        process = process.split(' ')

        options = process.last
        ['(', ')'].each {|char| options.delete!(char) }
        options = options.split(',')

        {
            # /var/lib/one/datastores/0/37/mapper/disk.0
            :source => process[0],
            # /var/lib/lxc-one/37/disk.0
            :target => process[2],
            # [rw nodev relatime user_id=0 group_id=0 default_permissions allow_other]
            :options => options
        }
    end

end

class LXDHost < ContainerHost

    SNAP_PATH = '/snap/bin/'

    def initialize(host)
        super(host)

        snapd?
    end

    def container_exec(os_cmd, container)
        cmd = "lxc exec #{container} -- #{os_cmd}"
        run(cmd)
    end

    def run(cmd)
        snap_prepend?(cmd)
        super(cmd)
    end

    private

    def snap_prepend?(cmd)
        cmd.prepend "sudo -S #{SNAP_PATH}" if ['lxc ',
                                               'lxd '].include?(cmd[0..3]) && @snap
    end

    def snapd?
        cmd = run('command -v snap')

        if cmd.status.zero?
            @snap = true
        else
            @snap = false
        end
    end

end
