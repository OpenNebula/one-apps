variable "ubuntu" {
  type = map(map(string))

  default = {
    "2204.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
    }
    "2204.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
    }
    "2204min.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/jammy/release/SHA256SUMS"
    }

    "2404.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
    }
    "2404.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
    }
    "2404min.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/noble/release/SHA256SUMS"
    }
    "2404min.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/noble/release/SHA256SUMS"
    }

    "2604.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/resolute/current/SHA256SUMS"
    }
    "2604.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/resolute/current/SHA256SUMS"
    }
    "2604min.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/resolute/release/ubuntu-26.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/resolute/release/SHA256SUMS"
    }
    "2604min.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/resolute/release/ubuntu-26.04-minimal-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/resolute/release/SHA256SUMS"
    }

    "2204oneke.x86_64" = {
      iso_url      = "https://cloud-images.ubuntu.com/releases/jammy/release-20241206/ubuntu-22.04-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/releases/jammy/release-20241206/SHA256SUMS"
    }
    "2204oneke.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/releases/jammy/release-20241206/ubuntu-22.04-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/releases/jammy/release-20241206/SHA256SUMS"
    }
  }
}
