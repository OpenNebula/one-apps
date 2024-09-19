require 'init'

require 'context/requirements'
require 'context/common'
require 'context/linux'
require 'context/service'
require 'context/windows'

require 'image'

# Sometimes OpenNebula is terribly slow
ENV['ONE_XMLRPC_TIMEOUT'] = '90'

describe 'Contextualization' do
    @defaults = RSpec.configuration.defaults

    @defaults[:tests].each do |name, metadata|
        # if additional parameter set, limit test only to particular platform
        next if ENV.key?('RSPEC_PARAM_TEST') &&
            !ENV['RSPEC_PARAM_TEST'].empty? &&
            ENV['RSPEC_PARAM_TEST'] != name

        # some images might be limited to the particular microenv
        next if @defaults.key?(:microenv) &&
            metadata.key?(:microenvs) &&
            ![metadata[:microenvs]].flatten.include?(@defaults[:microenv])

        # lame detect hypervisor
        case @defaults[:microenv]
        when /lxd/
            hv = 'LXD'
        when /lxc/
            hv = 'LXC'
        when /vcenter/
            hv = 'VCENTER'
        else
            hv = 'KVM'
        end

        vm = nil

        context "image #{name} on #{hv}" do
            it 'imports image if it does not exist' do
                # import image if missing
                if cli_action("oneimage show '#{name}' >/dev/null", nil).fail?
                    # cmd = "oneimage create -d 1 --type OS --name '#{name}'"
                    options = "--path #{metadata[:url]} --format qcow2"

                    image = CLIImage.create(name, 1, options)
                    image.ready?
                end
            end

            it 'creates VM' do
                cmd = "onetemplate instantiate base --disk \'#{name}\'"
                vm_id = cli_create(cmd)
                vm = VM.new(vm_id)
                vm.reachable?
            end

            # TODO: Parse BSD static routing
            it 'VM has static route' do
                skip 'Missing route parsing for BSD' if vm.os_type == 'FreeBSD'

                # defined in bootstrap.yaml
                test_routes = ['8.8.4.4/32 via 192.168.150.2', '1.0.0.1/32 via 192.168.150.2']

                sleep(5) # netplan/NM quirks

                test_routes.each do |route|
                    # remove '/32' part
                    route_seen = route.sub(%r{/\d* via}, ' via')

                    expect(vm.routes.include?(route_seen)).to be(true)
                end
            end

            # Only the route is checked if ONEGATE_ENDPOINT is set. onegate is not interacted with
            it 'VM has ONEGATE Proxy static route' do
                skip 'Missing route parsing for BSD' if vm.os_type == 'FreeBSD'

                vm.poweroff

                onegate_host='169.254.16.9'
                test_route="#{onegate_host} dev eth0"
                onegate_endpoint = "ONEGATE_ENDPOINT=\"http://#{onegate_host}:5030\""
                vm.recontextualize(onegate_endpoint)

                vm.resume
                vm.reachable?

                expect(vm.routes.include?(test_route)).to be(true)
            end

            it 'deletes VM' do
                vm.terminate_hard
            end
        end
    end
end

def show_routes(vm)
    pp '---------------'
    pp vm.routes
    pp '---------------'
end
