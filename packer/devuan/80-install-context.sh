#!/usr/bin/env bash

# Downloads and installs the latest one-context package.

: "${CTX_SUFFIX:=.deb}"

policy_rc_d_disable() (echo "exit 101" >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)
policy_rc_d_enable()  (echo "exit 0"   >/usr/sbin/policy-rc.d && chmod a+x /usr/sbin/policy-rc.d)

exec 1>&2
set -o errexit -o nounset -o pipefail
set -x

export DEBIAN_FRONTEND=noninteractive

if ! stat /context/one-context*$CTX_SUFFIX; then (
    install -d /context/ && cd /context/
    curl -fsSL https://api.github.com/repos/OpenNebula/addon-context-linux/releases \
    | jq -r ".[0].assets[].browser_download_url | select(endswith(\"$CTX_SUFFIX\"))" \
    | xargs -r -n1 curl -fsSLO
) fi

policy_rc_d_disable

dpkg -i /context/one-context*$CTX_SUFFIX || apt-get install -y -f
dpkg -i /context/one-context*$CTX_SUFFIX

apt-get install -y open-vm-tools

policy_rc_d_enable

sync
