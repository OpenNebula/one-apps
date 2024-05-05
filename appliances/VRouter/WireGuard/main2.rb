# frozen_string_literal: true

require 'erb'
require 'ipaddr'
require 'yaml'
require 'base64'
require_relative '../vrouter.rb'

module Service
module WireGuard
    extend self

    # This class represents a WG peer and includes function to render and publish
    # its configuration to the virtual router VM template
    class Peer
        @@peers = 0

        def initialize(subnet, ip)
            @subnet = IPAddr.new(subnet)

            raise "Peer IP #{ip} not in peer subnet #{subnet}" unless @subnet.include? ip

            @ip = IPAddr.new(ip)

            @peer   = @@peers
            @@peers = @@peers + 1

            shared_k  = bash('wg genpsk', chomp: true)
            private_k = bash('wg genkey', chomp: true)
            public_k  = bash("wg pubkey <<< '#{private_k}'", chomp: true)

            @wgpeer = {
                'address'       => "#{@ip.to_s}/#{@subnet.prefix}",
                'preshared_key' => shared_k,
                'private_key'   => private_k,
                'public_key'    => public_k,
                'allowed_ips'   => %w[0.0.0.0/0]
            }
        end

        def to_s_client(opts)
            <<~PEER
                [Interface]
                Address    = #{@wgpeer['address']}
                PrivateKey = #{@wgpeer['private_key']}

                [Peer]
                Endpoint     = #{opts['server_addr']}:#{opts['listen_port']}
                PublicKey    = #{@wgpeer['public_key']}
                PresharedKey = #{@wgpeer['preshared_key']}
                AllowedIPs   = #{@wgpeer['allowed_ips'].join(%[,])}
            PEER
        end

        def to_s_server
            <<~PEER
                [Peer]
                PresharedKey = #{@wgpeer['preshared_key']}
                PublicKey    = #{@wgpeer['public_key']}
                AllowedIPs   = #{@wgpeer['address'].split(%[/])[0]}/32
            PEER
        end

        def update(opts)
            conf = "ONEAPP_VNF_WG_PEER#{@peer}='#{Base64.strict_encode64(to_s_client(opts))}'"

            bash "onegate vm update #{VM_ID} --data #{conf}"
        rescue StandardError => e
            msg :error, e.message
        end
    end


    DEPENDS_ON = %w[Service::Failover]

    # --------------------------------------------------------------------------
    # WireGuard Configuration parameters.
    # --------------------------------------------------------------------------
    #
    # ONEAPP_VNF_WG_ENABLED       = "YES"
    # ONEAPP_VNF_WG_INTERFACE_OUT = "eth0"
    # ONEAPP_VNF_WG_INTERFACE_IN  = "eth1"
    # ONEAPP_VNF_WG_LISTEN_PORT   = "51820"
    # ONEAPP_VNF_WG_DEVICE        = "wg0"
    # ONEAPP_VNG_WG_PEERS         = "10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4"
    # --------------------------------------------------------------------------
    # The VM ID of the Virtual Router
    VM_ID = env :VM_ID, nil

    # Enables the service
    ONEAPP_VNF_WG_ENABLED = env :ONEAPP_VNF_WG_ENABLED, 'NO'

    # The NIC to connect clients, its IP will be the service endpoint (MANDATORY)
    ONEAPP_VNF_WG_INTERFACE_OUT = env :ONEAPP_VNF_WG_INTERFACE_OUT, nil

    # The NIC to connect to the private subnet (MANDATORY)
    ONEAPP_VNF_WG_INTERFACE_IN = env :ONEAPP_VNF_WG_INTERFACE_IN, nil

    # Listen port number, defaults to 51820
    ONEAPP_VNF_WG_LISTEN_PORT = env :ONEAPP_VNF_WG_LISTEN_PORT, 51820

    # WG device name, defaults to wg0
    ONEAPP_VNF_WG_DEVICE = env :ONEAPP_VNF_WG_DEVICE, 'wg0'

    # Peers by IP address, each address MUST no be assigned to any VM (i.e. put
    # on hold or exclude from VNET AR's) (MANDATORY)
    # For example 5 PEERS:
    #    ONEAPP_VNG_WG_PEERS = "10.0.0.1 10.0.0.2 10.0.0.3 10.0.0.4 10.0.0.5"
    ONEAPP_VNF_WG_PEERS = env :ONEAPP_VNF_WG_PEERS, ''

    def parse_env
        iout = ONEAPP_VNF_WG_INTERFACE_OUT
        iin  = ONEAPP_VNF_WG_INTERFACE_IN

        mgmt = detect_mgmt_nics

        raise "Forbidden public (out) interface: #{iout}" if mgmt.include?(iout)

        @addrs_in ||= nics_to_addrs([iin])
        @addr_in  ||= @addrs_in[iin]

        @nets_in  ||= nics_to_subnets([iin])
        @net_in   ||= @nets_in[iin]

        pp @addrs_in
        pp @nets_in
        pp iin
        pp iout

        if @net_in.nil? || @net_in[0].empty? || @addr_in.nil? || @addr_in[0].empty?
          raise "Wrong configuration for private (in) interface: #{iin}"
        end

        {
          ONEAPP_VNF_WG_DEVICE => {
              'listen_port' => ONEAPP_VNF_WG_LISTEN_PORT,
              'iface_out'   => iout,
              'server_addr' => @addr_in[0],
              'private_key' => bash('wg genkey', chomp: true), 
              'peer_subnet' => @net_in[0],
              'peers'       => ONEAPP_VNF_WG_PEERS.split(' ').map {|p| p.chomp }
          }
        }
    end

    # --------------------------------------------------------------------------
    # SERIVCE INTERFACE: install, configure and bootstrap methods
    # --------------------------------------------------------------------------
    # Installs WireGuard service. Log set to /var/log/one-appliance/one-wg.log
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

    # Configure WG service
    def configure(basedir: '/etc/wireguard')
        msg :info, 'WireGuard::configure'

        unless ONEAPP_VNF_WG_ENABLED
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
            return
        end

        parse_env.each do |dev, opts|
            peers  = []

            opts['peers'].each do |ip|
                p = Peer.new opts['peer_subnet'], ip
                peers << p
            rescue StandardError => e
                msg :error, e.message
                next
            end

            file "#{basedir}/#{dev}.conf", ERB.new(<<~CONF, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
                [Interface]
                Address    = <%= opts['server_addr'] %>
                ListenPort = <%= opts['listen_port'] %>
                PrivateKey = <%= opts['private_key'] %>
                <% peers.each do |p| %>
                <%= p.to_s_server %>
                <% end %>
            CONF

            peers.each do |p|
                p.update opts
            end
        end
    end

    def bootstrap
        msg :info, 'WireGuard::bootstrap'
    end

    # --------------------------------------------------------------------------
    # WG helper functions
    # --------------------------------------------------------------------------
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

end
end
