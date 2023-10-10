#!/usr/bin/env sh

# (Auto)Removes unneeded packages and upgrades
# the distro.

exec 1>&2
set -ex

# Ensure packages needed for post-processing scripts do exist.
apk --no-cache add bash curl gawk grep jq sed

gawk -i inplace -f- /etc/apk/repositories <<'EOF'
/community$/ && !/edge/ { gsub(/^#\s*/, "") }
{ print }
EOF

apk update
apk upgrade

sync
