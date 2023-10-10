#!/bin/bash

set -e

export DATE=$(date +%Y%m%d)
TARGETS='msi iso'

for TARGET in $TARGETS; do
	TARGET="${TARGET}" ./generate.sh
done

echo
echo "The packages are here:"
echo "--------------------------------------------------------------------------------"
find out -type f
