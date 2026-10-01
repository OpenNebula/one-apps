#!/usr/bin/env bash

# Set kernel command line (net.ifnames=0 is particularily important),
# then update initramfs/initrd and grub2.

exec 1>&2
set -eux -o pipefail

rm -rf /etc/default/grub.d/

# Drop unwanted.

# NOTE: console=ttyS*, earlyprintk=ttyS* may cause kernel panic during first boot.
# The exact problem is identical to https://github.com/dmacvicar/terraform-provider-libvirt/issues/948.
# A correct workaround is described here: https://bugs.launchpad.net/ubuntu/+source/cloud-initramfs-tools/+bug/1123220.

gawk -i inplace -f- /etc/default/grub <<'EOF'
/^GRUB_CMDLINE_LINUX=/ { gsub(/\<quiet\>/, "") }
/^GRUB_CMDLINE_LINUX=/ { gsub(/\<splash\>/, "") }
/^GRUB_CMDLINE_LINUX=/ { gsub(/\<console=ttyS[^ ]*\>/, "") }
/^GRUB_CMDLINE_LINUX=/ { gsub(/\<earlyprintk=ttyS[^ ]*\>/, "") }
/^GRUB_TERMINAL=/ { gsub(/\<serial\>/, "") }
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

# Load virtio_net before virtio_pci so that multi-NIC VMs get deterministic
# eth%d names (with virtio_pci as a module udev loads virtio_net concurrently
# with the NIC probing). Inert on kernels with built-in virtio_pci.
echo 'softdep virtio_pci pre: virtio_net' >/etc/modprobe.d/virtio-net-first.conf

update-initramfs -vu
update-grub2

sync
