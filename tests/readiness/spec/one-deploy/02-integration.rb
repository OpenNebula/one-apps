require 'init'

SSH_OPTS = '-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null'

VNET_PUBLIC_NAME   = 'public'
VNET_PUBLIC_PREFIX = '192.168.150'
VNET_PUBLIC_SUBNET = "#{VNET_PUBLIC_PREFIX}.0/24"

ONE_TOKEN = 'ci:Pantufl4.'

# Helper function to achieve idempotent iptables
def iptables_cmd(args, table = 'nat', command = '-I', chain = 'POSTROUTING')
    check = "iptables -t #{table} -C #{chain} #{args}"
    apply = "iptables -t #{table} #{command} #{chain} #{args}"
    "#{check} || #{apply}"
end

# Enable NATed connection to public Internet via service VNET
def patch_networking
    steps = [
        # Enable IPv4 forwarding
        'sysctl -w net.ipv4.ip_forward=1',
        # Enable NAT on eth0 for the public VNET
        iptables_cmd("-o eth0 -s #{VNET_PUBLIC_SUBNET} -j MASQUERADE")
    ]
    steps.each do |command|
        cli_action "ssh #{SSH_OPTS} root@localhost '#{command}'", nil
    end
end

RSpec.configure { |config| config.fail_fast = true }

RSpec.describe 'Prepare to run one-deploy/molecule' do
    before(:all) do
        @d = RSpec.configuration.defaults
        patch_networking
    end

    it 'clones one-deploy repository' do
        steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
        steps << 'install -m u=rwx,go= -d ~oneadmin/one-deploy/'
        steps << 'cd ~oneadmin/one-deploy/'
        steps << "git clone --recursive '#{@d[:onedeploy_url]}' --branch '#{@d[:onedeploy_rev]}' . || git pull origin"
        cli_action steps.join(';')
    end

    it 'installs one-deploy requirements' do
        steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
        steps << "pip3 install poetry"
        steps << 'cd ~oneadmin/one-deploy/'
        steps << 'make requirements'
        cli_action steps.join(';')
    end
end

RSpec.describe 'Deploy one-deploy/molecule environments' do
   before(:all) do
        @d = RSpec.configuration.defaults

        File.write File.expand_path('~oneadmin/one-deploy/.env.yml'), <<~VARS
            ONE_HOST: http://localhost:2633/RPC2
            ONE_USER: oneadmin
            ONE_PSWD: opennebula
            ONE_TOKEN: #{ONE_TOKEN}
            ONE_VNET: #{VNET_PUBLIC_NAME}
            ONE_SUBNET: #{VNET_PUBLIC_SUBNET}
            ONE_RANGE1: #{VNET_PUBLIC_PREFIX}.200 4
            ONE_RANGE2: #{VNET_PUBLIC_PREFIX}.204 4
            ONE_RANGE3: #{VNET_PUBLIC_PREFIX}.208 4
        VARS
    end

    it 'converges/destroys prometheus-ha environment' do
        %w[converge destroy].each do |action|
            steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
            steps << 'cd ~/one-deploy/'
            steps << "poetry run molecule #{action} -s prometheus-ha"
            cli_action_timeout steps.join(';'), true, 1500
        end
    end

    it 'converges/destroys passenger-ha environment' do
        %w[converge destroy].each do |action|
            steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
            steps << 'cd ~/one-deploy/'
            steps << "poetry run molecule #{action} -s passenger-ha"
            cli_action_timeout steps.join(';'), true, 1500
        end
    end

    it 'converges/destroys ceph-hci environment' do
        %w[converge destroy].each do |action|
            steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
            steps << 'cd ~/one-deploy/'
            steps << "poetry run molecule #{action} -s ceph-hci"
            cli_action_timeout steps.join(';'), true, 1500
        end
    end

    it 'converges/destroys federation environment' do
        %w[converge destroy].each do |action|
            steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
            steps << 'cd ~/one-deploy/'
            steps << "poetry run molecule #{action} -s federation"
            cli_action_timeout steps.join(';'), true, 1500
        end
    end

    it 'converges/destroys federation-ha environment' do
        %w[converge destroy].each do |action|
            steps = ['set -e', 'export PATH=$HOME/.local/bin:$PATH']
            steps << 'cd ~/one-deploy/'
            steps << "poetry run molecule #{action} -s federation-ha"
            cli_action_timeout steps.join(';'), true, 1500
        end
    end
end
