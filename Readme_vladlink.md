docker build -t packer-builder . --network=host
docker run --rm --privileged     -v /dev/kvm:/dev/kvm     -v /boot:/boot:ro     -v /lib/modules:/lib/modules:ro     -v $(pwd):/workspace --network=host     -e CONTEXT_TARGETS='deb iso'     packer-builder     make ubuntu2604
