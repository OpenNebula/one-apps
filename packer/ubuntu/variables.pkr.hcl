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
    "2004" = {
      iso_url      = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/focal/current/SHA256SUMS"
    }

    "2004min" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/minimal/releases/focal/release/SHA256SUMS"
    }
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

    "2204oneke" = {
      iso_url      = "https://cloud-images.ubuntu.com/releases/jammy/release-20241206/ubuntu-22.04-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/releases/jammy/release-20241206/SHA256SUMS"
    }
    "2204oneke.aarch64" = {
      iso_url      = "https://cloud-images.ubuntu.com/releases/jammy/release-20241206/ubuntu-22.04-server-cloudimg-arm64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/releases/jammy/release-20241206/SHA256SUMS"
    }
  }
}
