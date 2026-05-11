#!/usr/bin/env ash

# Update various settings that require reboot.

exec 1>&2
set -eux -o pipefail

# The cloud image's apk upgrade replaces /boot/vmlinuz-virt with a newer
# kernel but leaves /boot/initramfs-virt built for the old one. Force it
# to be rebuilt for the kernel that's actually installed.
for kver in /lib/modules/*; do
    [ -d "$kver/kernel" ] || continue
    mkinitfs -c /etc/mkinitfs/mkinitfs.conf -b / "${kver##*/}"
done

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
/^timeout=/ { sub(/timeout=[0-9]+/, "timeout=1") }
{ print }
EOF
    update-extlinux
fi

sync
