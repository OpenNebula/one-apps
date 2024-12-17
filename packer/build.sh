#!/bin/bash
DISTRO_NAME=$1                           # e.g. debian
DISTRO_VER=$2                            # e.g. 11
DISTRO=${DISTRO_NAME}${DISTRO_VER}       # e.g. debian11
DST=$3                                   # e.g. export/debian11-6.6.1-1.qcow2
INPUT_DIR="$(dirname "$0")/$DISTRO_NAME" # e.g. packer/debian
OUTPUT_DIR="$DIR_BUILD/$DISTRO"          # e.g. build/debian11 (working dir)
mkdir -p "$OUTPUT_DIR"
ARCH='x86_64'

if [[ "$DISTRO_VER" =~ "arch64" ]]; then
    ARCH='aarch64'
fi

packer init "$INPUT_DIR"

packer build -force \
    -var "appliance_name=${DISTRO}" \
    -var "version=${DISTRO_VER}" \
    -var "input_dir=${INPUT_DIR}" \
    -var "output_dir=${OUTPUT_DIR}" \
    -var "headless=${PACKER_HEADLESS}" \
    -var "arch=${ARCH}" \
    "$INPUT_DIR"                       # loads all *.pkr.hcl from dir

# delete potential temporary cloud-init files
rm -rf "$INPUT_DIR"/"$DISTRO"-cloud-init.iso  \
       "$INPUT_DIR"/"$DISTRO"-context.iso  \
       "$INPUT_DIR"/context/

# convert to the export dir and compress
qemu-img convert -c -O qcow2 "$OUTPUT_DIR/$DISTRO" "$DST"

# delete workig directory
rm -rf "$OUTPUT_DIR"
