#!/usr/bin/env ash

# Update various settings that require reboot.

exec 1>&2
set -eux -o pipefail

gawk -i inplace -f- /etc/inittab <<'EOF'
/^ttyS/ { $0 = "#" $0 }
{ print }
EOF

if [ "$(arch)" = "x86_64" ]; then
    apk --no-cache add syslinux
    gawk -i inplace -f- /boot/extlinux.conf <<'EOF'
BEGIN { update = "TIMEOUT 3" }
/^TIMEOUT\s/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF
fi

sync
