#!/usr/bin/env bash

# Set kernel command line (net.ifnames=0 is particularily important),
# then update initramfs/initrd and grub2.

exec 1>&2
set -eux -o pipefail

rm -rf /etc/default/grub.d/

# Drop unwanted.

gawk -i inplace -f- /etc/default/grub <<'EOF'
/^GRUB_CMDLINE_LINUX_DEFAULT=/ { gsub(/\<quiet\>/, "") }
/^GRUB_CMDLINE_LINUX_DEFAULT=/ { gsub(/\<splash\>/, "") }
/^GRUB_CMDLINE_LINUX_DEFAULT=/ { gsub(/\<console=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX_DEFAULT=/ { gsub(/\<earlyprintk=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX_DEFAULT=/ { gsub(/\<crashkernel=[^ ]*\>/, "crashkernel=no") }
{ print }
EOF

# Ensure required.

gawk -i inplace -f- /etc/default/grub <<'EOF'
/^GRUB_CMDLINE_LINUX=/ { found = 1 }
/^GRUB_CMDLINE_LINUX=/ && !/net.ifnames=0/ { gsub(/"$/, " net.ifnames=0\"") }
/^GRUB_CMDLINE_LINUX=/ && !/biosdevname=0/ { gsub(/"$/, " biosdevname=0\"") }
{ print }
ENDFILE { if (!found) print "GRUB_CMDLINE_LINUX=\" net.ifnames=0 biosdevname=0\"" }
EOF

gawk -i inplace -f- /etc/default/grub <<'EOF'
BEGIN { update = "GRUB_TIMEOUT=0" }
/^GRUB_TIMEOUT=/ { $0 = update; found = 1 }
{ print }
ENDFILE { if (!found) print update }
EOF

# Cleanup.

gawk -i inplace -f- /etc/default/grub <<'EOF'
{ gsub(/(" *| *")/, "\""); gsub(/  */, " ") }
{ print }
EOF

grub2-mkconfig -o /boot/grub2/grub.cfg

sync
