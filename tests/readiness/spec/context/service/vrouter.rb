require "base64"
require "init"
require 'lib/DiskResize'

require_relative 'vrouter_common'

include DiskResize


#
# VMs context
#

VM_CONTEXT_BASIC = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  PASSWORD = "debugtest" ]
NIC = [
  NETWORK = "private" ]
EOT

VM_CONTEXT_SIMPLE_WEB_SERVER = <<-EOT
CONTEXT = [
  BACKEND = "YES",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  START_SCRIPT_BASE64="#{Base64.encode64("
      myipaddr=$(ip -o addr show eth1 scope global | awk '{print $4}');
      echo 'Hello from:' ${myipaddr} > /var/tmp/index.html;

      ### webserver code starts here ###
      {
      echo 'require \"socket\"';
      echo 'server = TCPServer.new 8080';
      echo 'while session = server.accept'
      echo '  request = session.gets';
      echo '  puts request';
      echo '  session.print \"HTTP/1.1 200\r\n\"';
      echo '  session.print \"Content-Type: text/html\r\n\"';
      echo '  session.print \"\r\n\"';
      echo '  msg = File.read(\"/var/tmp/index.html\")';
      echo '  session.print msg.to_s';
      echo '  session.close';
      echo 'end';
      } > /var/tmp/simple-webserver.rb
      ### webserver code ends here ###

      # to avoid stuck ssh session...

      echo '#{Base64.encode64("#!/sbin/openrc-run

name='ruby-webserver'

scriptfile='/var/tmp/simple-webserver.rb'

command='/bin/sh'
command_args=\" -c 'while true ; do /usr/bin/ruby \${scriptfile} ; done'\"
command_background='yes'
command_user='root:root'
pidfile='/var/tmp/ruby-webserver.pid'

start_stop_daemon_args=\"
    --wait 10
    \$start_stop_daemon_args\"

depend() {
    after firewall
    use logger
}

reload() {
    ebegin \"Reloading \${RC_SVCNAME}\"
    start-stop-daemon --signal HUP --pidfile \"\${pidfile}\"
    eend \$?
}
")}' | base64 -d > /etc/init.d/ruby-webserver ;
      chmod 0755 /etc/init.d/ruby-webserver

      cp -a /run/one-context/context.sh.network /tmp/context.sh.network
      sed -i 's/.*/export &/g' /tmp/context.sh.network
      . /tmp/context.sh.network
      install -d /etc/iproute2 ;
      echo '100 avoid_private_vnet' > /etc/iproute2/rt_tables ;
      ip rule add from ${myipaddr} table avoid_private_vnet ;
      ip route add default via ${ETH1_GATEWAY} dev eth1 table avoid_private_vnet ;

      # run webserver in the workaround
      ")}",
  PASSWORD = "debugtest"
  ]
NIC = [
  NETWORK = "private"
  ]
EOT

# works better but requires internet and functioning dns
VM_CONTEXT_NGINX_WEB_SERVER = <<-EOT
CONTEXT = [
  BACKEND = "YES",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  START_SCRIPT_BASE64="#{Base64.encode64("
      myipaddr=$(ip -o addr show eth1 scope global | awk '{print $4}');
      echo 'Hello from:' ${myipaddr} > /var/tmp/index.html;
      chmod 644 /var/tmp/index.html;

      while ! command -v nginx ; do
        apk update || true
        apk add nginx || true
      done

      echo '#{Base64.encode64('
        server {
            listen 8080 default_server;
            listen [::]:8080 default_server;

            root /var/tmp;
            index index.html;
            location / {
                    try_files $uri $uri/ =404;
            }

            # You may need this to prevent return 404 recursion.
            location = /404.html {
                    internal;
            }
        }
      ')}' | base64 -d > /etc/nginx/http.d/default.conf ;

      cp -a /run/one-context/context.sh.network /tmp/context.sh.network
      sed -i 's/.*/export &/g' /tmp/context.sh.network
      . /tmp/context.sh.network
      install -d /etc/iproute2 ;
      echo '100 avoid_private_vnet' > /etc/iproute2/rt_tables ;
      ip rule add from ${myipaddr} table avoid_private_vnet ;
      ip route add default via ${ETH1_GATEWAY} dev eth1 table avoid_private_vnet ;

      # run rc-service nginx start in the workaround
  ")}",
  PASSWORD = "debugtest"
  ]
NIC = [
  NETWORK = "private"
  ]
EOT


#
# VNF contexts
#

VNF_CONTEXT_NETWORK = <<-EOT
NIC = [
  NETWORK = "public" ]
NIC = [
  NETWORK = "vnet_a",
  IP = "%VNET_A_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_b",
  IP = "%VNET_B_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_mgt",
  IP = "%VNET_MGT_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_dmz",
  IP = "%VNET_DMZ_GATEWAY%" ]
EOT

# AS VM TEMPLATE

VNF_CONTEXT_VM_TEST0 = <<-EOT
CONTEXT = [
  ONEAPP_VNF_KEEPALIVED_VRID = "86",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  PASSWORD = "debugtest" ]
EOT

VNF_CONTEXT_VM_TEST1 = <<-EOT
CONTEXT = [
  ONEAPP_VNF_KEEPALIVED_VRID = "86",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth0",
  ONEAPP_VNF_DHCP4_ENABLED = "YES",
  ONEAPP_VNF_DHCP4_INTERFACES = "lo/127.0.0.1",
  ONEAPP_VNF_SDNAT4_ENABLED = "YES",
  ONEAPP_VNF_LB_ENABLED = "YES",
  ONEAPP_VNF_HAPROXY_ENABLED = "YES",
  PASSWORD = "debugtest" ]
EOT

VNF_CONTEXT_VM_TEST2 = <<-EOT
CONTEXT = [
  ONEAPP_VNF_KEEPALIVED_VRID = "86",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_ROUTER4_INTERFACES = "eth1 eth2 eth4",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_DNS_INTERFACES = "eth1 eth2 eth3 eth4",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth4",
  ONEAPP_VNF_KEEPALIVED_ENABLED = "YES",
  ONEAPP_VNF_DHCP4_ENABLED = "YES",
  ONEAPP_VNF_DHCP4_INTERFACES = "eth1 eth2",
  ONEAPP_VNF_DHCP4_ETH1_GATEWAY = "192.168.101.1",
  ONEAPP_VNF_DHCP4_ETH2_GATEWAY = "192.168.102.1",
  ONEAPP_VNF_SDNAT4_ENABLED = "YES",
  ONEAPP_VNF_LB_ENABLED = "YES",
  ONEAPP_VNF_LB_REFRESH_RATE = "5",
  ONEAPP_VNF_LB_FWMARK_OFFSET = "2000",
  ONEAPP_VNF_WG_ENABLED       = "YES",
  ONEAPP_VNF_WG_INTERFACE_OUT = "eth0",
  ONEAPP_VNF_WG_INTERFACE_IN  = "eth1",
  ONEAPP_VNF_WG_PEERS         = "3",
  ONEAPP_VNF_HAPROXY_ENABLED = "YES",
  ONEAPP_VNF_HAPROXY_REFRESH_RATE = "5",
  PASSWORD = "debugtest" ]
#{VNF_CONTEXT_NETWORK}
EOT

VNF_CONTEXT_VM_TEST3 = <<-EOT
CONTEXT = [
  ONEAPP_VNF_KEEPALIVED_VRID = "86",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_DNS_INTERFACES = "eth1 eth2",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth0",
  ONEAPP_VNF_KEEPALIVED_ENABLED = "NO",
  ONEAPP_VNF_LB_ENABLED = "YES",
  ONEAPP_VNF_LB_REFRESH_RATE = "5",
  ONEAPP_VNF_LB_FWMARK_OFFSET = "2000",
  ONEAPP_VNF_HAPROXY_ENABLED = "NO",
  PASSWORD = "debugtest" ]
#{VNF_CONTEXT_NETWORK}
EOT

VNF_CONTEXT_VM_TEST4 = <<-EOT
CONTEXT = [
  ONEAPP_VNF_KEEPALIVED_VRID = "86",
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_DNS_INTERFACES = "eth1 eth2",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth0",
  ONEAPP_VNF_KEEPALIVED_ENABLED = "NO",
  ONEAPP_VNF_LB_ENABLED = "NO",
  ONEAPP_VNF_HAPROXY_ENABLED = "YES",
  ONEAPP_VNF_HAPROXY_REFRESH_RATE = "5",
  PASSWORD = "debugtest" ]
#{VNF_CONTEXT_NETWORK}
EOT

VNF_CONTEXT_VM_UPDATE1 = {
  'ONEAPP_VNF_DNS_USE_ROOTSERVERS' => 'NO',
  'ONEAPP_VNF_DHCP4_LEASE_TIME' => "666"
}

VNF_CONTEXT_VM_UPDATE3 = {
  'ONEAPP_VNF_LB0_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_LB0_PROTOCOL' => "TCP",
  'ONEAPP_VNF_LB0_PORT' => "8080",
  'ONEAPP_VNF_LB0_TIMEOUT' => "3",
  'ONEAPP_VNF_LB0_SCHEDULER' => "rr",
  'ONEAPP_VNF_LB0_SERVER0_HOST' => "192.168.101.100",
  'ONEAPP_VNF_LB0_SERVER0_PORT' => "8080",
  'ONEAPP_VNF_LB0_SERVER1_HOST' => "192.168.102.100",
  'ONEAPP_VNF_LB0_SERVER1_PORT' => "8080",
  'ONEAPP_VNF_LB1_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_LB1_PROTOCOL' => "UDP",
  'ONEAPP_VNF_LB1_PORT' => "3001",
  'ONEAPP_VNF_LB1_TIMEOUT' => "3",
  'ONEAPP_VNF_LB1_SCHEDULER' => "rr",
  'ONEAPP_VNF_LB2_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_LB2_PROTOCOL' => "both",
  'ONEAPP_VNF_LB2_PORT' => "3002",
  'ONEAPP_VNF_LB2_TIMEOUT' => "3",
  'ONEAPP_VNF_LB2_SCHEDULER' => "rr"
}

VNF_CONTEXT_VM_UPDATE5 = {
  'ONEAPP_VNF_LB0_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_LB0_PROTOCOL' => "TCP",
  'ONEAPP_VNF_LB0_PORT' => "8080",
  'ONEAPP_VNF_LB0_TIMEOUT' => "3",
  'ONEAPP_VNF_LB0_SCHEDULER' => "rr",
  'ONEAPP_VNF_LB1_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_LB1_PROTOCOL' => "TCP",
  'ONEAPP_VNF_LB1_PORT' => "3002",
  'ONEAPP_VNF_LB1_TIMEOUT' => "3",
  'ONEAPP_VNF_LB1_SCHEDULER' => "rr",
}

VNF_CONTEXT_VM_UPDATE6 = {
  'ONEAPP_VNF_HAPROXY_LB0_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_HAPROXY_LB0_PORT' => "8080",
  'ONEAPP_VNF_HAPROXY_LB0_SERVER0_HOST' => "192.168.101.100",
  'ONEAPP_VNF_HAPROXY_LB0_SERVER0_PORT' => "8080",
  'ONEAPP_VNF_HAPROXY_LB0_SERVER1_HOST' => "192.168.102.100",
  'ONEAPP_VNF_HAPROXY_LB0_SERVER1_PORT' => "8080",
  'ONEAPP_VNF_HAPROXY_LB1_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_HAPROXY_LB1_PORT' => "3001",
  'ONEAPP_VNF_HAPROXY_LB2_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_HAPROXY_LB2_PORT' => "3002",
}

VNF_CONTEXT_VM_UPDATE8 = {
  'ONEAPP_VNF_HAPROXY_LB0_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_HAPROXY_LB0_PORT' => "8080",
  'ONEAPP_VNF_HAPROXY_LB1_IP' => "%VNF_PUBLIC_IP%",
  'ONEAPP_VNF_HAPROXY_LB1_PORT' => "3002",
}

# AS VROUTER TEMPLATE

VROUTER_TEMPLATE_FULL1 = <<-EOT
NAME = vrouter-test
KEEPALIVED_ID = 1
NIC = [
  NETWORK = "public" ]
NIC = [
  NETWORK = "vnet_a",
  FLOATING_IP="YES",
  IP = "%VNET_A_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_b",
  FLOATING_IP="YES",
  IP = "%VNET_B_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_mgt",
  VROUTER_MANAGEMENT="YES" ]
EOT

VROUTER_TEMPLATE_FULL2 = <<-EOT
NAME = vrouter-test
KEEPALIVED_ID = 2
NIC = [
  NETWORK = "public" ]
NIC = [
  NETWORK = "vnet_dmz",
  IP = "%VNET_DMZ_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_a",
  IP = "%VNET_A_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_b",
  IP = "%VNET_B_GATEWAY%" ]
EOT

VROUTER_TEMPLATE_FULL3 = <<-EOT
NAME = vrouter-test
KEEPALIVED_ID = 2
NIC = [
  NETWORK = "public" ]
NIC = [
  NETWORK = "vnet_a",
  IP = "%VNET_A_GATEWAY%" ]
NIC = [
  NETWORK = "vnet_b",
  IP = "%VNET_B_GATEWAY%" ]
EOT

VROUTER_TEMPLATE_BARE1 = <<-EOT
NAME = vrouter-test
KEEPALIVED_ID = 123
KEEPALIVED_PASSWORD = asd123
NIC = [
  NETWORK = "public" ]
EOT

VNF_CONTEXT_VROUTER_LEGACY1 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  PASSWORD = "debugtest"
  ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_LEGACY2 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_SDNAT1 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED     = "YES",
  ONEAPP_VNF_SDNAT4_ENABLED      = "YES",
  ONEAPP_VNF_SDNAT4_REFRESH_RATE = "1",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_SDNAT2 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED     = "YES",
  ONEAPP_VNF_SDNAT4_ENABLED      = "YES",
  ONEAPP_VNF_SDNAT4_INTERFACES   = "eth1 eth2",
  ONEAPP_VNF_SDNAT4_REFRESH_RATE = "1",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_SDNAT3 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED     = "YES",
  ONEAPP_VNF_NAT4_ENABLED        = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth1",
  ONEAPP_VNF_SDNAT4_ENABLED      = "YES",
  ONEAPP_VNF_SDNAT4_INTERFACES   = "eth1 eth2",
  ONEAPP_VNF_SDNAT4_REFRESH_RATE = "1",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_SDNAT4 = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED     = "YES",
  ONEAPP_VNF_SDNAT4_ENABLED      = "YES",
  ONEAPP_VNF_SDNAT4_INTERFACES   = "eth1 eth2 eth3",
  ONEAPP_VNF_SDNAT4_REFRESH_RATE = "1",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_LB = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_DNS_INTERFACES = "eth1 eth2",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth0",
  ONEAPP_VNF_LB_ENABLED = "YES",
  ONEAPP_VNF_LB_ONEGATE_ENABLED = "YES",
  ONEAPP_VNF_LB_REFRESH_RATE = "5",
  ONEAPP_VNF_LB_FWMARK_OFFSET = "2000",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_HAPROXY = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED = "YES",
  ONEAPP_VNF_DNS_ENABLED = "YES",
  ONEAPP_VNF_DNS_INTERFACES = "eth1 eth2",
  ONEAPP_VNF_NAT4_ENABLED = "YES",
  ONEAPP_VNF_NAT4_INTERFACES_OUT = "eth0",
  ONEAPP_VNF_LB_ENABLED = "NO",
  ONEAPP_VNF_HAPROXY_ENABLED = "YES",
  ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED = "YES",
  ONEAPP_VNF_HAPROXY_REFRESH_RATE = "5",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

VNF_CONTEXT_VROUTER_WG = <<-EOT
CONTEXT = [
  NETWORK = "YES",
  SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\",
  TOKEN = "YES",
  REPORT_READY = "YES",
  ONEAPP_VNF_ROUTER4_ENABLED     = "YES",
  ONEAPP_VNF_SDNAT4_ENABLED      = "YES",
  ONEAPP_VNF_SDNAT4_INTERFACES   = "eth1 eth2",
  ONEAPP_VNF_SDNAT4_REFRESH_RATE = "1",
  ONEAPP_VNF_WG_ENABLED          = "YES",
  ONEAPP_VNF_WG_INTERFACE_OUT    = "eth0",
  ONEAPP_VNF_WG_INTERFACE_IN     = "eth1",
  ONEAPP_VNF_WG_PEERS            = "3",
  PASSWORD = "debugtest" ]
VROUTER="YES"
EOT

#
# tests
#

shared_examples_for "service_VRouter" do |name, hv|
    #
    # AS VM TEMPLATE
    #

    context "VNF VM Scenario 1: (VNF) - empty context (nothing is running)" do
        include_examples 'deploy_vnf', name, hv, 'vd',
            VNF_CONTEXT_VM_TEST0,
            'http://services/images/alpine-testing.qcow2',
            []

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vnf, 'MASTER'

        # ROUTER4 is disabled
        include_examples 'vnf_router4', :vnf, false, ["eth0"]

        # NAT is disabled
        include_examples 'vnf_nat', :vnf, false

        # DHCP4 is disabled
        include_examples 'vnf_dhcp4_running', :vnf, false

        # DNS is disabled
        include_examples 'vnf_dns_running', :vnf, false

        # LB has no loadbalancer configured
        include_examples 'vnf_lb_is_empty', :vnf

        # HAPROXY has no loadbalancer configured
        include_examples 'vnf_haproxy_is_empty', :vnf

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end
    end

    context "VNF VM Scenario 2: (VNF) - all VNFs enabled (with defaults) including KEEPALIVED" do
        include_examples 'deploy_vnf', name, hv, 'vd',
            VNF_CONTEXT_VM_TEST1,
            'http://services/images/alpine-testing.qcow2',
            []

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vnf, 'MASTER'

        # ROUTER4 is enabled
        include_examples 'vnf_router4', :vnf, true, ["eth0"]

        # NAT is enabled
        include_examples 'vnf_nat', :vnf, true, ["eth0"]

        # DHCP4 is enabled
        include_examples 'vnf_dhcp4_running', :vnf, true

        # DNS is enabled
        include_examples 'vnf_dns_running', :vnf, true, ["eth0"]

        # verify keepalived config
        include_examples 'vnf_keepalived_vrid', :vnf, [86]

        # SDNAT4 is enabled
        include_examples 'vnf_sdnat_running', :vnf, true

        # LB is enabled
        include_examples 'vnf_lb_running', :vnf, true

        # LB has no loadbalancer configured
        include_examples 'vnf_lb_is_empty', :vnf

        # HAPROXY is enabled
        include_examples 'vnf_haproxy_running', :vnf, true

        # HAPROXY has no loadbalancer configured
        include_examples 'vnf_haproxy_is_empty', :vnf
    end

    context "VNF VM Scenario 3: (VNF + vm1, vm2, vm3, vm4) - all VNFs enabled with KEEPALIVED" do
        include_examples 'deploy_vnf', name, hv, 'vd',
            VNF_CONTEXT_VM_TEST2,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_BASIC},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_BASIC},
             {name: 'vm3', net: :vnet_mgt, context: VM_CONTEXT_BASIC},
             {name: 'vm4', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # keepalived should not be running
        include_examples 'vnf_running_keepalived', :vnf, 'MASTER'

        # ROUTER4 is enabled on...
        include_examples 'vnf_router4', :vnf, true, ["eth1", "eth2", "eth4"]

        # ROUTER4 is disabled on...
        include_examples 'vnf_router4', :vnf, false, ["eth0", "eth3"]

        # NAT is enabled on...
        include_examples 'vnf_nat', :vnf, true, ["eth4"]

        # NAT is disabled on...
        include_examples 'vnf_nat', :vnf, false, ["eth0", "eth1", "eth2", "eth3"]

        # NAT outgoing ip packet to vm4 has to have VNF's eth4 address (vnet_dmz)
        include_examples 'vnf_nat_verify', 'vm1', 'vm4', :vnet_dmz
        include_examples 'vnf_nat_verify', 'vm2', 'vm4', :vnet_dmz

        # DNS is enabled on...
        include_examples 'vnf_dns_running', :vnf, true, ["eth1", "eth2", "eth3", "eth4"]

        # DNS is disabled on...
        include_examples "vnf_dns_interfaces", :vnf, false, ["eth0"]

        # DNS resolving via ROOT servers
        include_examples 'vnf_dns_resolv_domain', :vnf, "opennebula.org"
        include_examples 'vnf_dns_resolv_domain', :vnf, "services", false

        # DHCP4 is enabled
        include_examples 'vnf_dhcp4_running', :vnf, true, ["eth1", "eth2"]
        include_examples 'vnf_dhcp4_pool_check', :vnf, :vnet_a
        include_examples 'vnf_dhcp4_pool_check', :vnf, :vnet_b

        # SDNAT4 is enabled
        include_examples 'vnf_sdnat_running', :vnf, true

        # LB is enabled
        include_examples 'vnf_lb_running', :vnf, true

        # LB started with no LBs
        include_examples 'vnf_lb_is_empty', :vnf

        # HAPROXY is enabled
        include_examples 'vnf_haproxy_running', :vnf, true

        # HAPROXY started with no LBs
        include_examples 'vnf_haproxy_is_empty', :vnf

        # validation
        include_examples 'vnf_vm_quadro_vnets_first_verification'

        # update context 1.
        include_examples 'vm_update_context', :vnf, VNF_CONTEXT_VM_UPDATE1

        it 'VNF: wait safe 10s to give the failover a chance to complete' do
            sleep 10
        end

        # validate updated context 1.
        include_examples 'vnf_dhcp4_lease_time_check', :vnf, "666"
        include_examples 'vnf_dns_resolv_domain', :vnf, "opennebula.org"
        include_examples 'vnf_dns_resolv_domain', :vnf, "services"

        # and validate it again...
        include_examples 'vnf_vm_quadro_vnets_first_verification'

        #Wireguard VPN is up
        include_examples 'vnf_wg', :vnf, true, 'vm1'
    end

    context "VNF VM Scenario 4: (VNF + vm1, vm2) - LB enabled with LB[0-9] and static servers" do
        include_examples 'deploy_vnf', name, hv, 'vd',
            VNF_CONTEXT_VM_TEST3,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_NGINX_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_NGINX_WEB_SERVER}
            ]

        # keepalived should not be running
        include_examples 'vnf_running_keepalived', :vnf, 'MASTER'

        # ROUTER4 is enabled on...
        include_examples 'vnf_router4', :vnf, true, ["eth0", "eth1", "eth2"]

        # NAT is enabled on...
        include_examples 'vnf_nat', :vnf, true, ["eth0"]

        # NAT is disabled on...
        include_examples 'vnf_nat', :vnf, false, ["eth1", "eth2"]

        # DNS is enabled on...
        include_examples 'vnf_dns_running', :vnf, true, ["eth1", "eth2"]

        # DNS is disabled on...
        include_examples "vnf_dns_interfaces", :vnf, false, ["eth0"]

        # DHCP4 is disabled
        include_examples 'vnf_dhcp4_running', :vnf, false

        # LB is enabled
        include_examples 'vnf_lb_running', :vnf, true

        # LB started with no LBs
        include_examples 'vnf_lb_is_empty', :vnf

        # update context 3.
        include_examples 'vm_update_context', :vnf, VNF_CONTEXT_VM_UPDATE3

        # validate LBs
        include_examples 'vnf_start_script_workaround_dns', 'vm1'
        include_examples 'vnf_start_script_workaround_dns', 'vm2'
        include_examples 'vnf_lb_verify', :vnf, '8080'
    end

    context "VNF VM Scenario 6: (VNF + vm1, vm2) - HAPROXY enabled with LB[0-9] and static servers" do
        include_examples 'deploy_vnf', name, hv, 'vd',
            VNF_CONTEXT_VM_TEST4,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_NGINX_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_NGINX_WEB_SERVER}
            ]

        # keepalived should not be running
        include_examples 'vnf_running_keepalived', :vnf, 'MASTER'

        # ROUTER4 is enabled on...
        include_examples 'vnf_router4', :vnf, true, ["eth0", "eth1", "eth2"]

        # NAT is enabled on...
        include_examples 'vnf_nat', :vnf, true, ["eth0"]

        # NAT is disabled on...
        include_examples 'vnf_nat', :vnf, false, ["eth1", "eth2"]

        # DNS is enabled on...
        include_examples 'vnf_dns_running', :vnf, true, ["eth1", "eth2"]

        # DNS is disabled on...
        include_examples "vnf_dns_interfaces", :vnf, false, ["eth0"]

        # DHCP4 is disabled
        include_examples 'vnf_dhcp4_running', :vnf, false

        # HAPROXY is enabled
        include_examples 'vnf_haproxy_running', :vnf, true

        # HAPROXY started with no LBs
        include_examples 'vnf_haproxy_is_empty', :vnf

        # update context 3.
        include_examples 'vm_update_context', :vnf, VNF_CONTEXT_VM_UPDATE6

        # validate HAPROXY
        include_examples 'vnf_start_script_workaround_dns', 'vm1'
        include_examples 'vnf_start_script_workaround_dns', 'vm2'
        include_examples 'vnf_haproxy_verify', :vnf, '8080'
    end

    #
    # AS VROUTER TEMPLATE
    #

    # simple legacy vrouter setup with 3 vnets
    context "VNF OLD VROUTER Scenario 1: (VROUTER + vm1, vm2, vm3) - 3 vnets" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_LEGACY1,
            VROUTER_TEMPLATE_FULL1,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_BASIC},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_BASIC},
             {name: 'vm3', net: :vnet_mgt, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # validation
        include_examples 'legacy_vrouter_trio_vnets_verification'

        # verify keepalived config
        include_examples 'vnf_keepalived_vrid', :vrouter, [1]
    end

    # legacy HA vrouter setup starting empty but with 3 vnets added one by one
    # VMs also will start without network connectivity to not steal our IPs...
    context "VNF OLD VROUTER Scenario 2: (2x VROUTER + vm1, vm2, vm3) - 3 vnets" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_LEGACY2,
            VROUTER_TEMPLATE_BARE1,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: nil, context: VM_CONTEXT_BASIC},
             {name: 'vm2', net: nil, context: VM_CONTEXT_BASIC},
             {name: 'vm3', net: nil, context: VM_CONTEXT_BASIC}
            ],
            2

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # attach NIC with vnet_a
        include_examples 'vrouter_attach_nic', :vnet_a, false, true
        include_examples 'wait_for_vrouter', ['vr1', 'vr2']

        # attach NIC with vnet_b
        include_examples 'vrouter_attach_nic', :vnet_b, false, true
        include_examples 'wait_for_vrouter', ['vr1', 'vr2']

        # attach NIC with vnet_mgt
        include_examples 'vrouter_attach_nic', :vnet_mgt, true
        include_examples 'wait_for_vrouter', ['vr1', 'vr2']

        # we can attach NICs to VMs after all vnets have been attached to the
        # vrouter first - so they will not eat our distinguished IP addresses...
        include_examples 'vm_attach_nic', 'vm1', :vnet_a
        include_examples 'vm_attach_nic', 'vm2', :vnet_b
        include_examples 'vm_attach_nic', 'vm3', :vnet_mgt

        # wait for VM contextualization and store IPs
        include_examples 'verify_vms', ['vm1', 'vm2', 'vm3']

        # NOTE: MASTER can flip-flop...
        include_examples 'update_keepalived_master', ['vr1', 'vr2']

        # validation
        include_examples 'legacy_vrouter_trio_vnets_verification'

        # shoot down the keepalived master and simulate the failover (terminates the VM!)
        include_examples 'simulate_failover'

        it 'VROUTER: wait 30s to give the failover a chance to complete' do
            sleep 30
        end

        # validation - again
        include_examples 'legacy_vrouter_trio_vnets_verification'

        # detach NIC with vnet_mgt
        include_examples 'vrouter_detach_nic', :vnet_mgt

        it 'VROUTER: wait 30s to give the failover a chance to complete' do
            sleep 30
        end

        # validation
        include_examples 'legacy_vrouter_duo_vnets_verification'

        # verify keepalived config
        include_examples 'vnf_keepalived_vrid', :vrouter, [123]
        include_examples 'vnf_keepalived_password', :vrouter, ["asd123"]
    end

    # vrouter setup with 3 vnets and nonfunctional SNAT/DNAT (intentionally
    # missing allowed interfaces)
    context "VNF VROUTER Scenario 3: (VROUTER + vm1, vm2 + vm3) - SNAT/DNAT from vnet_dmz to vnet_a (no interfaces)" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_SDNAT1,
            VROUTER_TEMPLATE_FULL2,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm3', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # forwarding is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2", "eth3"]

        # NAT is disabled
        include_examples 'vnf_nat', :vrouter, false

        # add external aliases to vms
        include_examples 'vm_attach_nic_external_alias', 'vm1', :vnet_dmz
        include_examples 'vm_attach_nic_external_alias', 'vm2', :vnet_dmz

        # TODO: you could improve this but refresh rate is 1s and if rules are
        # not there until 10s wait period then something is wrong
        it 'VNF: SDNAT4 - wait safe 10s for potential rules to apply (refresh rate is 1s)' do
            sleep 10
        end

        # we have empty ONEAPP_VNF_SDNAT4_INTERFACES so no alias should work yet

        it 'VNF: SDNAT4 - vm3 does not ping vm1 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:external_alias]}")
            expect(cmd.success?).to be(false)
        end

        it 'VNF: SDNAT4 - vm3 does not ping vm2 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:external_alias]}")
            expect(cmd.success?).to be(false)
        end
    end

    # vrouter setup with 3 vnets and functional SNAT/DNAT to vnet_a only
    context "VNF VROUTER Scenario 4: (VROUTER + vm1, vm2 + vm3) - SNAT/DNAT from vnet_dmz to vnet_a (eth1, eth2)" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_SDNAT2,
            VROUTER_TEMPLATE_FULL2,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm3', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # forwarding is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2", "eth3"]

        # add external aliases to vms
        include_examples 'vm_attach_nic_external_alias', 'vm1', :vnet_dmz
        include_examples 'vm_attach_nic_external_alias', 'vm2', :vnet_dmz

        # TODO: you could improve this but refresh rate is 1s and if rules are
        # not there until 10s wait period then something is wrong
        it 'VNF: SDNAT4 - wait safe 10s for potential rules to apply (refresh rate is 1s)' do
            sleep 10
        end

        it 'VNF: SDNAT4 - vm3 pings vm1 external alias' do
            pp @info['vm1'][:external_alias]
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        # for this ping we would have to add eth3 to ONEAPP_VNF_SDNAT4_INTERFACES

        it 'VNF: SDNAT4 - vm3 does not ping vm2 external alias' do
            pp @info['vm2'][:external_alias]
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:external_alias]}")
            expect(cmd.success?).to be(false)
        end

        # verify that we actually get to the vm via external alias
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_sdnat_verify', 'vm3', 'vm1'
    end

    # vrouter setup with 3 vnets and functional SNAT/DNAT to vnet_a and NAT
    context "VNF VROUTER Scenario 5: (VROUTER + vm1, vm2 + vm3) - SNAT/DNAT from vnet_dmz to vnet_a (eth1, eth2) *AND* NAT on vnet_dmz" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_SDNAT3,
            VROUTER_TEMPLATE_FULL2,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm3', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # forwarding is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2", "eth3"]

        # NAT is enabled
        include_examples 'vnf_nat', :vrouter, true, ["eth1"]

        # add external aliases to vms
        include_examples 'vm_attach_nic_external_alias', 'vm1', :vnet_dmz
        include_examples 'vm_attach_nic_external_alias', 'vm2', :vnet_dmz

        # TODO: you could improve this but refresh rate is 1s and if rules are
        # not there until 10s wait period then something is wrong
        it 'VNF: SDNAT4 - wait safe 10s for potential rules to apply (refresh rate is 1s)' do
            sleep 10
        end

        it 'VNF: SDNAT4 - vm3 pings vm1 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        # for this ping we would have to add eth3 to ONEAPP_VNF_SDNAT4_INTERFACES

        it 'VNF: SDNAT4 - vm3 does not ping vm2 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:external_alias]}")
            expect(cmd.success?).to be(false)
        end

        # verify that we actually get to the vm via external alias
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_sdnat_verify', 'vm3', 'vm1'

        # NAT is enabled and still works
        include_examples 'vnf_nat_verify', 'vm2', 'vm3', :vnet_dmz
    end

    # vrouter setup with 3 vnets and SNAT/DNAT from and to the vnet with aliases (vnet_dmz)
    context "VNF VROUTER Scenario 6: (VROUTER + vm1, vm2 + vm3) - SNAT/DNAT to vnet_dmz reservations" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_SDNAT4,
            VROUTER_TEMPLATE_FULL2,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm3', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # forwarding is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2", "eth3"]

        # add external aliases to vms
        include_examples 'vm_attach_nic_external_alias', 'vm1', :vnet_dmz_reserved1
        include_examples 'vm_attach_nic_external_alias', 'vm2', :vnet_dmz_reserved2

        # TODO: you could improve this but refresh rate is 1s and if rules are
        # not there until 10s wait period then something is wrong
        it 'VNF: SDNAT4 - wait safe 10s for potential rules to apply (refresh rate is 1s)' do
            sleep 10
        end

        it 'VNF: SDNAT4 - vm3 pings vm1 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        it 'VNF: SDNAT4 - vm3 pings vm2 external alias' do
            cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        # verify that we actually get to the vm via external alias
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_sdnat_verify', 'vm3', 'vm1'
        include_examples 'vnf_sdnat_verify', 'vm3', 'vm2'
    end

    # vrouter setup with 2+1 vnets and SNAT/DNAT from and to the vnet with aliases (vnet_dmz)
    context "VNF VROUTER Scenario 7: (VROUTER + vm1, vm2, vm3 + vm4) - SNAT/DNAT from vnet_dmz reservation" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_SDNAT4,
            VROUTER_TEMPLATE_FULL3,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm3', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm4', net: :vnet_dmz, context: VM_CONTEXT_BASIC}
            ]

        #it 'DEBUG: sleep for 5 minutes' do
        #    sleep 300
        #end

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # attach NIC with vnet_dmz
        include_examples 'vrouter_attach_nic', :vnet_dmz, false, false
        include_examples 'wait_for_vrouter', ['vr1']

        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # forwarding is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2", "eth3"]

        # add external aliases to vms
        include_examples 'vm_attach_nic_external_alias', 'vm1', :vnet_dmz_reserved1
        include_examples 'vm_attach_nic_external_alias', 'vm2', :vnet_dmz_reserved2
        include_examples 'vm_attach_nic_external_alias', 'vm3', :vnet_dmz

        # TODO: you could improve this but refresh rate is 1s and if rules are
        # not there until 10s wait period then something is wrong
        it 'VNF: SDNAT4 - wait safe 10s for potential rules to apply (refresh rate is 1s)' do
            sleep 10
        end

        it 'VNF: SDNAT4 - vm4 pings vm1 external alias' do
            cmd = @info['vm4'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        it 'VNF: SDNAT4 - vm4 pings vm2 external alias' do
            cmd = @info['vm4'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        it 'VNF: SDNAT4 - vm4 pings vm3 external alias' do
            cmd = @info['vm4'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm3'][:external_alias]}")
            expect(cmd.success?).to be(true)
        end

        # verify that we actually get to the vm via external alias
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_start_script_workaround_nodns', 'vm3'
        include_examples 'vnf_sdnat_verify', 'vm4', 'vm1'
        include_examples 'vnf_sdnat_verify', 'vm4', 'vm2'
        include_examples 'vnf_sdnat_verify', 'vm4', 'vm3'
    end

    context "VNF VROUTER Scenario 8: (VROUTER + vm1, vm2) - LB enabled with LB[0-9] and dynamic servers" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_LB,
            VROUTER_TEMPLATE_FULL3,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER}
            ]

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # ROUTER4 is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2"]

        # NAT is enabled on...
        include_examples 'vnf_nat', :vrouter, true, ["eth0"]

        # NAT is disabled on...
        include_examples 'vnf_nat', :vrouter, false, ["eth1", "eth2"]

        # DNS is enabled on...
        include_examples 'vnf_dns_running', :vrouter, true, ["eth1", "eth2"]

        # DNS is disabled on...
        include_examples "vnf_dns_interfaces", :vrouter, false, ["eth0"]

        # DHCP4 is disabled
        include_examples 'vnf_dhcp4_running', :vrouter, false

        # LB is enabled
        include_examples 'vnf_lb_running', :vrouter, true

        # LB started with no LBs
        include_examples 'vnf_lb_is_empty', :vrouter

        # update context 3.
        include_examples 'vm_update_context', 'vr1', VNF_CONTEXT_VM_UPDATE5

        # populate dynamic real servers
        include_examples 'vnf_lb_setup_dynamic_real_server', 'vr1', 'vm1', 0, 'tcp', '8080', '8080'
        include_examples 'vnf_lb_setup_dynamic_real_server', 'vr1', 'vm1', 1, 'tcp', '3002', '8080'
        include_examples 'vnf_lb_setup_dynamic_real_server', 'vr1', 'vm2', 0, 'tcp', '8080', '8080'
        include_examples 'vnf_lb_setup_dynamic_real_server', 'vr1', 'vm2', 1, 'tcp', '3002', '8080'

        # verify that we can actually use the load-balancer
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_lb_verify', 'vr1', '8080'
        include_examples 'vnf_lb_verify', 'vr1', '3002'
    end

    context "VNF VROUTER Scenario 9: (VROUTER + vm1, vm2) - HAPROXY enabled with LB[0-9] and dynamic servers" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_HAPROXY,
            VROUTER_TEMPLATE_FULL3,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_SIMPLE_WEB_SERVER},
             {name: 'vm2', net: :vnet_b, context: VM_CONTEXT_SIMPLE_WEB_SERVER}
            ]

        # wait for keepalived
        include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

        # ROUTER4 is enabled on...
        include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2"]

        # NAT is enabled on...
        include_examples 'vnf_nat', :vrouter, true, ["eth0"]

        # NAT is disabled on...
        include_examples 'vnf_nat', :vrouter, false, ["eth1", "eth2"]

        # DNS is enabled on...
        include_examples 'vnf_dns_running', :vrouter, true, ["eth1", "eth2"]

        # DNS is disabled on...
        include_examples "vnf_dns_interfaces", :vrouter, false, ["eth0"]

        # DHCP4 is disabled
        include_examples 'vnf_dhcp4_running', :vrouter, false

        # HAPROXY is enabled
        include_examples 'vnf_haproxy_running', :vrouter, true

        # HAPROXY started with no LBs
        include_examples 'vnf_haproxy_is_empty', :vrouter

        # update context 3.
        include_examples 'vm_update_context', 'vr1', VNF_CONTEXT_VM_UPDATE8

        # populate dynamic backend servers
        include_examples 'vnf_haproxy_setup_dynamic_backend_server', 'vr1', 'vm1', 0, 'tcp', '8080', '8080'
        include_examples 'vnf_haproxy_setup_dynamic_backend_server', 'vr1', 'vm1', 1, 'tcp', '3002', '8080'
        include_examples 'vnf_haproxy_setup_dynamic_backend_server', 'vr1', 'vm2', 0, 'tcp', '8080', '8080'
        include_examples 'vnf_haproxy_setup_dynamic_backend_server', 'vr1', 'vm2', 1, 'tcp', '3002', '8080'

        # verify that we can actually use the load-balancer
        include_examples 'vnf_start_script_workaround_nodns', 'vm1'
        include_examples 'vnf_start_script_workaround_nodns', 'vm2'
        include_examples 'vnf_haproxy_verify', 'vr1', '8080'
        include_examples 'vnf_haproxy_verify', 'vr1', '3002'
    end

    context "VNF VROUTER Scenario 3: (VROUTER + vm1) - Wireguard VPN to vnet_a" do
        include_examples 'deploy_vrouter', name, hv, 'vd',
            VNF_CONTEXT_VROUTER_WG,
            VROUTER_TEMPLATE_FULL1,
            'http://services/images/alpine-testing.qcow2',
            [{name: 'vm1', net: :vnet_a, context: VM_CONTEXT_BASIC}],
            3

        include_examples 'vnf_wg', :vrouter, true, 'vm1'
    end
end
