require 'resolv'

require_relative 'linux/boot_prefix'
require_relative 'linux/common1'
require_relative 'linux/common2'
require_relative 'linux/common3'
require_relative 'linux/context_target'
require_relative 'linux/grow_fs'
require_relative 'linux/hostname'
require_relative 'linux/init_scripts'
require_relative 'linux/ip_method'
require_relative 'linux/netcfg_type'
require_relative 'linux/network'
require_relative 'linux/onesysprep'
require_relative 'linux/password'
require_relative 'linux/sudo'
require_relative 'linux/onegate'

#
# functions
#

def count_ifaces(vm)
    cmd = vm.ssh('ip a')

    ifaces = []
    cmd.stdout.split("\n").each do |line|
        line = line.match(/^[0-9]+:/).to_s
        if !line.empty?
            ifaces.push(line.gsub(/^([0-9]+):.*/, '\\1').to_i)
        end
    end

    ifaces.count
end

def cli_action_wrapper_with_tmpfile(action_string, template = nil, expected_result = true)
    if !template.nil?
        file = Tempfile.new('functionality')
        file << template
        file.flush
        file.close

        action_string += " #{file.path}"
    end

    cmd = cli_action(action_string, expected_result)

    return unless expected_result == false

    return cmd
end

def img_safe_reboot(image)
    rtn = image.include?('alt')

    !rtn
end

# Returns Linux uptime (in seconds) of the managed VM
def linux_uptime
    uptime = nil

    if @info[:vm].ssh('test -f /proc/uptime').success?
        cmd = @info[:vm].ssh('cat /proc/uptime')
        expect(cmd.success?).to be(true)
        uptime = cmd.stdout.strip.split[0].to_f
    else
        # FreeBSD boot time as formatted string with epochtime, e.g.:
        # kern.boottime: { sec = 1572433288, usec = 196752 } Wed Oct 30 11:01:28 2019
        cmd = @info[:vm].ssh('/sbin/sysctl kern.boottime')
        expect(cmd.success?).to be(true)
        boot = cmd.stdout.strip.match(/sec = (\d+),/).captures[0].to_i

        # current epochtime
        cmd = @info[:vm].ssh('date +%s')
        expect(cmd.success?).to be(true)
        time = cmd.stdout.strip.to_i

        uptime = time - boot
    end

    uptime
end

ONEGATE_READY_METHODS = [
    { :method => 'UNIMPORTANT_VAR=UNIMPORTANT_VALUE',       :ready => true }, # regular READY reporting
    { :method => 'READY_SCRIPT="echo simple_ready"',        :ready => true },
    { :method => 'READY_SCRIPT="ZWNobyBzaW1wbGVfcmVhZHkK"', :ready => true },
    { :method => 'READY_SCRIPT="asdf"',                     :ready => false },
    { :method => 'READY_SCRIPT_PATH="/bin/echo"',           :ready => true },
    { :method => 'READY_SCRIPT_PATH="asdf"',                :ready => false }
]

defaults = RSpec.configuration.defaults

#
# examples
#

shared_examples_for 'context_linux' do |image, hv, prefix, context, image_size = nil|
    include_examples 'context', image, hv, prefix, context, image_size

    it 'ssh (required)' do
        @info[:vm].wait_ping
        @info[:vm].reachable?
    end

    if description == 'common (1)' && hv != 'VCENTER'
        it 'boots under 60 seconds' do
            boot_time = Time.now.to_i - @info[:vm_stime]
            STDERR.puts "BOOT_TIME (#{image}) - #{boot_time}"
            expect(boot_time).to be > 0
            expect(boot_time).to be < 60, "Too slow boot (#{boot_time}s)"
        end
    end

    it 'contextualized' do
        # wait for variables for after-network contextualization to be ready
        wait_loop do
            cmd = @info[:vm].ssh('test -f /var/run/one-context/context.sh.network')
            cmd.success?
        end

        # wait for any contextualization to finish
        wait_loop do
            cmd = @info[:vm].ssh('test -e /var/run/one-context/one-context.lock')
            cmd.fail?
        end
    end
end

#####

shared_examples_for 'linux' do |name, hv|
    hv == 'VCENTER' ? (prefix = 'sd') : (prefix = 'vd')

    context 'common (1)' do
        include_examples 'context_linux_common1', name, hv, prefix
    end

    ONEGATE_READY_METHODS.each do |ready_method|
        context 'onegate' do
            include_examples 'onegate_linux', name, hv, prefix, ready_method
        end
    end

    context 'common (2)' do
        include_examples 'context_linux_common2', name, hv, prefix
    end

    context 'common (3)' do
        include_examples 'context_linux_common3', name, hv, prefix
    end

    unless ['LXD', 'LXC'].include? hv
        context 'filesystem growing' do
            include_examples 'context_linux_grow_fs', name, hv, prefix
        end
    end

    # these tests will run only on KVM
    if hv == 'KVM'
        if defaults[:tests][name].key?(:dev_prefixes)
            prefixes = defaults[:tests][name][:dev_prefixes]
        else
            prefixes = ['hd', 'vd', 'sd']
        end

        prefixes.each do |pref|
            context "with boot disk on #{pref}" do
                include_examples 'context_linux_boot_prefix',
                                 name,
                                 hv,
                                 pref
            end
        end

        # NOTE: vdb/virtio is not supported in recent KVM/QEMUs
        # error: unsupported configuration: disk type of 'vdb' does not support ejectable media
        ['hda', 'sda'].each do |target|
            context "with context disk on #{target}" do
                include_examples 'context_linux_context_target', name, hv, 'vd', target
            end
        end
    end

    ['root', 'non-root'].each do |user|
        passwd = '6be4AO@ld'

        params = [
            ['PASSWORD', passwd, passwd],
            ['PASSWORD_BASE64', Base64.encode64(passwd), passwd],
            ['CRYPTED_PASSWORD', passwd.crypt('salt'), passwd],
            ['CRYPTED_PASSWORD_BASE64', Base64.encode64(passwd.crypt('salt')), passwd]
        ]

        params.each do |p|
            context "context #{user} user #{p[0]}" do
                include_examples 'context_linux_password', name, hv, prefix, user, *p
            end
        end
    end

    context 'context non-root user without sudo' do
        include_examples 'context_linux_nosudo', name, hv, prefix, 'non-root'
    end

    context 'context non-root user' do
        include_examples 'context_linux_sudo', name, hv, prefix, 'non-root'
    end

    ###### Temporarily disable following tests for LXD
    if hv == 'KVM'
        ['myh', 'myh.', 'myh.myd.tld', 'myh.sub.myd.tld'].each do |hostname|
            context "context hostname SET_HOSTNAME=#{hostname}" do
                include_examples 'context_linux_set_hostname', name, hv, 'vd', hostname
            end
        end
    end

    context 'context hostname EC2_HOSTNAME=yes' do
        include_examples 'context_linux_ec2_hostname', name, hv, prefix
    end

    context 'context hostname DNS_HOSTNAME=yes' do
        include_examples 'context_linux_dns_hostname', name, hv, prefix
    end

    context 'context INIT_SCRIPT prepare' do
        include_examples 'context_linux_prepare_init_scripts', name, hv, prefix
    end

    context 'context INIT_SCRIPTS' do
        include_examples 'context_linux_init_scripts', name, hv, prefix
    end

    # TODO: test with qcow2 caching enabled
    # onesysprep disk zeroing breaks the host
    # https://github.com/OpenNebula/one/issues/5582
    if hv != 'LXD'
        context 'onesysprep' do
            include_examples 'context_linux_onesysprep', name, hv, prefix
        end
    end

    if hv == 'KVM'
        # Description of each distribution image (matching :distro RE), with
        # default network configuration renderer (:netcfg_type_default) and
        # other non-default rendrers to test (:netcfg_types).
        # IMPORTANT: Data must be in sync with capabilities of each image!!!
        distro_netcfg = [
            {
                :distro => /^alpine/i,
                :netcfg_type_default => 'interfaces'
            },
            {
                :distro => /^amazon2$/i,
                :netcfg_type_default => 'scripts'
            },
            {
                :distro => /^(centos|ol|rhel)[67]$/i,
                :netcfg_type_default => 'nm'
            },
            {
                :distro => /^(alma|centos|ol|rhel|rocky|springdale)[89]/i,
                :netcfg_types => ['nm', 'networkd'],
                :netcfg_type_default => 'nm'
            },
            {
                :distro => /^alt/i,
                :netcfg_types => ['nm'],
                :netcfg_type_default => 'networkd'
            },
            {
                :distro => /^fedora/i,
                :netcfg_types => ['nm', 'networkd'],
                :netcfg_type_default => 'nm'
            },
            {
                :distro => /^opensuse/i,
                :netcfg_type_default => 'scripts'
            },
            {
                :distro => /^debian9$/i,
                :netcfg_type_default => 'interfaces'
            },
            {
                :distro => /^debian1/i,
                :netcfg_types => ['netplan', ['netplan', 'NetworkManager'], 'nm', 'networkd'],
                :netcfg_type_default => 'interfaces'
            },
            {
                :distro => /^devuan/i,
                :netcfg_type_default => 'interfaces'
            },
            {
                :distro => /^ubuntu\d+/i,
                :netcfg_types => ['netplan', ['netplan', 'NetworkManager'], 'nm', 'networkd'],
                :netcfg_type_default => 'netplan'
            },
            {
                :distro => /^freebsd/i,
                :netcfg_type_default => 'bsd'
            }
        ]

        if defaults && defaults.key?(:tests) && defaults[:tests][name]
            distro_netcfg.each do |c|
                next unless name.match(c[:distro])

                # prepare list of netcfg_types to test
                netcfg_types = c[:netcfg_types]
                netcfg_types ||= []
                netcfg_types.insert(0, '') # always use a default (unspecified) renderer
                netcfg_types.uniq!

                netcfg_types.each do |netcfg_type, netcfg_netplan_renderer|
                    test_name = "network renderer #{netcfg_type}"
                    test_name << 'default' if netcfg_type.empty?
                    test_name << "(#{netcfg_netplan_renderer})" if netcfg_netplan_renderer

                    context "#{test_name}" do
                        if netcfg_type != '' && defaults[:tests][name][:enable_netcfg_common]
                            context 'common' do
                                include_examples 'context_linux_network_netcfg_type_common',
                                                 name, hv, prefix, nil,
                                                 netcfg_type, netcfg_netplan_renderer,
                                                 c[:netcfg_type_default]
                            end
                        end

                        if defaults[:tests][name][:enable_netcfg_ip_methods]
                            context 'IP configuration' do
                                include_examples 'context_linux_ip_methods',
                                                 name, hv, prefix, nil,
                                                 netcfg_type, netcfg_netplan_renderer,
                                                 c[:netcfg_type_default]
                            end
                        end
                    end
                end

                break
            end
        end
    end

    # spare a disk space and avoid orphans across different test runs
    # on vCenter by deleting an image after image testing is finished
    if hv == 'VCENTER'
        context "delete image #{name}" do
            it "delete image #{name}" do
                cli_action("oneimage delete '#{name}' >/dev/null", nil)

                wait_loop do
                    cmd = cli_action("oneimage show '#{name}'", nil)
                    !cmd.success?
                end
            end
        end
    end
end
