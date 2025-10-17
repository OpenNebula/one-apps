variable "alma" {
  type = map(map(string))

  default = {
    "8.x86_64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/CHECKSUM"
    }

    "8.aarch64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/8/cloud/aarch64/images/AlmaLinux-8-GenericCloud-latest.aarch64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/8/cloud/aarch64/images/CHECKSUM"
    }

    "9.x86_64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/CHECKSUM"
    }

    "9.aarch64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/9/cloud/aarch64/images/AlmaLinux-9-GenericCloud-latest.aarch64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/9/cloud/aarch64/images/CHECKSUM"
    }

    "10.x86_64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/AlmaLinux-10-GenericCloud-latest.x86_64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/10/cloud/x86_64/images/CHECKSUM"
    }

    "10.aarch64" = {
      iso_url      = "https://repo.almalinux.org/almalinux/10/cloud/aarch64/images/AlmaLinux-10-GenericCloud-latest.aarch64.qcow2"
      iso_checksum = "file:https://repo.almalinux.org/almalinux/10/cloud/aarch64/images/CHECKSUM"
    }
  }
}
