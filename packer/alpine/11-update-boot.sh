#!/usr/bin/env ash

# Update various settings that require reboot.

exec 1>&2
set -eux -o pipefail

gawk -i inplace -f- /etc/inittab <<'EOF'
/^ttyS/ { $0 = "#" $0 }
/^#tty[0-9]/ { sub(/^#/, "") }
{ print }
EOF

if [ "$(arch)" = "x86_64" ]; then
    apk --no-cache add syslinux

    gawk -i inplace -f- /etc/update-extlinux.conf <<'EOF'
/^default_kernel_opts=/ { gsub(/console=ttyS[^ "]*/, "") }
/^default_kernel_opts=/ { gsub(/console=ttyAMA[^ "]*/, "console=tty0") }
{ print }
EOF
    update-extlinux
fi

sync
