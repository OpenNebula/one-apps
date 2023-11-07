#!/usr/bin/env bash

# Sets kernel command line (net.ifnames=0 is particularily important),
# then updates initramfs/initrd and grub2.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

rm -rf /etc/default/grub.d/

# NOTE: in this old version of OL, gawk does not understand
# the "-i inplace" option.

# Drop unwanted.

gawk -f- /etc/default/grub >/etc/default/grub.new <<'EOF'
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<quiet\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<splash\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<console=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<earlyprintk=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<crashkernel=[^ ]*\>/, "crashkernel=no") }
{ print }
EOF
mv /etc/default/grub{.new,}

# Ensure required.

gawk -f- /etc/default/grub >/etc/default/grub.new <<'EOF'
/^GRUB_CMDLINE_LINUX=/ { found = 1 }
/^GRUB_CMDLINE_LINUX=/ && !/net.ifnames=0/ { gsub(/"$/, " net.ifnames=0\"") }
/^GRUB_CMDLINE_LINUX=/ && !/biosdevname=0/ { gsub(/"$/, " biosdevname=0\"") }
{ print }
END { if (!found) print "GRUB_CMDLINE_LINUX=\" net.ifnames=0 biosdevname=0\"" >> FILENAME }
EOF
mv /etc/default/grub{.new,}

gawk -f- /etc/default/grub >/etc/default/grub.new <<'EOF'
BEGIN { update = "GRUB_TIMEOUT=0" }
/^GRUB_TIMEOUT=/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF
mv /etc/default/grub{.new,}

# Cleanup.

gawk -f- /etc/default/grub >/etc/default/grub.new <<'EOF'
{ gsub(/(" *| *")/, "\""); gsub(/  */, " ") }
{ print }
EOF
mv /etc/default/grub{.new,}

yum install -y dracut-config-generic dracut-network

INITRAMFS_IMG=$(find /boot/ -maxdepth 1 -name 'initramfs-*.img' ! -name '*rescue*' ! -name '*kdump*' | sort -V | tail -1)
INITRAMFS_VER=$(sed -e 's/^.*initramfs-//' -e 's/\.img$//' <<< "$INITRAMFS_IMG")
dracut --force "$INITRAMFS_IMG" "$INITRAMFS_VER"

grub2-mkconfig -o /boot/grub2/grub.cfg

sync