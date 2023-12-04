#!/usr/bin/env bash

# Configures critical settings for OpenSSH server.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "PasswordAuthentication no" }
/^[#\s]*PasswordAuthentication\s*/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "PermitRootLogin without-password" }
/^[#\s]*PermitRootLogin\s*/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "UseDNS no" }
/^[#\s]*UseDNS\s*/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "AllowTcpForwarding yes" }
/^[#\s]*AllowTcpForwarding\s*/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "AllowAgentForwarding yes" }
/^[#\s]*AllowAgentForwarding\s*/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

sync
