# frozen_string_literal: true

require 'erb'
require 'ipaddr'
require 'yaml'
require_relative '../vrouter.rb'

begin
    require 'json-schema'
rescue LoadError
    # NOTE: This handles the install stage.
end

module Service
module WireGuard
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_WG_ENABLED = env :ONEAPP_VNF_WG_ENABLED, 'NO'

    ONEAPP_VNF_WG_INTERFACES_OUT = env :ONEAPP_VNF_WG_INTERFACES_OUT, nil # nil -> none, empty -> all

    ONEAPP_VNF_WG_CFG_LOCATION = env :ONEAPP_VNF_WG_CFG_LOCATION, '/dev/sr0:/onewg.yml'

    def parse_env
        @interfaces_out ||= parse_interfaces ONEAPP_VNF_WG_INTERFACES_OUT
        @mgmt           ||= detect_mgmt_nics
        @interfaces     ||= @interfaces_out.keys - @mgmt

        iso_path, cfg_path = ONEAPP_VNF_WG_CFG_LOCATION.split(%[:])

        schema = YAML.load bash("#{File.dirname(__FILE__)}/onewg schema show", chomp: true)

        document = YAML.load bash("isoinfo -i #{iso_path} -R -x #{cfg_path}", chomp: true)

        if JSON::Validator.validate(schema, document)
            { cfg: document }
        else
            msg :error, 'YAML config looks invalid!'
            { cfg: nil }
        end
    end

    def install(initdir: '/etc/init.d')
        msg :info, 'WireGuard::install'

        puts bash 'apk --no-cache add cdrkit ruby wireguard-tools-wg-quick'
        puts bash 'gem install --no-document json-schema'

        file "#{initdir}/one-wg", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            depend() {
                after net firewall keepalived
            }

            start() {
                $command $command_args -e Service::WireGuard.execute 1>>/var/log/one-appliance/one-wg.log 2>&1
            }

            stop() {
                $command $command_args -e Service::WireGuard.cleanup 1>>/var/log/one-appliance/one-wg.log 2>&1
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/wireguard')
        msg :info, 'WireGuard::configure'

        unless ONEAPP_VNF_WG_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        parse_env[:cfg]&.each do |dev, opts|
            unless @interfaces.include?(opts['interface_out'])
                msg :error, "Forbidden outgoing interface: #{opts['interface_out']}"
                next
            end

            subnet = IPAddr.new(opts['peer_subnet'])

            peers = opts['peers'].to_h.each_with_object({}) do |(k, v), acc|
                next if v['public_key'].nil? && v['private_key'].nil?

                v['public_key'] ||= bash("wg pubkey <<< #{v['private_key']}", chomp: true)

                acc[k] = v
            end

            file "#{basedir}/#{dev}.conf", ERB.new(<<~PEER, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
                [Interface]
                Address    = <%= subnet.succ.to_s %>/<%= subnet.prefix %>
                ListenPort = <%= opts['server_port'] %>
                PrivateKey = <%= opts['private_key'] %>
                <%- peers.each do |k, v| -%>
                [Peer]
                PresharedKey = <%= v['preshared_key'] %>
                PublicKey    = <%= v['public_key'] %>
                AllowedIPs   = <%= v['address'].split(%[/])[0] %>/32
                <%- end -%>
            PEER
        end
    end

    def execute
        msg :info, 'WireGuard::execute'

        parse_env[:cfg]&.each do |dev, _|
            bash <<~BASH
                wg-quick up '#{dev}'
                echo 1 > '/proc/sys/net/ipv4/conf/#{dev}/forwarding'
            BASH
        end
    end

    def cleanup
        msg :info, 'WireGuard::cleanup'

        parse_env[:cfg]&.each do |dev, _|
            bash "wg-quick down '#{dev}'"
        end
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "WireGuard::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del one-wg default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-wg #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'WireGuard::bootstrap'
    end
end
end
