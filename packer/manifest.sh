#!/usr/bin/env bash
# Generate a manifest yaml next to the given qcow2 image.
# Usage: manifest.sh <qcow2_path>
#
# VERSION and RELEASE are read from the environment (set by Makefile.config)
# and fall back to parsing Makefile.config directly.

set -e

# Derive FreeBSD's release (e.g. 14.4) from the packer variables
freebsd_release_from_vars() {
    local major="$1" arch="$2" dir url
    command -v packer >/dev/null 2>&1 || return 1
    dir="$(dirname "$0")/freebsd"
    url=$(echo "var.freebsd[\"${major}.${arch}\"].iso_url" | packer console "$dir" 2>/dev/null) || return 1
    printf '%s\n' "$url" | sed -n 's/.*FreeBSD-\([0-9][0-9.]*\)-RELEASE.*/\1/p'
}

DST="$1"
[ -n "$DST" ] || { echo "usage: $0 <qcow2_path>" >&2; exit 2; }
[ -f "$DST" ] || { echo "$0: not a file: $DST" >&2; exit 2; }

# Derive distro + arch from filename: foo[.aarch64].qcow2
BASE=$(basename "$DST" .qcow2)
ARCH='x86_64'
DISTRO="$BASE"
if [[ "$BASE" == *.aarch64 ]]; then
    ARCH='aarch64'
    DISTRO="${BASE%.aarch64}"
fi

# Distro name (strip trailing digits/dots, mirrors top-level Makefile)
DISTRO_NAME=$(echo "$DISTRO" | sed 's/[0-9\.].*//')

# VERSION/RELEASE: from env (Makefile.config exports both) or parse it directly
if [ -z "${VERSION:-}" ] || [ -z "${RELEASE:-}" ]; then
    MKCFG="$(dirname "$0")/../Makefile.config"
    if [ -f "$MKCFG" ]; then
        VERSION=${VERSION:-$(sed -n 's/^VERSION[[:space:]]*:=[[:space:]]*//p' "$MKCFG")}
        RELEASE=${RELEASE:-$(sed -n 's/^RELEASE[[:space:]]*:=[[:space:]]*//p' "$MKCFG")}
    fi
fi
: "${VERSION:?VERSION not set and Makefile.config not readable}"
: "${RELEASE:?RELEASE not set and Makefile.config not readable}"

# Read /etc/os-release from the image
OS_ID=''
OS_RELEASE=''
if OSREL=$(virt-cat -a "$DST" /etc/os-release 2>/dev/null); then
    OS_ID=$(printf '%s\n' "$OSREL" | sed -n 's/^NAME=//p' | sed -e 's/^"//' -e 's/"$//')
    OS_RELEASE=$(printf '%s\n' "$OSREL" | sed -n 's/^VERSION_ID=//p' | sed -e 's/^"//' -e 's/"$//')
fi

# FreeBSD can't be read by virt-cat; derive its release from the packer vars.
if [ -z "$OS_RELEASE" ] && [ "$DISTRO_NAME" = 'freebsd' ]; then
    OS_ID='FreeBSD'
    OS_RELEASE=$(freebsd_release_from_vars "${DISTRO#freebsd}" "$ARCH" || true)
fi

# Display name: service appliances override the OS-derived name
if [[ "$DISTRO_NAME" == service_* ]] || [ "$DISTRO_NAME" = 'capone' ]; then
    NAME="${DISTRO_NAME#service_}"
elif [ -n "$OS_ID" ] && [ -n "$OS_RELEASE" ]; then
    NAME="$OS_ID $OS_RELEASE"
else
    NAME="$DISTRO"
fi

# Hash the image so downstream tools (app2 release) don't have to.
echo "manifest.sh: hashing $DST..."
SHA256=$(sha256sum "$DST" | awk '{print $1}')
MD5=$(md5sum "$DST" | awk '{print $1}')
FILE_SIZE=$(stat -c %s "$DST")

# Virtual disk size in bytes — what the marketplace yaml's images[].size expects
# (qcow2 is sparse, so this differs from the on-disk file size).
VIRTUAL_SIZE=$(qemu-img info "$DST" | sed -n 's/^virtual size: .*(\([0-9]*\) bytes).*/\1/p')

MANIFEST="${DST%.qcow2}.yaml"
cat > "$MANIFEST" <<EOF
name: $NAME
version: ${VERSION}-${RELEASE}-$(date +%Y%m%d)
image: $(basename "$DST")
format: qcow2
size: $VIRTUAL_SIZE
file_size: $FILE_SIZE
sha256: $SHA256
md5: $MD5
creation_time: $(stat -c %Y "$DST")
os-id: $OS_ID
os-release: '$OS_RELEASE'
os-arch: $ARCH
EOF
