#!/usr/bin/env bash

# Configure critical settings for OpenSSH server.

exec 1>&2
set -eux -o pipefail

# SLES 16 ships sshd_config read-only under /usr/etc; harden via a drop-in
# (the vendor config Includes /etc/ssh/sshd_config.d/*.conf).
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/90-opennebula.conf <<'EOF'
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin without-password
UseDNS no
EOF

rm -f /etc/ssh/sshd_config.d/*-cloud-init.conf

sync
