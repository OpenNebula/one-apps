#!/usr/bin/env bash

# Configure critical settings for OpenSSH server.

exec 1>&2
set -eux -o pipefail

if [ "${DIST_VER}" -lt "16" ]; then
    gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "PasswordAuthentication no" }
/^[#\s]*PasswordAuthentication\s/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

    gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "ChallengeResponseAuthentication no" }
/^[#\s]*ChallengeResponseAuthentication\s/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

    gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "PermitRootLogin without-password" }
/^[#\s]*PermitRootLogin\s/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

    gawk -i inplace -f- /etc/ssh/sshd_config <<'EOF'
BEGIN { update = "UseDNS no" }
/^[#\s]*UseDNS\s/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF
else
    # Leap 16+ ships sshd_config read-only under /usr/etc; harden via a
    # drop-in (the vendor config Includes /etc/ssh/sshd_config.d/*.conf).
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/90-opennebula.conf <<'EOF'
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin without-password
UseDNS no
EOF
fi
rm -f /etc/ssh/sshd_config.d/*-cloud-init.conf

sync
