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

        def to_template(opts)
            peer_conf64 = Base64.strict_encode64(to_s_client(opts))

            "ONEAPP_VNF_WG_PEER#{@peer}=#{peer_conf64}"
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

    #Base folder to store WG configuration
    ETC_DIR = '/etc/wireguard'

    def wg_environment
        iout = ONEAPP_VNF_WG_INTERFACE_OUT
        iin  = ONEAPP_VNF_WG_INTERFACE_IN

        mgmt = detect_mgmt_nics

        raise "Forbidden ONEAPP_VNF_WG_INTERFACE_OUT interface: #{iout}" if mgmt.include?(iout)

        #-----------------------------------------------------------------------
        # Get IP address information for INTERFACE_IN
        #-----------------------------------------------------------------------
        eps = detect_endpoints

        raise "Cannot find address information for #{iin}" if eps[iin].nil?

        rc = iin.match /eth(\d+)/i

        raise "Wrong format for ONEAPP_VNF_WG_INTERFACE_IN: #{iin}" if rc.nil?

        addr_in = eps[iin]["ETH#{rc[1]}_EP0"]

        raise "Cannot get IP address for #{iin}" if addr_in.nil? || addr_in.empty?

        server_addr, server_prefix = addr_in.split('/')

        nets_in  = nics_to_subnets([iin])
        net_in   = nets_in[iin]

        raise "Cannot get net addres for #{iin}" if nets_in[iin].nil? || net_in[0].empty?

        #-----------------------------------------------------------------------
        # Return configuration for the WG device
        #-----------------------------------------------------------------------
        {
            'listen_port' => ONEAPP_VNF_WG_LISTEN_PORT,
            'iface_out'   => iout,
            'server_addr' => server_addr,
            'private_key' => bash('wg genkey', chomp: true),
            'peer_subnet' => net_in[0],
            'peers'       => ONEAPP_VNF_WG_PEERS.split(' ').map {|p| p.chomp }
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

    # Configure WG service, just return and postpone to execute
    def configure(basedir: ETC_DIR)
        msg :info, 'WireGuard::configure'

        # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
        unless ONEAPP_VNF_WG_ENABLED
            toggle [:stop, :disable]
            return
        end
    end

    def bootstrap
        msg :info, 'WireGuard::bootstrap'
    end

    def bootstrap
        msg :info, 'WireGuard::bootstrap'
    end

    # --------------------------------------------------------------------------
    # WG helper functions
    # --------------------------------------------------------------------------
    def execute
        msg :info, 'WireGuard::execute'

        opts = wg_environment

        ids    = onegate_vmids
        conf64 = ''
        tstamp = 0

        ids.each do |vmid|
            t, c = onegate_conf(vmid)

            conf64 = c if (tstamp == 0 || t > tstamp) && c && !c.empty?
        end

        if !conf64.empty?
            # ------------------------------------------------------------------
            # Reuse existing configuration file in virtual router
            # ------------------------------------------------------------------
            msg :info, '[WireGuard::execute] Using existing configuration'

            file "#{ETC_DIR}/#{ONEAPP_VNF_WG_DEVICE}.conf",
                 Base64.strict_decode64(conf64),
                 mode: 'u=rw,g=r,o=',
                 overwrite: true
        else
            msg :info, '[WireGuard::execute] Generating a new configuration'

            # ------------------------------------------------------------------
            # Generate a new configuration
            # ------------------------------------------------------------------
            peers  = []

            opts['peers'].each do |ip|
                p = Peer.new opts['peer_subnet'], ip
                peers << p
            rescue StandardError => e
                msg :error, e.message
                next
            end

            conf = ERB.new(<<~CONF, trim_mode: '-').result(binding)
                [Interface]
                Address    = <%= opts['server_addr'] %>
                ListenPort = <%= opts['listen_port'] %>
                PrivateKey = <%= opts['private_key'] %>
                <% peers.each do |p| %>
                <%= p.to_s_server %>
                <% end %>
            CONF

            file "#{ETC_DIR}/#{ONEAPP_VNF_WG_DEVICE}.conf",
                 conf,
                 mode: 'u=rw,g=r,o=',
                 overwrite: true

            # ------------------------------------------------------------------
            # Save configuration to virtual router VMs
            # ------------------------------------------------------------------
            info = []

            peers.each do |p|
              info << p.to_template(opts)
            end

            info << "ONEAPP_VNF_WG_SERVER=#{Base64.strict_encode64(conf)}"
            info << "ONEAPP_VNF_WG_SERVER_TIMESTAMP=#{Time.now.to_i}"

            data = info.join("\n")

            ids.each do |vmid|
                msg :info, "[WireGuard::execute] Updating VM #{vmid}"

                bash "onegate vm update #{vmid} --data \"#{data}\""
            rescue StandardError => e
                msg :error, e.message
                next
            end
        end

        msg :info, "[WireGuard::execute] bringing up #{ONEAPP_VNF_WG_DEVICE}"

        bash <<~BASH
            wg-quick up '#{ONEAPP_VNF_WG_DEVICE}'
            echo 1 > '/proc/sys/net/ipv4/conf/#{ONEAPP_VNF_WG_DEVICE}/forwarding'
        BASH
    end

    def cleanup
        msg :info, 'WireGuard::cleanup'

        bash "wg-quick down '#{ONEAPP_VNF_WG_DEVICE}'"
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

    # Get the vm ids of the virtual router. Used to get/set WG configuration
    def onegate_vmids
        vr = onegate_vrouter_show

        vr['VROUTER']['VMS']['ID']
    rescue
        [VM_ID]
    end

    # Get configuration from the VM template
    def onegate_conf(vm_id)
        vm   = onegate_vm_show(vm_id)
        utmp = vm['VM']['USER_TEMPLATE']

        [utmp['ONEAPP_VNF_WG_SERVER_TIMESTAMP'], utmp['ONEAPP_VNF_WG_SERVER']]
    rescue
        [0, '']
    end

end
end
