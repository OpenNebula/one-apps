#!/usr/bin/env bash

set -xeo pipefail

PATH_SRC='/var/lib/one/readiness/spec/functionality/terraform/terraform-provider-opennebula'

trap "rm -rf $PATH_SRC/" EXIT

if ! go version; then
    eval "$(curl -fsL https://raw.githubusercontent.com/travis-ci/gimme/master/gimme | GIMME_GO_VERSION=1.18 bash)"
fi

install -d "$PATH_SRC/" && cd "$PATH_SRC/"

# Get provider source code
git clone https://github.com/OpenNebula/terraform-provider-opennebula.git .

export GOFLAGS='-buildvcs=false'
export OPENNEBULA_ENDPOINT='http://localhost:2633/RPC2'
export OPENNEBULA_USERNAME='oneadmin'
export OPENNEBULA_PASSWORD='opennebula'
export OPENNEBULA_FLOW_ENDPOINT='http://localhost:2474'
export TF_ACC=1

IFS=';'
VERSIONS="$1"
for VERSION in $VERSIONS; do
    git checkout -- .
    git checkout "$VERSION"

    go install
    go test ./opennebula/ -v -timeout 120m
done
