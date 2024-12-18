variable "appliance_name" {
  type    = string
  default = "ubuntu"
}

variable "version" {
  type    = string
  default = "2004"
}

variable "input_dir" {
  type = string
}

variable "output_dir" {
  type = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "ubuntu" {
  type = map(map(string))

  default = {
    "2204" = {
      iso_url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
    }
    "2204.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS"
    }

    "2204min" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/jammy/release/SHA256SUMS"
    }
    "2204min.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/jammy/release/SHA256SUMS"
    }

    "2404" = {
      iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
    }
    "2404.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
    }

    "2404min" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/noble/release/SHA256SUMS"
    }
    "2404min.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/noble/release/SHA256SUMS"
    }
  }
}
