variable "rocky" {
  type = map(map(string))

  default = {
    "8.x86_64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2.CHECKSUM"
    }
    "8.aarch64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/8/images/aarch64/Rocky-8-GenericCloud.latest.aarch64.qcow2"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/8/images/aarch64/Rocky-8-GenericCloud.latest.aarch64.qcow2.CHECKSUM"
    }

    "9.x86_64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2.CHECKSUM"
    }
    "9.aarch64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/9/images/aarch64/Rocky-9-GenericCloud.latest.aarch64.qcow2"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/9/images/aarch64/Rocky-9-GenericCloud.latest.aarch64.qcow2.CHECKSUM"
    }
  }
}
