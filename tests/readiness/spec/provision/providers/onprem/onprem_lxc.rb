require 'init_functionality'

require_relative '../provision'
require_relative '../cleanup'

require 'base64'
require 'yaml'
require 'zlib'

RSpec.describe 'Onprem provision [LXC]' do
    hypervisor    = 'lxc'
    provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                    'metal/providers/onprem/onprem.yml'

    inputs = "hosts_names='192.168.150.2;192.168.150.3'," <<
             'first_public_ip=192.168.150.100,' <<
             'number_public_ips=10,' <<
             'public_phydev="br0",' <<
             'private_phydev="br0",' <<
             "one_hypervisor=#{hypervisor}"

    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), '../../defaults.yaml')
        )
    end

    before(:all) do
        unless File.exist?(provider_path)
            raise "Provider #{provider_path} does not exists"
        end

        @info           = {}
        @provider       = load_yaml(provider_path)
        @provision_path = '/usr/share/one/oneprovision/edge-clusters/' \
                          'metal/provisions/onprem.yml'

        # fail fast if some `:required` exmple fails -> fail the others
        $continue = 'yes'
    end

    after(:each) do |example|
        $continue = 'skip' if example.skipped?  && example.metadata[:required]
        $continue = 'fail' if example.exception && example.metadata[:required]
    end

    before(:each) do
        fail 'Previous required test failed'  if $continue == 'fail'
        skip 'Previous required test skipped' if $continue == 'skip'
    end

    it 'should create provider', :required do
        tempfile = Tempfile.new('provider')
        tempfile << @provider.to_yaml
        tempfile.close

        @info[:p_id] = cli_create("oneprovider create #{tempfile.path}")
    end

    it 'should check empty provision list' do
        expect(empty?).to eq(true)
    end

    it 'should create a provision', :required do
        cmd = "oneprovision create #{@provision_path} " \
              "--provider #{@info[:p_id]} " \
              '-D ' \
              '--batch ' \
              '--fail-modes cleanup ' \
              '--ping-timeout 60 ' <<
              "--user-inputs=#{inputs}"

        # NOTE: set timeout to 30 minutes
        puts cli_action_timeout(cmd, true, 1800).stdout

        @info[:p_id] = cli_action(
            'oneprovision list --no-header -l ID'
        ).stdout.strip

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
        expect(count_elements('host')).to eq(2)
    end

    it 'should count vnets' do
        expect(count_elements('network')).to eq(1)
    end

    it '[FAIL] should fail to configure a RUNNING provision' do
        cli_action("oneprovision configure #{@info[:p_id]} -D", false)
    end

    it 'should configure a RUNNING provision' do
        cmd = cli_action_timeout(
            "oneprovision configure #{@info[:p_id]} -D --force", true, 1800
        )

        puts cmd.stdout
        puts cmd.stderr
    end

    it 'should add one more host to the provision', :required do
        cmd = cli_action_timeout(
            "oneprovision host add #{@info[:p_id]} " \
            "--hostnames '192.168.150.4' " \
            '-D',
            true,
            1800
        )

        puts cmd.stdout
        puts cmd.stderr
    end

    it 'should count hosts (one more)' do
        expect(count_elements('host')).to eq(3)
    end

    it 'should ensure REPLICA_HOST in datastore' do
        host   = element(@info[:provision], 'infrastructure', 'hosts')
        ds     = element(@info[:provision], 'infrastructure', 'datastores', 1)

        host   = Host.new(host['id'])
        ds_xml = cli_action_xml("onedatastore show -x #{ds['id']}")

        expect(ds_xml['TEMPLATE/REPLICA_HOST']).to eq(host.xml['NAME'])
    end

    it 'should find public network' do
        body = @info[:provision]['DOCUMENT']['TEMPLATE']['BODY']
        vnets = body['provision']['infrastructure']['networks']
        @info[:vnet_id] = vnets[0]['id']
    end

    it 'updates public vnet' do
        cli_update("onevnet update #{@info[:vnet_id]}",
                   'CONF="keep_empty_bridge=true"
                    PHYDEV=""
                    BRIDGE="br0"', true)
    end

    it 'should create a VM' do
        cli_create(
            'oneimage create --name nginx ' \
            '-d onprem-cluster-image ' \
            '--path http://services/images/lxc/lxc-nginx ' \
            '--prefix vd ' \
            '--type OS'
        )

        wait_loop(:success => 'READY', :break => 'ERROR', :timeout => 900) do
            xml = cli_action_xml('oneimage show -x nginx')
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        lxc_vm_tmpl = <<-EOT
            NAME="alpine"
            CPU="0.5"
            MEMORY="128"
            CONTEXT=[
                NETWORK="YES",
                SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]" ]
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

        @info[:vm] = VM.new(cli_create('onetemplate instantiate alpine'))
        @info[:vm].running?
    end

    it 'should terminate VM' do
        @info[:vm].terminate_hard
        @info[:vm].done?

        cli_action('onetemplate delete alpine --recursive')

        wait_loop(:success => false, :timeout => 60) do
            cli_action('oneimage show -x alpine', nil).success?
        end
    end

    it_behaves_like 'cleanup'
end
