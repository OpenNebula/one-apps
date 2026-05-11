variable "alpine" {
  type = map(map(string))

  default = {
    "320.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.10-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.10-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "320.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.10-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/nocloud_alpine-3.20.10-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "321.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.7-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.7-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "321.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.7-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/nocloud_alpine-3.21.7-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "322.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.4-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.4-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "322.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.4-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.4-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }

    "323.x86_64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.4-x86_64-bios-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.4-x86_64-bios-cloudinit-r0.qcow2.sha512"
    }
    "323.aarch64" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.4-aarch64-uefi-cloudinit-r0.qcow2"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.4-aarch64-uefi-cloudinit-r0.qcow2.sha512"
    }
  }
}
