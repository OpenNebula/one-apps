#!/usr/bin/env bash

set -eo pipefail

GOCA_SRC_URL="$1"
PATH_SRC='/var/lib/one/readiness/spec/functionality/terraform/goca-src'

trap "rm -rf '$PATH_SRC/'" EXIT

if ! go version; then
    eval "$(curl -fsSL https://raw.githubusercontent.com/travis-ci/gimme/master/gimme | GIMME_GO_VERSION=1.18 bash)"
fi

install -d "$PATH_SRC/"

curl -fsSL "$GOCA_SRC_URL" | tar -xzf- --strip-components=1 -C "$PATH_SRC/"

cd "$PATH_SRC/src/goca/"

export GOFLAGS='-buildvcs=false'
export OPENNEBULA_ENDPOINT='http://localhost:2633/RPC2'
export OPENNEBULA_USERNAME='oneadmin'
export OPENNEBULA_PASSWORD='opennebula'
export OPENNEBULA_FLOW_ENDPOINT='http://localhost:2474'
export TF_ACC=1

go get gopkg.in/check.v1
go test ./ -v -timeout 120m
