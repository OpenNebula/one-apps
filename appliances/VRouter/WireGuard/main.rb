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

        def initialize(conf)
            @wgpeer = {}

            #-------------------------------------------------------------------
            # Peer index
            # Address: Peer IP address in the peer subnet.
            #   subnet + 0 = peer network address
            #   subnet + 1 = WG server IP
            #   subnet + 2 + N = IP for Nth peer
            #-------------------------------------------------------------------
            @peer   = @@peers
            @@peers = @@peers + 1

            addr = IPAddr.new(conf[:subnet].to_i + @peer + 2, Socket::AF_INET)

            @wgpeer[:address] = "#{addr}/#{conf[:subnet].prefix}"

            #-------------------------------------------------------------------
            # Keys
            #-------------------------------------------------------------------
            @wgpeer[:shared]  = bash('wg genpsk', chomp: true)
            @wgpeer[:private] = bash('wg genkey', chomp: true)
            @wgpeer[:public]  = bash("wg pubkey <<< '#{@wgpeer[:private]}'", chomp: true)

            @wgpeer[:allowedips] = conf[:allowedips]

            #-------------------------------------------------------------------
            # Server Information
            #-------------------------------------------------------------------
            @wgpeer[:server_addr]   = conf[:server_addr]
            @wgpeer[:server_public] = conf[:server_public]
            @wgpeer[:listenport]    = conf[:listenport]
        end

        def to_s_client
            <<~PEER
                [Interface]
                Address    = #{@wgpeer[:address]}
                PrivateKey = #{@wgpeer[:private]}

                [Peer]
                Endpoint     = #{@wgpeer[:server_addr]}:#{@wgpeer[:listenport]}
                PublicKey    = #{@wgpeer[:server_public]}
                PresharedKey = #{@wgpeer[:shared]}
                AllowedIPs   = #{@wgpeer[:allowedips]}
            PEER
        end

        def to_s_server
            <<~PEER
                [Peer]
                PresharedKey = #{@wgpeer[:shared]}
                PublicKey    = #{@wgpeer[:public]}
                AllowedIPs   = #{@wgpeer[:address].split(%[/])[0]}/32
            PEER
        end

        def to_template
            "ONEGATE_VNF_WG_PEER#{@peer}=#{Base64.strict_encode64(to_s_client)}"
        end
    end

    DEPENDS_ON = %w[Service::Failover]

    # --------------------------------------------------------------------------
    # WireGuard Configuration parameters.
    # --------------------------------------------------------------------------
    # Sample configuration minimal (with 5 peers):
    #     ONEAPP_VNF_WG_ENABLED       = "YES"
    #     ONEAPP_VNF_WG_INTERFACE_OUT = "eth0"
    #     ONEAPP_VNF_WG_INTERFACE_IN  = "eth1"
    #
    # Complete configuration
    #     ONEAPP_VNF_WG_ENABLED       = "YES"
    #     ONEAPP_VNF_WG_INTERFACE_OUT = "eth0"
    #     ONEAPP_VNF_WG_INTERFACE_IN  = "eth1"
    #     ONEAPP_VNF_WG_LISTEN_PORT   = "51820"
    #     ONEAPP_VNF_WG_DEVICE        = "wg0"
    #     ONEAPP_VNG_WG_PEERS         = "3"
    #     ONEAPP_VNG_WG_SUBNET        = "169.254.33.0/24"
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

    # Number of peers, it will generate peer configuration and associated keys
    ONEAPP_VNF_WG_PEERS = env :ONEAPP_VNF_WG_PEERS, 5

    # Subnet used to interconnect WG peers these address should not be part
    # of an OpenNebula virtual network
    ONEAPP_VNF_WG_SUBNET = env :ONEAPP_VNF_WG_SUBNET, '169.254.33.0/24'

    # WG device name, defaults to wg0
    ONEAPP_VNF_WG_DEVICE = env :ONEAPP_VNF_WG_DEVICE, 'wg0'

    #Base folder to store WG configuration
    ETC_DIR = '/etc/wireguard'

    def wg_environment
        iout = ONEAPP_VNF_WG_INTERFACE_OUT
        iin  = ONEAPP_VNF_WG_INTERFACE_IN

        mgmt = detect_mgmt_nics

        raise "Forbidden ONEAPP_VNF_WG_INTERFACE_OUT interface: #{iout}" if mgmt.include?(iout)

        conf = {}

        #-----------------------------------------------------------------------
        # Endpoint: IP address peers will use to connect to the WG
        # server
        #   conf[:server_addr]
        #   conf[:server_prefix]
        #-----------------------------------------------------------------------
        eps = detect_endpoints

        raise "Cannot find address information for #{iout}" if eps[iout].nil?

        rc = iout.match /eth(\d+)/i

        raise "Wrong format for ONEAPP_VNF_WG_INTERFACE_IN: #{iout}" if rc.nil?

        addr_in = eps[iout]["ETH#{rc[1]}_EP0"]

        raise "Cannot get IP address for #{iout}" if addr_in.nil? || addr_in.empty?

        conf[:server_addr], conf[:server_prefix] = addr_in.split('/')

        #-----------------------------------------------------------------------
        # AllowedIPs: IP addresses (CIDR) from which traffic is allowed
        # and to which traffic is directed. This is the OpenNebula virtual
        # network address space.
        #   conf[:subnet]
        #-----------------------------------------------------------------------
        nets_in  = nics_to_subnets([iin])
        net_in   = nets_in[iin]

        raise "Cannot get net addres for #{iin}" if nets_in[iin].nil? || net_in[0].empty?

        conf[:allowedips] = net_in[0]

        #-----------------------------------------------------------------------
        # Server keys
        #   conf[:server_private]
        #   conf[:server_public]
        #-----------------------------------------------------------------------
        conf[:server_private] = bash('wg genkey', chomp: true)
        conf[:server_public]  = bash("wg pubkey <<< '#{conf[:server_private]}'",
                                     chomp: true)

        #-----------------------------------------------------------------------
        # Misc. configuration parameters
        #-----------------------------------------------------------------------
        conf[:listenport] = ONEAPP_VNF_WG_LISTEN_PORT
        conf[:subnet]     = IPAddr.new(ONEAPP_VNF_WG_SUBNET)
        conf[:dev]        = ONEAPP_VNF_WG_DEVICE
        conf[:num_peers]  = begin
                                Integer(ONEAPP_VNF_WG_PEERS)
                            rescue
                                5
                            end
        #-----------------------------------------------------------------------
        # Return configuration
        # TODO Support multiple devices
        #-----------------------------------------------------------------------
        conf
    end

    # --------------------------------------------------------------------------
    # SERIVCE INTERFACE: install, configure and bootstrap methods
    # --------------------------------------------------------------------------
    # Installs WireGuard service. Log set to /var/log/one-appliance/one-wg.log
    def install(initdir: '/etc/init.d')
        msg :info, 'WireGuard::install'

        puts bash 'apk --no-cache add cdrkit ruby wireguard-tools-wg-quick'

        file "#{initdir}/one-wg", <<~SERVICE, mode: 'u=rwx,go=rx'
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

    # --------------------------------------------------------------------------
    # WG helper functions
    # --------------------------------------------------------------------------
    def execute
        msg :info, 'WireGuard::execute'

        opts = wg_environment

        ids    = onegate_vmids
        conf64 = ''
        vm64   = -1
        tstamp = 0

        ids.each do |vmid|
            t, c = onegate_conf(vmid)

            if (tstamp == 0 || t > tstamp) && c && !c.empty?
                conf64 = c
                vm64   = vmid
            end
        end

        if !conf64.empty?
            # ------------------------------------------------------------------
            # Reuse existing configuration file in virtual router
            # ------------------------------------------------------------------
            msg :info, "[WireGuard::execute] Using configuration found in VM #{vm64}"

            file "#{ETC_DIR}/#{opts[:dev]}.conf",
                 Base64.strict_decode64(conf64),
                 mode: 'u=rw,g=r,o=',
                 overwrite: true
        else
            msg :info, '[WireGuard::execute] Generating a new configuration'

            # ------------------------------------------------------------------
            # Generate a new configuration
            # ------------------------------------------------------------------
            peers  = []

            opts[:num_peers].to_i.times do |ip|
                p = Peer.new opts
                peers << p
            rescue StandardError => e
                msg :error, e.message
                next
            end

            conf = ERB.new(<<~CONF, trim_mode: '-').result(binding)
                [Interface]
                Address    = <%= "#{opts[:subnet].succ}/#{opts[:subnet].prefix}" %>
                ListenPort = <%= opts[:listenport] %>
                PrivateKey = <%= opts[:server_private] %>
                <% peers.each do |p| %>
                <%= p.to_s_server %>
                <% end %>
            CONF

            file "#{ETC_DIR}/#{opts[:dev]}.conf",
                 conf,
                 mode: 'u=rw,g=r,o=',
                 overwrite: true

            # ------------------------------------------------------------------
            # Save configuration to virtual router VMs
            # ------------------------------------------------------------------
            info = []

            peers.each do |p|
              info << p.to_template
            end

            info << "ONEGATE_VNF_WG_SERVER=#{Base64.strict_encode64(conf)}"
            info << "ONEGATE_VNF_WG_SERVER_TIMESTAMP=#{Time.now.to_i}"

            data = info.join("\n")

            ids.each do |vmid|
                msg :info, "[WireGuard::execute] Updating VM #{vmid}"

                OneGate.instance.vm_update(data, vmid)
            rescue StandardError => e
                msg :error, e.message
                next
            end
        end

        msg :info, "[WireGuard::execute] bringing up #{opts[:dev]}"

        bash <<~BASH
            wg-quick up '#{opts[:dev]}'
            echo 1 > '/proc/sys/net/ipv4/conf/#{opts[:dev]}/forwarding'
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
        vr = OneGate.instance.vrouter_show

        vr['VROUTER']['VMS']['ID']
    rescue
        [VM_ID]
    end

    # Get configuration from the VM template
    def onegate_conf(vm_id)
        vm   = OneGate.instance.vm_show(vm_id)
        utmp = vm['VM']['USER_TEMPLATE']

        [utmp['ONEGATE_VNF_WG_SERVER_TIMESTAMP'], utmp['ONEGATE_VNF_WG_SERVER']]
    rescue
        [0, '']
    end

end
end
