# frozen_string_literal: true

require 'ipaddr'

require_relative 'config.rb'
require_relative 'helpers.rb'
require_relative 'onegate.rb'

def configure_vnf(gw_ipv4 = ONEAPP_VROUTER_ETH1_VIP0,
                  use_dns = ONEAPP_VNF_DNS_ENABLED,
                  dns_ipv4 = ONEAPP_VROUTER_ETH1_VIP0)

    if gw_ipv4.nil? || (use_dns && dns_ipv4.nil?)
        addr_info = ip_addr_show('eth0')&.dig(0, 'addr_info')
                                        &.find { |item| item['family'] == 'inet'}
        if addr_info.nil?
            msg :error, 'Unable to get local IP, aborting..'
            exit 1
        end

        subnet = IPAddr.new("#{addr_info['local']}/#{addr_info['prefixlen']}")

        vnf_ipv4 = vnf_vm_show&.dig('VM', 'TEMPLATE', 'NIC')
                              &.find { |item| !(ip = item['IP']).nil? && subnet.include?(ip) }
                              &.dig('IP')
        if vnf_ipv4.nil?
            msg :error, 'Unable to get VNF IP, aborting..'
            exit 1
        end

        if gw_ipv4.nil?
            msg :info, "Using '#{vnf_ipv4}' as default gateway.."
            gw_ipv4 = vnf_ipv4
        end

        if use_dns && dns_ipv4.nil?
            msg :info, "Using '#{vnf_ipv4}' as primary nameserver.."
            dns_ipv4 = vnf_ipv4
        end
    end

    if (gw_ok = !gw_ipv4.nil? && ipv4?(gw_ipv4)) == true
        msg :debug, 'Configure default gateway (temporarily)'
        bash "ip route replace default via #{gw_ipv4} dev eth0"
    end

    if (dns_ok = use_dns && !dns_ipv4.nil? && ipv4?(dns_ipv4)) == true
        msg :debug, 'Configure primary DNS (temporarily)'
        file '/etc/resolv.conf', <<~RESOLV_CONF, overwrite: true
        nameserver #{dns_ipv4}
        RESOLV_CONF
    end

    msg :info, 'Install the vnf-restore service'

    file '/etc/systemd/system/vnf-restore.service', <<~SERVICE, overwrite: true
    [Unit]
    After=network.target

    [Service]
    Type=oneshot
    ExecStart=/bin/sh -ec '#{gw_ok ? "ip route replace default via #{gw_ipv4} dev eth0" : ':'}'
    ExecStart=/bin/sh -ec '#{dns_ok ? "echo 'nameserver #{dns_ipv4}' > /etc/resolv.conf" : ':'}'

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Make sure vnf-restore is triggered everytime one-context-reconfigure.service runs.
    file '/etc/systemd/system/one-context-reconfigure.service.d/vnf-restore.conf', <<~SERVICE, overwrite: true
    [Service]
    ExecStartPost=/usr/bin/systemctl restart vnf-restore.service
    SERVICE

    msg :info, 'Enable and start the vnf-restore service'
    bash <<~SCRIPT
    systemctl daemon-reload
    systemctl enable vnf-restore.service --now
    SCRIPT
end

def vnf_supervisor_setup_backend(lb_idx = 0,
                                 lb_ipv4 = ONEAPP_VNF_HAPROXY_LB0_IP,
                                 lb_port = ONEAPP_VNF_HAPROXY_LB0_PORT)

    unless (lb_ok = !lb_ipv4.nil? && port?(lb_port))
        msg :error, "Invalid IPv4/port for VNF/HAPROXY/#{lb_idx}, aborting.."
        exit 1
    end

    ipv4 = external_ipv4s
        .reject { |item| item == lb_ipv4 }
        .first

    msg :info, "Register VNF/HAPROXY/#{lb_idx} backend in OneGate"

    onegate_vm_update [
        "ONEGATE_HAPROXY_LB#{lb_idx}_IP=#{lb_ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_PORT=#{lb_port}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_HOST=#{ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_PORT=#{lb_port}"
    ]
end

def vnf_control_plane_setup_backend(lb_idx = 1,
                                    lb_ipv4 = ONEAPP_VNF_HAPROXY_LB1_IP,
                                    lb_port = ONEAPP_VNF_HAPROXY_LB1_PORT)

    unless (lb_ok = !lb_ipv4.nil? && port?(lb_port))
        msg :error, "Invalid IPv4/port for VNF/HAPROXY/#{lb_idx}, aborting.."
        exit 1
    end

    ipv4 = external_ipv4s
        .reject { |item| item == lb_ipv4 }
        .first

    msg :info, "Register VNF/HAPROXY/#{lb_idx} backend in OneGate"

    onegate_vm_update [
        "ONEGATE_HAPROXY_LB#{lb_idx}_IP=#{lb_ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_PORT=#{lb_port}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_HOST=#{ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_PORT=#{lb_port}"
    ]
end

def vnf_ingress_setup_https_backend(lb_idx = 2,
                                    lb_ipv4 = ONEAPP_VNF_HAPROXY_LB2_IP,
                                    lb_port = ONEAPP_VNF_HAPROXY_LB2_PORT)

    unless (lb_ok = !lb_ipv4.nil? && port?(lb_port))
        msg :error, "Invalid IPv4/port for VNF/HAPROXY/#{lb_idx}, aborting.."
        exit 1
    end

    ipv4 = external_ipv4s
        .reject { |item| item == lb_ipv4 }
        .first

    msg :info, "Register VNF/HAPROXY/#{lb_idx} backend in OneGate"

    server_port = lb_port.to_i + 32_000

    onegate_vm_update [
        "ONEGATE_HAPROXY_LB#{lb_idx}_IP=#{lb_ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_PORT=#{lb_port}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_HOST=#{ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_PORT=#{server_port}"
    ]
end

def vnf_ingress_setup_http_backend(lb_idx = 3,
                                   lb_ipv4 = ONEAPP_VNF_HAPROXY_LB3_IP,
                                   lb_port = ONEAPP_VNF_HAPROXY_LB3_PORT)

    unless (lb_ok = !lb_ipv4.nil? && port?(lb_port))
        msg :error, "Invalid IPv4/port for VNF/HAPROXY/#{lb_idx}, aborting.."
        exit 1
    end

    ipv4 = external_ipv4s
        .reject { |item| item == lb_ipv4 }
        .first

    msg :info, "Register VNF/HAPROXY/#{lb_idx} backend in OneGate"

    server_port = lb_port.to_i + 32_000

    onegate_vm_update [
        "ONEGATE_HAPROXY_LB#{lb_idx}_IP=#{lb_ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_PORT=#{lb_port}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_HOST=#{ipv4}",
        "ONEGATE_HAPROXY_LB#{lb_idx}_SERVER_PORT=#{server_port}"
    ]
end
