require 'init'

K8S_SERVICE_NAME = 'Service OneKE 1.29 Airgapped'

SSH_OPTS = '-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null'

VNET_PUBLIC_SUBNET = '192.168.150.0/24'
VNET_PUBLIC_IP     = '192.168.150.100'
VNET_PUBLIC_LBIP   = '192.168.150.87'

# Helper function to achieve idempotent iptables
def iptables_cmd(args, table = 'nat', command = '-I', chain = 'POSTROUTING')
    check = "iptables -t #{table} -C #{chain} #{args}"
    apply = "iptables -t #{table} #{command} #{chain} #{args}"
    "#{check} || #{apply}"
end

# Enable NATed connection to public Internet via service VNET
def patch_networking
    fe_steps = [
        # Enable IPv4 forwarding
        'sysctl -w net.ipv4.ip_forward=1',
        # Enable NAT on eth0 for the public VNET
        iptables_cmd("-o eth0 -s #{VNET_PUBLIC_SUBNET} -j MASQUERADE"),
        # Make NGINX LB (MetalLB L2) accesible via VNF
        "ip route replace #{VNET_PUBLIC_LBIP}/32 via #{VNET_PUBLIC_IP} dev eth1"
    ]
    fe_steps.each do |command|
        cli_action "ssh #{SSH_OPTS} root@localhost '#{command}'", nil
    end
    vnf_steps = [
        # Make NGINX LB (MetalLB L2) accesible via VNF
        "ip route replace #{VNET_PUBLIC_LBIP}/32 dev eth1"
    ]
    vnf_steps.each do |command|
        cli_action "ssh #{SSH_OPTS} root@#{VNET_PUBLIC_IP} '#{command}'", nil
    end
end

RSpec.describe 'Instantiate OneKE/OneFlow service' do
    before(:all) do
        patch_networking
    end
    it 'instantiate OneKE/OneFlow service' do
        config = {
            "networks_values": [
                {"Public": {"id": "0"}},
                {"Private": {"id": "1"}}
            ],
            "custom_attrs_values": {
                "ONEAPP_VROUTER_ETH0_VIP0": "",
                "ONEAPP_VROUTER_ETH1_VIP0": "",

                "ONEAPP_RKE2_SUPERVISOR_EP": "ep0.eth0.vr:9345",
                "ONEAPP_K8S_CONTROL_PLANE_EP": "ep0.eth0.vr:6443",
                "ONEAPP_K8S_EXTRA_SANS": "localhost,127.0.0.1,ep0.eth0.vr,${vnf.TEMPLATE.CONTEXT.ETH0_IP}",

                "ONEAPP_K8S_MULTUS_ENABLED": "YES",
                "ONEAPP_K8S_MULTUS_CONFIG": "",

                "ONEAPP_K8S_CNI_PLUGIN": "cilium",
                "ONEAPP_K8S_CNI_CONFIG": "",
                "ONEAPP_K8S_CILIUM_RANGE": "192.168.150.240/28",

                "ONEAPP_K8S_LONGHORN_ENABLED": "YES",
                "ONEAPP_STORAGE_DEVICE": "/dev/vdb",
                "ONEAPP_STORAGE_FILESYSTEM": "xfs",

                "ONEAPP_K8S_METALLB_ENABLED": "NO",
                "ONEAPP_K8S_METALLB_CONFIG": "",
                "ONEAPP_K8S_METALLB_RANGE": "#{VNET_PUBLIC_LBIP}-#{VNET_PUBLIC_LBIP}",

                "ONEAPP_K8S_TRAEFIK_ENABLED": "YES",
                "ONEAPP_VNF_HAPROXY_INTERFACES": "eth0",
                "ONEAPP_VNF_HAPROXY_REFRESH_RATE": "30",
                "ONEAPP_VNF_HAPROXY_LB0_PORT": "9345",
                "ONEAPP_VNF_HAPROXY_LB1_PORT": "6443",
                "ONEAPP_VNF_HAPROXY_LB2_PORT": "443",
                "ONEAPP_VNF_HAPROXY_LB3_PORT": "80",

                "ONEAPP_VNF_DNS_ENABLED": "YES",
                "ONEAPP_VNF_DNS_INTERFACES": "eth1",
                "ONEAPP_VNF_DNS_NAMESERVERS": "1.1.1.1,8.8.8.8",
                "ONEAPP_VNF_NAT4_ENABLED": "YES",
                "ONEAPP_VNF_NAT4_INTERFACES_OUT": "eth0",
                "ONEAPP_VNF_ROUTER4_ENABLED": "YES",
                "ONEAPP_VNF_ROUTER4_INTERFACES": "eth0,eth1"
            }
        }

        file = Tempfile.new 'OneKE_instantiate'
        file.write JSON.generate(config)
        file.flush
        file.close

        cli_create "oneflow-template instantiate '#{K8S_SERVICE_NAME}' #{file.path}"
    end
    it 'check OneKE/OneFlow service is running (after instantiate)' do
        wait_service_ready(1200, K8S_SERVICE_NAME)
    end
    it 'scale up OneKE/OneFlow service' do
        cli_action "oneflow scale '#{K8S_SERVICE_NAME}' storage 1", nil
    end
    it 'check OneKE/OneFlow service is running (after scale)' do
        wait_service_ready(1200, K8S_SERVICE_NAME)
    end
end
