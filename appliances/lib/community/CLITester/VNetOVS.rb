require 'json'

class OVSNetwork

    include RSpec::Matchers

    def initialize(vnet_id, host_id, oneadmin, timeout = 30)
        @defaults = RSpec.configuration.defaults

        @vnid = vnet_id
        @host = Host.new(host_id)

        @timeout = timeout
        @user    = oneadmin
    end

    def ssh(cmd)
        @host.ssh(cmd, true, { :timeout => @timeout }, @user)
    end

    def link_info(link)
        rc = ssh("ip --json link show #{link}")

        expect(rc.success?).to be(true)

        JSON.parse(rc.stdout)[0]
    end

    def qos_info(vnic)
        domain = vnic.split('-')[0..1].join('-')

        rc = ssh("virsh -c qemu:///system domiftune #{domain} #{vnic}")

        expect(rc.success?).to be(true)

        info = {}
        rc.stdout.each_line do |l|
            next if l.strip.empty?

            fields = l.split(':')
            info[fields[0].strip] = fields[1].strip
        end

        info
    end

    def port_info(port)
        rc = ssh("sudo ovs-vsctl list port #{port}")

        expect(rc.success?).to be(true)

        info = {}

        rc.stdout.each_line do |l|
            fields = l.split(':')
            info[fields[0].strip] = fields[1].strip
        end

        info
    end

    def list_ports
        vnet_info

        rc = ssh("sudo ovs-vsctl list-ports #{@xml['BRIDGE']}")

        expect(rc.success?).to be(true)

        rc.stdout.split
    end

    def updated?
        vnet_info
        @xml['OUTDATED_VMS'].empty? && @xml['UPDATING_VMS'].empty? && @xml['ERROR_VMS'].empty?
    end

    def update(template)
        cli_update("onevnet update #{@vnid}", template, true)
    end

    def vnet_info
        @xml = cli_action_xml("onevnet show -x #{@vnid}")
    end

    def state
        vnet_info
        VirtualNetwork::VN_STATES[@xml['STATE'].to_i]
    end

end
