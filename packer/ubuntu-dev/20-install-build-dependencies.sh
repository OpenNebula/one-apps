#!/usr/bin/env bash

# Match one-infra's packages-build-dependencies role.

exec 1>&2
set -eux -o pipefail

export DEBIAN_FRONTEND=noninteractive

policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

. /etc/os-release
: "${OPENNEBULA_VERSION:?}"
source_version="${OPENNEBULA_VERSION}.0"
package_version="${source_version}-1"
# Use the versioned repository; the major.minor alias moves to newer releases.
repo_url="https://downloads.opennebula.io/repo/${source_version}/Ubuntu/${VERSION_ID}"
dsc_url="${repo_url}/opennebula-${package_version}-amd64/source/opennebula_${package_version}.dsc"

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
cd "$work_dir"

policy_rc_d_disable

apt-get update -y
apt-get install -y ca-certificates devscripts equivs

# The source package requires Node.js 20, supplied by OpenNebula's repository.
# This repository setup is a prerequisite of the one-infra dependency role.
install -d -m 0755 /etc/apt/keyrings
curl --fail --silent --show-error --location \
    https://downloads.opennebula.io/repo/repo2.key \
    -o /etc/apt/keyrings/opennebula.asc
chmod 0644 /etc/apt/keyrings/opennebula.asc
echo "deb [signed-by=/etc/apt/keyrings/opennebula.asc] ${repo_url} stable opennebula" \
    >/etc/apt/sources.list.d/opennebula.list

# Prefer the compatible Node.js package over Ubuntu's newer major versions.
cat >/etc/apt/preferences.d/opennebula-nodejs <<'EOF'
Package: nodejs
Pin: release o=OpenNebula
Pin-Priority: 600
EOF

apt-get update -y

# Derive the full dependency set from the source package's debian/control.
dget -u "$dsc_url"
cd "opennebula-${source_version}"
mk-build-deps -i --tool 'apt-get -y --no-remove -o Debug::pkgProblemResolver=yes'
dpkg-checkbuilddeps

# Ensure the role's gRPC dependencies are present even for older source packages.
apt-get install -y libabsl-dev libgrpc++-dev protobuf-compiler-grpc python3-grpc-tools

policy_rc_d_enable

sync
