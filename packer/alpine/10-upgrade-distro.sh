#!/usr/bin/env ash

# Install required packages and upgrade the distro.

exec 1>&2
set -eux -o pipefail

apk --no-cache add bash curl gawk grep jq sed

gawk -i inplace -f- /etc/apk/repositories <<'EOF'
/community$/ && !/edge/ { gsub(/^#\s*/, "") }
{ print }
EOF

apk update
apk upgrade

sync
