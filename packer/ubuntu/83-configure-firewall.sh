#!/bin/bash
set -e

echo "Configuring Firewall and rc.local..."

# 1. Create iptables rules file
cat <<EOF > /etc/iptables.rules
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -s 172.17.0.0/24 -j ACCEPT
-A INPUT -s 172.31.0.0/24 -j ACCEPT
-A INPUT -s 109.126.0.0/22 -j ACCEPT
-A INPUT -s 10.240.230.0/24 -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -j DROP
COMMIT
EOF

# 2. Create /etc/rc.local
cat <<EOF > /etc/rc.local
#!/bin/bash
iptables-restore < /etc/iptables.rules
exit 0
EOF

chmod +x /etc/rc.local

# 3. Rewrite rc-local.service to be non-static and enable it
cat <<EOF > /lib/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable rc-local.service

echo "Firewall configured and rc-local.service activated."
