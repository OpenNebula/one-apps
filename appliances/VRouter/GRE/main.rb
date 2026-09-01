# frozen_string_literal: true

require_relative '../vrouter'
require 'ipaddr'
require 'shellwords'

module Service
  module GRE
    extend self

    DEPENDS_ON = %w[Service::Failover Service::Router4]

    # Routing table used for GRE source-based policy routing.
    GRE_ROUTING_TABLE_ID = 10_000

    # ------------------------------------------------------------------------------
    # GRE Configuration parameters.
    # ------------------------------------------------------------------------------
    # Sample configuration:
    #     ONEAPP_VNF_GRE_ENABLED   = "YES"
    #     ONEAPP_VNF_GRE_INTERFACE = "gre1"
    #     ONEAPP_VNF_GRE_LOCAL     = "<LOCAL OUTER IP>"
    #     ONEAPP_VNF_GRE_REMOTE    = "<REMOTE PUBLIC IP>"
    #     ONEAPP_VNF_GRE_ADDRESS   = "<TUNNEL IP/CIDR>"
    #     ONEAPP_VNF_GRE_GATEWAY   = "<REMOTE TUNNEL IP>"
    #     ONEAPP_VNF_GRE_NETWORKS  = "<ROUTED NETWORK/CIDR>"
    #     ONEAPP_VNF_GRE_TTL       = "255"
    #
    # Example:
    #     ONEAPP_VNF_GRE_ENABLED   = "YES"
    #     ONEAPP_VNF_GRE_INTERFACE = "gre1"
    #     ONEAPP_VNF_GRE_LOCAL     = "192.168.1.80"
    #     ONEAPP_VNF_GRE_REMOTE    = "5.230.205.34"
    #     ONEAPP_VNF_GRE_ADDRESS   = "172.31.160.66/30"
    #     ONEAPP_VNF_GRE_GATEWAY   = "172.31.160.65"
    #     ONEAPP_VNF_GRE_NETWORKS  = "5.230.227.80/29"
    #     ONEAPP_VNF_GRE_TTL       = "255"
    # ------------------------------------------------------------------------------

    # Enable or disable the GRE service.
    ONEAPP_VNF_GRE_ENABLED =
      env :ONEAPP_VNF_GRE_ENABLED, 'NO'

    # Name of the GRE tunnel interface created by the service.
    ONEAPP_VNF_GRE_INTERFACE =
      env :ONEAPP_VNF_GRE_INTERFACE, 'gre1'

    # Local outer endpoint of the GRE tunnel.
    ONEAPP_VNF_GRE_LOCAL =
      env :ONEAPP_VNF_GRE_LOCAL, nil

    # Remote outer endpoint of the GRE tunnel.
    ONEAPP_VNF_GRE_REMOTE =
      env :ONEAPP_VNF_GRE_REMOTE, nil

    # Local inner address assigned to the GRE tunnel interface.
    ONEAPP_VNF_GRE_ADDRESS =
      env :ONEAPP_VNF_GRE_ADDRESS, nil

    # Remote inner address used as the next hop for traffic sent through GRE.
    ONEAPP_VNF_GRE_GATEWAY =
      env :ONEAPP_VNF_GRE_GATEWAY, nil

    # Source network prefixes whose traffic is routed through the GRE tunnel.
    ONEAPP_VNF_GRE_NETWORKS =
      env :ONEAPP_VNF_GRE_NETWORKS, nil

    # TTL applied to the outer GRE packets.
    ONEAPP_VNF_GRE_TTL =
      env :ONEAPP_VNF_GRE_TTL, '255'

    def install(initdir: '/etc/init.d')
      msg :info, 'GRE::install'

      puts bash 'apk --no-cache add iproute2 ruby'

      file "#{initdir}/one-gre", <<~SERVICE, mode: 'u=rwx,go=rx'
        #!/sbin/openrc-run
        source /run/one-context/one_env

        command="/usr/bin/ruby"
        command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

        depend() {
            after sysctl net firewall keepalived one-router4
        }

        start() {
            $command $command_args -e Service::GRE.execute 1>>/var/log/one-appliance/one-gre.log 2>&1
        }

        stop() {
            $command $command_args -e Service::GRE.cleanup 1>>/var/log/one-appliance/one-gre.log 2>&1
        }
      SERVICE

      toggle [:update]
    end

    def configure
      msg :info, 'GRE::configure'

      return if ONEAPP_VNF_GRE_ENABLED

      # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
      toggle %i[stop disable]
      nil
    end

    def toggle(operations)
      operations.each do |op|
        msg :info, "GRE::toggle([:#{op}])"

        case op
        when :disable
          puts bash 'rc-update del one-gre default ||:'
        when :update
          puts bash 'rc-update -u'
        else
          puts bash "rc-service one-gre #{op}"
        end
      end
    end

    def bootstrap
      msg :info, 'GRE::bootstrap'
    end

    def configuration
      {
        interface: validate_interface(ONEAPP_VNF_GRE_INTERFACE),
        address: validate_ipv4(ONEAPP_VNF_GRE_ADDRESS, 'ONEAPP_VNF_GRE_ADDRESS', cidr: true),
        local: validate_ipv4(ONEAPP_VNF_GRE_LOCAL, 'ONEAPP_VNF_GRE_LOCAL'),
        remote: validate_ipv4(ONEAPP_VNF_GRE_REMOTE, 'ONEAPP_VNF_GRE_REMOTE'),
        gateway: validate_ipv4(ONEAPP_VNF_GRE_GATEWAY, 'ONEAPP_VNF_GRE_GATEWAY'),
        networks: validate_networks(ONEAPP_VNF_GRE_NETWORKS),
        ttl: validate_ttl(ONEAPP_VNF_GRE_TTL)
      }.transform_values do |value|
        value.is_a?(Array) ? value.map { |item| Shellwords.escape(item) } : Shellwords.escape(value)
      end
    end

    def validate_interface(value)
      unless value.to_s.match?(/\A[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,14}\z/) &&
             !%w[all default gre0].include?(value)
        raise 'Invalid ONEAPP_VNF_GRE_INTERFACE (expected a Linux interface name)'
      end

      value
    end

    def validate_ipv4(value, name, cidr: false)
      string = value.to_s
      raise "Missing #{name}" if string.empty?
      raise "Invalid #{name} (expected IPv4#{'/CIDR' if cidr})" if cidr && !string.match?(%r{\A[0-9.]+/[0-9]{1,2}\z})
      raise "Invalid #{name} (expected IPv4)" if !cidr && string.include?('/')

      address = IPAddr.new(string)
      raise "Invalid #{name} (expected IPv4#{'/CIDR' if cidr})" unless address.ipv4?

      string
    rescue IPAddr::InvalidAddressError
      raise "Invalid #{name} (expected IPv4#{'/CIDR' if cidr})"
    end

    def validate_networks(value)
      networks = value.to_s.split(/[\s,;]+/).reject(&:empty?)
      raise 'Missing ONEAPP_VNF_GRE_NETWORKS' if networks.empty?

      networks.map do |network|
        address = IPAddr.new(validate_ipv4(network, 'ONEAPP_VNF_GRE_NETWORKS', cidr: true))
        "#{address}/#{address.prefix}"
      end.uniq
    end

    def validate_ttl(value)
      ttl = Integer(value, 10)
      raise 'Invalid ONEAPP_VNF_GRE_TTL (expected 1..255)' unless (1..255).cover?(ttl)

      ttl.to_s
    rescue ArgumentError, TypeError
      raise 'Invalid ONEAPP_VNF_GRE_TTL (expected 1..255)'
    end

    def execute
      msg :info, 'GRE::execute'

      config = configuration
      tun_interface = config[:interface]
      tun_address = config[:address]
      local = config[:local]
      remote = config[:remote]
      gateway = config[:gateway]
      networks = config[:networks]
      ttl = config[:ttl]

      msg :info, '[GRE::execute]: enabling ip_gre kernel module'
      bash 'modprobe ip_gre || true'

      msg :info, "[GRE::execute]: creating tunnel interface #{tun_interface}"

      bash <<~BASH
        ip tunnel del #{tun_interface} 2>/dev/null || true

        ip tunnel add #{tun_interface} \
            mode gre \
            local #{local} \
            remote #{remote} \
            ttl #{ttl}

        ip addr add #{tun_address} dev #{tun_interface}
        ip link set #{tun_interface} up
      BASH

      msg :info, "[GRE::execute]: enabling forwarding on #{tun_interface}"
      bash "sysctl -w net/ipv4/conf/#{tun_interface}/forwarding=1"

      msg :info, '[GRE::execute]: configuring source-based routing'

      bash <<~BASH
        ip rule flush table #{GRE_ROUTING_TABLE_ID} 2>/dev/null || true
        ip route flush table #{GRE_ROUTING_TABLE_ID} 2>/dev/null || true
      BASH

      networks.each do |network|
        bash <<~BASH
          ip rule add from #{network} table #{GRE_ROUTING_TABLE_ID}
          ip route replace throw #{network} table #{GRE_ROUTING_TABLE_ID}
        BASH
      end

      bash <<~BASH
        ip route replace default \
            via #{gateway} \
            dev #{tun_interface} \
            table #{GRE_ROUTING_TABLE_ID}
      BASH
    end

    def cleanup
      msg :info, 'GRE::cleanup'

      tun_interface = Shellwords.escape(validate_interface(ONEAPP_VNF_GRE_INTERFACE))

      msg :info, '[GRE::cleanup]: removing source-based routing'

      bash <<~BASH
        ip rule flush table #{GRE_ROUTING_TABLE_ID} 2>/dev/null || true
        ip route flush table #{GRE_ROUTING_TABLE_ID} 2>/dev/null || true
      BASH

      msg :info, "[GRE::cleanup]: removing tunnel interface #{tun_interface}"

      bash "ip tunnel del #{tun_interface} 2>/dev/null || true"
    end
  end
end
