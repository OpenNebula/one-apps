variable "appliance_name" {
  type    = string
  default = "alpine"
}

variable "version" {
  type    = string
  default = "316"
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

variable "alpine" {
  type = map(map(string))

  default = {
    "318" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "318.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "319" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.4-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.4-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "319.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.4-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.4-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "320" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.3-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.3-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "320.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.3-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.3-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "321" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "321.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.0-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }
  }
}
