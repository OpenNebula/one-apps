#!/usr/bin/env bash
set -eux -o pipefail

####
# This script is used to download NVIDIA drivers from a given URL or copy them
# from a local path to a specified temporary destination directory.
# Arguments:
#   - DRIVERS_PATH: URL or local path to the NVIDIA drivers.
#   - DRIVERS_TMP_DEST_DIR: Temporary directory to store the downloaded drivers.
###


###  Functions

is_url() {
  case "$1" in
    http://*|https://*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

download_drivers() {
    local _url=$1
    local _dest=$2
    if command -v wget > /dev/null 2>&1; then
        wget -P "$_dest" "$_url"
    elif command -v curl > /dev/null 2>&1; then
        curl -fsO --output-dir "$_dest" "$_url"
    else
        echo "Error: No wget or curl binaries installed, unable to download drivers."
        return 1
    fi
}

### Script start

echo "Downloading/copying NVIDIA drivers from $DRIVERS_PATH to $DRIVERS_TMP_DEST_DIR ..."

if [ -z "$DRIVERS_PATH" ]; then
    echo "No driver path specified (DRIVERS_PATH), ignoring NVIDIA drivers installation..."
    exit
fi

if [ -z "$DRIVERS_TMP_DEST_DIR" ]; then
    echo "No temporary destination directory specified (DRIVERS_TMP_DEST_DIR), unable to proceed..."
    exit
fi

mkdir -p "$DRIVERS_TMP_DEST_DIR"

if is_url "$DRIVERS_PATH"; then
    download_drivers "$DRIVERS_PATH" "$DRIVERS_TMP_DEST_DIR"
else
    if [ -f "$DRIVERS_PATH" ]; then
        cp "$DRIVERS_PATH" "$DRIVERS_TMP_DEST_DIR"
    else
        echo "Error: File '$DRIVERS_PATH' does not exist"
        exit 1
    fi
fi
