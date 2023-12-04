#!/usr/bin/env bash

set -eu -o pipefail; shopt -qs failglob

find . -type f -name 'tests.rb' | while read FILE; do
    (cd $(dirname "$FILE")/ && echo ">> $FILE <<" && rspec $(basename "$FILE"))
done
