require 'date'
require 'fileutils'
require 'one-open-uri'
require 'tempfile'
require 'yaml'

require_relative 'aws/cleanup'
require_relative 'schedule_today'

# List of providers that use port forwarding
NODE_PORT_PROVIDERS = %w[digitalocean google]

# List of providers that does not support BGP
NO_BGP = %w[vultr_metal]

# 'onevm ssh' default options
SSH_OPTIONS = '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# MarketPlace appliance to use
APPLIANCE = 'Debian 11'

# List of VMs that should be created
VMS = [:vm1, :vm2, :vm3]

# Check if list is empty
def empty?
    cli_action('oneprovision list --no-header').stdout.empty?
end

# Count number of resources
#
# @param type [String] Resources type to count
def count_elements(type)
    cli_action(
        "oneprovision #{type} list --csv --no-header"
    ).stdout.split("\n").size
end

# Get specific element from provision
#
# @param provision [Hash]    Provision information
# @param type      [String]  infrastructure/resource
# @param object    [String]  Specific object type
# @param index     [Integer] Element to get
def element(provision, type, object, index = 0)
    provision['DOCUMENT']['TEMPLATE']['BODY']['provision'][type][object][index]
end

# Load YAML file
#
# @param path [String] Path to YAML file
def load_yaml(path)
    begin
        YAML.safe_load(File.read(path))
    rescue StandardError => e
        raise "Unable to read '#{path}'. Invalid YAML syntax:\n" + e.message
    end
end

# Get current absolute path
#
# @param name [String] File name
def path(name)
    File.realpath(File.join(File.dirname(__FILE__), name))
end

RSpec.shared_examples_for 'provision_hci' do |hypervisor,
                                          instance_type,
                                          provider_path,
                                          inputs|
    before(:all) do
        unless File.exist?(provider_path)
            raise "Provider #{provider_path} does not exists"
        end

        if %w[firecracker lxc].include?(hypervisor)
            @live = false
        else
            @live = true
        end

        $provider = load_yaml(provider_path)
        p_def     = load_yaml(path("#{$provider['provider']}/defaults.yaml"))
        schedule  = load_yaml(path('schedule.yaml'))[schedule_today]

        unless schedule.include?($provider['provider'])
            $continue = 'skip'
            skip "No #{$provider['provider']} tests today"
        end

        credentials = YAML.safe_load(
            URI.parse(p_def['credentials_url']).open.read
        )

        @node   = true if NODE_PORT_PROVIDERS.include?($provider['provider'])
        @no_bgp = true if NO_BGP.include?($provider['provider'])

        ########################################################################
        # Get provision definition path
        ########################################################################

        @provision_path = '/usr/share/one/oneprovision/edge-clusters/' \
                          "#{instance_type}/provisions/"

        if %w[vultr_virtual vultr_metal].include?($provider['provider'])
            yaml = 'vultr'
        else
            yaml = $provider['provider']
        end

        @provision_path << "#{yaml}-hci.yml"

        ########################################################################
        # Credentials
        ########################################################################

        case $provider['provider']
        when 'aws'
            $provider['connection']['access_key'] = credentials['aws_access']
            $provider['connection']['secret_key'] = credentials['aws_secret']
        end

        # Fail fast if some `:required` example fails -> skip the others
        # WARNING: do not use this in OpenNebula code
        $continue = 'yes'

        # WARNING: do not use this in OpenNebula code
        $provider = $provider # To be able to use it in cleanup
    end

    after(:each) do |example|
        $continue = 'skip' if example.skipped?  && example.metadata[:required]
        $continue = 'fail' if example.exception && example.metadata[:required]
    end

    before(:each) do
        fail 'Previous required test failed'  if $continue == 'fail'
        skip 'Previous required test skipped' if $continue == 'skip'
    end

    ############################################################################
    # Examples
    ############################################################################

    it 'should delete resources on remote provider' do
        connection = $provider['connection']

        case $provider['provider']
        when 'aws'
            p = AWS.new(connection['access_key'], connection['secret_key'])
        end

        p.delete_devices
        p.delete_net
    end

    it 'should check empty provision list' do
        expect(empty?).to eq(true)
    end

    ############################################################################
    # Create the provider
    ############################################################################

    it 'should create the provider', :required do
        tempfile = Tempfile.new('provider')
        tempfile << $provider.to_yaml
        tempfile.close

        @info[:p_id] = cli_create("oneprovider create #{tempfile.path}")
    end

    ############################################################################
    # Create the provision
    ############################################################################

    it 'should create a provision', :required do
        cmd = "oneprovision create #{@provision_path} " \
              "--provider #{@info[:p_id]} " \
              '-D ' \
              '--batch ' \
              '--fail-modes cleanup ' \
              '--ping-timeout 60 ' \
              "--user-inputs=#{inputs}"

        # NOTE: set timeout to 60 minutes
        cmd = cli_action_timeout(cmd, true, 3600)

        # puts cmd.stdout
        # puts cmd.stderr

        @info[:p_id] = cli_action(
            'oneprovision list --no-header -l ID'
        ).stdout.strip

        if @info[:p_id].empty?
            puts "oneprovision list empty"
            puts "STDOUT:"
            puts cmd.stdout

            puts "STDERR:"
            puts cmd.stderr
        end

        @info[:provision] = cli_action_json(
            "oneprovision show -j #{@info[:p_id]}"
        )
    end

    it 'should check not empty provision list' do
        expect(empty?).to eq(false)
    end

    it 'should count clusters' do
        expect(count_elements('cluster')).to eq(1)
    end

    it 'should count datastores' do
        expect(count_elements('datastore')).to eq(2)
    end

    it 'should count hosts' do
        expect(count_elements('host')).to eq(3)
    end

    it 'should  count vnets' do
        expect(count_elements('network')).to eq(1)
    end

    ############################################################################
    # Configure and add more resources to the provision
    ############################################################################
    it '[FAIL] should fail to configure a RUNNING provision' do
        cli_action("oneprovision configure #{@info[:p_id]} -D", false)
    end

    it 'should configure a RUNNING provision' do
        cmd = cli_action_timeout(
            "oneprovision configure #{@info[:p_id]} -D --force --batch --fail-modes cleanup", true, 3600
        )

        puts cmd.stdout
        puts cmd.stderr
    end

    it 'should add one more host to the provision', :required do
        cmd = cli_action_timeout(
            "oneprovision host add #{@info[:p_id]} --batch --fail-modes cleanup --host-params ceph_group=clients -D", true, 1800
        )

        puts cmd.stdout
        puts cmd.stderr
    end

    it 'should count hosts (one more)' do
        expect(count_elements('host')).to eq(4)
    end

    it 'should add one more IP to the provision', :required do
        if @node
            cli_action("oneprovision ip add #{@info[:p_id]}", false)
        else
            cli_action("oneprovision ip add #{@info[:p_id]}")
        end
    end

    ############################################################################
    # Check the provision
    ############################################################################

    it 'should ensure 3 HOST in datastore BRIDGE_LIST' do
        ds     = element(@info[:provision], 'infrastructure', 'datastores', 1)
        ds_xml = cli_action_xml("onedatastore show -x #{ds['id']}")

        for i in 0..2
            host   = element(@info[:provision], 'infrastructure', 'hosts', i)
            host   = Host.new(host['id'])

            expect(ds_xml['TEMPLATE/BRIDGE_LIST'].split(' ')).to include(host.xml['NAME'])
        end
    end

    it 'should add ssh key to user template' do
        oneadmin_ssh_key = File.read('/var/lib/one/.ssh/id_rsa.pub')
        tmpl_ssh_key     = <<-EOF
            SSH_PUBLIC_KEY="#{oneadmin_ssh_key}"
        EOF

        cli_update('oneuser update 0', tmpl_ssh_key, false, true)
    end

    it 'should wait for marketplace appliance', :required do
        wait_app_ready(60, "'#{APPLIANCE}'")
    end

    it 'should forceupdate all the hosts to sync state' do
        cli_action('onehost forceupdate')
    end

    it 'should monitor datastores' do
        img_ds = element(@info[:provision], 'infrastructure', 'datastores', 0)
        sys_ds = element(@info[:provision], 'infrastructure', 'datastores', 1)

        wait_loop do
            img_ds_xml = cli_action_xml("onedatastore show -x #{img_ds['id']}")
            sys_ds_xml = cli_action_xml("onedatastore show -x #{sys_ds['id']}")

            img_ds_xml['FREE_MB'].to_i > 10000 && \
                sys_ds_xml['FREE_MB'].to_i > 10000
        end
    end

    ############################################################################
    # Create the VM
    ############################################################################

    it 'should create VM template', :required do
        netcat_listener = <<-EOT
            nc -lk -p 80 -e echo ConnectOK >/dev/null 2>&1 &
            nc -lk -p 81 -e echo ConnectOK >/dev/null 2>&1 &
        EOT

        ruby_listener = <<-EOT
            ruby -rsocket -e 'f=TCPServer.new(80);loop do c=f.accept;c.puts "ConnectOK";c.close; end' >/dev/null 2>&1 &
            ruby -rsocket -e 'f=TCPServer.new(81);loop do c=f.accept;c.puts "ConnectOK";c.close; end' >/dev/null 2>&1 &
        EOT

        case hypervisor
        when 'firecracker'
            cli_create(
                'oneimage create --name fc_fs ' \
                "-d #{$provider['provider']}-hci-cluster-image " \
                '--path http://services/images/fc_fs ' \
                '--prefix vd ' \
                '--type OS'
            )

            cli_create(
                'oneimage create --name fc_kernel ' \
                '-d files ' \
                '--path http://services/images/fc_kernel ' \
                '--type kernel'
            )

            wait_loop(:success => 'READY',
                      :break   => 'ERROR',
                      :timeout => 1800) do
                xml = cli_action_xml('oneimage show -x fc_fs')
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end

            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml('oneimage show -x fc_kernel')
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end

            fc_vm_tmpl = <<-EOT
                NAME="alpine"
                CPU="0.5"
                MEMORY="146"
                VCPU="2"
                CONTEXT=[
                  NETWORK="YES",
                  SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
                  START_SCRIPT_BASE64="#{Base64.encode64(netcat_listener).strip}" ]
                DISK=[
                  IMAGE="fc_fs",
                  IMAGE_UNAME="oneadmin" ]
                GRAPHICS=[
                  LISTEN="0.0.0.0",
                  TYPE="VNC" ]
                OS=[
                  BOOT="",
                  KERNEL_CMD="console=ttyS0 reboot=k panic=1 pci=off i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd",
                  KERNEL_DS="$FILE[IMAGE=\\"fc_kernel\\"]"]
            EOT

            cli_create('onetemplate create', fc_vm_tmpl)
        when 'lxc'
            cli_create(
                'oneimage create --name nginx ' \
                "-d #{$provider['provider']}-hci-cluster-image " \
                '--path http://services/images/lxc/lxc-nginx ' \
                '--prefix vd ' \
                '--type OS'
            )

            wait_loop(:success => 'READY',
                      :break   => 'ERROR',
                      :timeout => 900) do
                xml = cli_action_xml('oneimage show -x nginx')
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end

            lxc_vm_tmpl = <<-EOT
                NAME="alpine"
                CPU="0.5"
                MEMORY="128"
                CONTEXT=[
                  NETWORK="YES",
                  SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
                  START_SCRIPT_BASE64="#{Base64.encode64(ruby_listener).strip}" ]
                DISK=[
                  IMAGE="nginx",
                  IMAGE_UNAME="oneadmin" ]
                GRAPHICS=[
                  LISTEN="0.0.0.0",
                  TYPE="VNC" ]
                OS=[
                  ARCH="x86_64",
                  BOOT="" ]
            EOT

            cli_create('onetemplate create', lxc_vm_tmpl)
        when 'qemu', 'kvm'
            cli_action(
                "onemarketapp export \"#{APPLIANCE}\" alpine " \
                "-d #{$provider['provider']}-hci-cluster-image"
            )

            wait_loop(:success => 'READY',
                      :break   => 'ERROR',
                      :timeout => 300) do
                xml = cli_action_xml('oneimage show -x alpine')
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end

            tpl = Tempfile.new('')
            tpl.puts <<-EOT
            CONTEXT=[
              NETWORK="YES",
              SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
              START_SCRIPT_BASE64="#{Base64.encode64(ruby_listener).strip}"
            ]
            EOT
            tpl.close

            cli_action("onetemplate update alpine -a #{tpl.path}")
        end
    end

    it 'should create VMs', :required do
        VMS.each do |vm|
            @info[vm] = VM.new(cli_create('onetemplate instantiate alpine'))
            @info[vm].running?

            # Just to make sure guest OS is started (otherwise we could have
            # contextualization problems when NIC is attached)
            sleep(60) if @live # KVM and QEMU
        end
    end

    ############################################################################
    # Networking
    ############################################################################

    it 'should create a SG' do
        tpl = Tempfile.new('')

        sg_txt = %(NAME=test-sg
          DESCRIPTION=""
          RULE=[
            PROTOCOL="TCP",
            RULE_TYPE="outbound" ]
          RULE=[
            PROTOCOL="ICMP",
            RULE_TYPE="outbound" ]
          RULE=[
            PROTOCOL="ICMP",
            RULE_TYPE="inbound" ]
          RULE=[
            PROTOCOL="TCP",
            RANGE="22",
            RULE_TYPE="inbound" ]
          RULE=[
            PROTOCOL="TCP",
            RANGE="80",
            RULE_TYPE="inbound" ]
          RULE=[
            PROTOCOL="TCP",
            RANGE="9080",
            RULE_TYPE="inbound" ])

        tpl.puts sg_txt
        tpl.close

        @info[:test_sg] = cli_create("onesecgroup create #{tpl.path}")
    end

    it 'should update net to use new sg' do
        tpl = Tempfile.new('')
        tpl.puts "SECURITY_GROUPS=\"#{@info[:test_sg]}\""
        tpl.close

        cli_action(
            "onevnet update #{$provider['provider']}-hci-cluster-public " \
            "-a #{tpl.path}"
        )
    end

    it 'should attach NIC to all VMs', :required do
        VMS.each do |vm|
            @info[vm].poweroff unless @live
            @info[vm].nic_attach("#{$provider['provider']}-hci-cluster-public")
            @info[vm].resume unless @live
            @info[vm].running?

            vm_xml = cli_action_xml("onevm show #{@info[vm].id} -x")
            expect(vm_xml['//NIC']).to_not be nil
        end
    end

    it 'should SSH to VM public interface' do
        skip 'No BGP' if @no_bgp

        VMS.each do |vm|
            if @node
                wait_loop do
                    cli_action(
                        "onevm ssh #{@info[vm].id} " \
                        "--ssh-options '#{SSH_OPTIONS}' " \
                        '--cmd date',
                        nil
                    ).success?
                end
            else
                vm_xml = cli_action_xml("onevm show #{@info[vm].id} -x")
                @info["ip_#{vm}".to_sym] = vm_xml['//NIC/EXTERNAL_IP']

                wait_loop do
                    !SafeExec.run(
                        "ssh #{SSH_OPTIONS} " \
                        "root@#{@info["ip_#{vm}".to_sym]} date"
                    ).stdout.strip.empty?
                end
            end
        end
    end

    it 'should connect to VM port 80 or 9080' do
        skip 'No BGP' if @no_bgp

        if @node
            ip   = @info[:vm1].hostname
            port = 9080
        else
            ip   = @info[:ip_vm1]
            port = 80
        end

        wait_loop(:timeout => 60, :success => 'ConnectOK') do
            SafeExec.run(
                "nc -w 3 #{ip} #{port} </dev/null"
            ).stdout.strip
        end
    end

    it '[FAIL] should connect to VM port 81 nor 9081' do
        skip 'No BGP' if @no_bgp

        if @node
            cmd = SafeExec.run(
                "nc -w 3 #{@info[:vm1].hostname} 9081 </dev/null"
            )
        else
            cmd = SafeExec.run("nc -w 3 #{@info[:ip_vm1]} 81 </dev/null")
        end

        expect(cmd.stdout.strip).to be_empty
    end

    ############################################################################
    # Second VM
    ############################################################################

    it 'should poweroff VM2 (itself)' do
        skip 'No BGP' if @no_bgp

        if @node
            cli_action(
                "onevm ssh #{@info[:vm2].id} " \
                "--ssh-options '#{SSH_OPTIONS}' " \
                '--cmd poweroff',
                nil
            )
        else
            # FC does not implement ACPI, reboot needed to remove FC process
            hypervisor != 'firecracker' ? cmd = 'poweroff' : cmd = 'reboot'

            @info[:vm2].ssh(cmd, false, {}, 'root', '//NIC/EXTERNAL_IP')
        end

        @info[:vm2].state?('POWEROFF')
    end

    it 'should resume VM2' do
        skip 'No BGP' if @no_bgp

        cli_action("onevm resume #{@info[:vm2].id}")
        @info[:vm2].running?
    end

    it 'should connect to VM port 80 or 9080 (from VM2)' do
        skip 'No BGP' if @no_bgp

        if @node
            wait_loop do
                cli_action(
                    "onevm ssh #{@info[:vm2].id} " \
                    "--ssh-options '#{SSH_OPTIONS}' " \
                    '--cmd date',
                    nil
                ).success?
            end

            cmd = cli_action(
                "onevm ssh #{@info[:vm2].id} " \
                "--ssh-options '#{SSH_OPTIONS}' " \
                "--cmd 'curl -s --connect-timeout 30 telnet://#{@info[:vm1].hostname}:9080 </dev/null'",
                nil
            )
        else
            wait_loop do
                !SafeExec.run(
                    "ssh #{SSH_OPTIONS} root@#{@info[:ip_vm2]} date"
                ).stdout.strip.empty?
            end

            cmd = @info[:vm2].ssh(
                "curl -s --connect-timeout 30 telnet://#{@info[:ip_vm1]}:80 </dev/null",
                false,
                {},
                'root',
                '//NIC/EXTERNAL_IP'
            )
        end

        expect(cmd.stdout.strip).to eq('ConnectOK')
    end

    it '[FAIL] should connect to VM port 81 nor 9081 (from VM2)' do
        skip 'No BGP' if @no_bgp

        if @node
            cmd = cli_action(
                "onevm ssh #{@info[:vm2].id} " \
                "--ssh-options '#{SSH_OPTIONS}' " \
                "--cmd 'curl -s --connect-timeout 3 telnet://#{@info[:vm1].hostname}:9081 </dev/null'",
                nil
            )
        else
            cmd = @info[:vm2].ssh(
                "curl -s --connect-timeout 3 telnet://#{@info[:ip_vm1]}:81 </dev/null",
                false,
                {},
                'root',
                '//NIC/EXTERNAL_IP'
            )
        end

        cmd.expect_fail
    end

    ############################################################################
    # Private networking
    ############################################################################

    it 'should create private vnet' do
        skip 'No BGP' if @no_bgp

        @info[:vnet_private] = cli_create(
            "onevntemplate instantiate #{$provider['provider']}-hci-cluster-private"
        )

        cli_action(
            "onevnet addar #{@info[:vnet_private]} -s 3 -i 192.168.150.1"
        )
    end

    it 'should ping VM-VM EVPN' do
        skip 'No BGP' if @no_bgp

        VMS.each do |vm|
            @info[vm].poweroff unless @live
            @info[vm].nic_attach(@info[:vnet_private])
            @info[vm].resume unless @live
            @info[vm].running?
        end

        # VM1 -> 192.168.150.1
        # VM2 -> 192.168.150.2
        # VM3 -> 192.168.150.3
        ips = ['192.168.150.2', '192.168.150.3']

        if @node
            ips.each do |ip|
                wait_loop do
                    cli_action(
                        "onevm ssh #{@info[:vm1].id} " \
                        "--ssh-options '#{SSH_OPTIONS}' " \
                        "--cmd 'ping -c1 #{ip}'",
                        nil
                    ).success?
                end
            end
        else
            ips.each do |ip|
                wait_loop do
                    SafeExec.run(
                        "ssh #{SSH_OPTIONS} root@#{@info[:ip_vm1]} " \
                        "ping -c1 #{ip}"
                    ).success?
                end
            end
        end
    end

    it 'should terminate VM2' do
        @info[:vm2].running?
        @info[:vm2].terminate_hard
        @info[:vm2].done?
    end

    it 'should terminate VM3' do
        @info[:vm3].running?
        @info[:vm3].terminate_hard
        @info[:vm3].done?
    end

    ############################################################################
    # NIC alias
    ############################################################################

    it 'should attach NIC alias' do
        skip 'Not supported' if @node
        skip 'No BGP' if @no_bgp

        @info[:vm1].poweroff unless @live
        @info[:vm1].nic_attach(
            "#{$provider['provider']}-hci-cluster-public --alias NIC0"
        )
        @info[:vm1].resume unless @live
        @info[:vm1].running?

        vm_xml = cli_action_xml("onevm show #{@info[:vm1].id} -x")
        expect(vm_xml['//NIC_ALIAS[NIC_ID=2]']).to_not be nil
    end

    it 'should SSH to VM public interface as alias' do
        skip 'Not supported' if @node
        skip 'No BGP' if @no_bgp

        vm_xml = cli_action_xml("onevm show #{@info[:vm1].id} -x")
        @info[:alias_ext_ip] = vm_xml['//NIC_ALIAS/EXTERNAL_IP']

        skip 'No alias' unless @info[:alias_ext_ip]

        wait_loop do
            !SafeExec.run(
                "ssh #{SSH_OPTIONS} root@#{@info[:alias_ext_ip]} date"
            ).stdout.strip.empty?
        end
    end

    it 'should connect to VM port 80 or 9080 (NIC_ALIAS)' do
        skip 'Not supported' if @node
        skip 'No BGP' if @no_bgp
        skip 'No alias' unless @info[:alias_ext_ip]

        wait_loop(:timeout => 60, :success => 'ConnectOK') do
            SafeExec.run(
                "nc -w 3 #{@info[:alias_ext_ip]} 80 </dev/null"
            ).stdout.strip
        end
    end

    it '[FAIL] should connect to VM port 81 (NIC_ALIAS)' do
        skip 'Not supported' if @node
        skip 'No BGP' if @no_bgp

        cmd = SafeExec.run("nc -w 3 #{@info[:alias_ext_ip]} 81 </dev/null")

        expect(cmd.stdout.strip).to eq('')
    end

    ############################################################################
    # Detach
    ############################################################################

    it 'should detach NIC alias' do
        skip 'Not supported' if @node
        skip 'No BGP' if @no_bgp

        @info[:vm1].poweroff unless @live
        @info[:vm1].nic_detach('2')
        @info[:vm1].resume unless @live
        @info[:vm1].running?

        vm_xml = cli_action_xml("onevm show #{@info[:vm1].id} -x")
        expect(vm_xml['//NIC_ALIAS[NIC_ID=2]']).to be nil
    end

    it 'should detach NIC' do
        @info[:vm1].poweroff unless @live
        @info[:vm1].nic_detach('0')
        @info[:vm1].resume unless @live
        @info[:vm1].running?

        vm_xml = cli_action_xml("onevm show #{@info[:vm1].id} -x")
        expect(vm_xml['//NIC[NIC_ID=0]']).to be nil
    end

    it 'should terminate VM' do
        @info[:vm1].terminate_hard
        @info[:vm1].done?

        cli_action('onetemplate delete alpine --recursive')

        wait_loop(:success => false, :timeout => 60) do
            cli_action('oneimage show -x alpine', nil).success?
        end
    end

    it 'should remove secgroup' do
        cli_action("onesecgroup delete #{@info[:test_sg]}")
    end
end
