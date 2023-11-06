#!/usr/bin/env bash

# Configures critical settings for OpenSSH server.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

gawk -i inplace -f- /etc/ssh/sshd_config /etc/ssh/sshd_config.d/50-redhat.conf <<'EOF'
BEGIN { update = "PasswordAuthentication no" }
/^[#\s]*PasswordAuthentication\s*/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "PermitRootLogin without-password" }
/^[#\s]*PermitRootLogin\s*/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "UseDNS no" }
/^[#\s]*UseDNS\s*/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF

rm -rf /etc/ssh/sshd_config.d/50-cloud-init.conf

sync
