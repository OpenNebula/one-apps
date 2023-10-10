#!/usr/bin/env bash

# Sets kernel command line (net.ifnames=0 is particularily important),
# then updates initramfs/initrd and grub2.

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

rm -rf /etc/default/grub.d/

# Drop unwanted.

gawk -i inplace -f- /etc/sysconfig/grub2 <<'EOF'
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<quiet\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<splash\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<console=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<earlyprintk=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX[^=]*=/ { gsub(/\<crashkernel=[^ ]*\>/, "crashkernel=no") }
{ print }
EOF

# Ensure required.

gawk -i inplace -f- /etc/sysconfig/grub2 <<'EOF'
/^GRUB_CMDLINE_LINUX=/ { found = 1 }
/^GRUB_CMDLINE_LINUX=/ && !/net.ifnames=0/ { gsub(/"$/, " net.ifnames=0\"") }
/^GRUB_CMDLINE_LINUX=/ && !/biosdevname=0/ { gsub(/"$/, " biosdevname=0\"") }
{ print }
END { if (!found) print "GRUB_CMDLINE_LINUX=\" net.ifnames=0 biosdevname=0\"" >> FILENAME }
EOF

gawk -i inplace -f- /etc/sysconfig/grub2 <<'EOF'
BEGIN { update = "GRUB_TIMEOUT=0" }
/^GRUB_TIMEOUT=/ { $0 = update; found = 1 }
{ print }
END { if (!found) print update >> FILENAME }
EOF

# Cleanup.

gawk -i inplace -f- /etc/sysconfig/grub2 <<'EOF'
{ gsub(/(" *| *")/, "\""); gsub(/  */, " ") }
{ print }
EOF

INITRAMFS_IMG=$(find /boot/ -maxdepth 1 -name 'vmlinuz-*' | sort -V | tail -1)
INITRAMFS_VER=$(sed -e 's/^.*vmlinuz-//' <<< "$INITRAMFS_IMG")
make-initrd -k "$INITRAMFS_VER"

update-grub

sync
