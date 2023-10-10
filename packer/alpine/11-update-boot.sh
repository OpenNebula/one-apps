#!/usr/bin/env bash

# Updates various settings that require reboot.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

gawk -i inplace -f- /etc/inittab <<'EOF'
/^ttyS/ { $0 = "#" $0 }
{ print }
EOF

gawk -i inplace -f- /boot/extlinux.conf <<'EOF'
BEGIN { update = "TIMEOUT 3" }
/^TIMEOUT\s/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF

sync
