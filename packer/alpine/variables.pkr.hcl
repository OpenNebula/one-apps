variable "alpine" {
  type = map(map(string))

  default = {
    "318.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "318.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/cloud/nocloud_alpine-3.18.9-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "319.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.6-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.6-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "319.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.6-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.6-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "320.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.5-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.5-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "320.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.5-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.5-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "321.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.2-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "321.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.2-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.2-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }
  }
}
