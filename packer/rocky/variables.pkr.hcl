variable "appliance_name" {
  type    = string
  default = "rocky"
}

variable "version" {
  type    = string
  default = "8"
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

variable "rocky" {
  type = map(map(string))

  default = {
    "8" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-x86_64-boot.iso"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-x86_64-boot.iso.CHECKSUM"
    }
    "8.aarch64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/8/isos/aarch64/Rocky-aarch64-boot.iso"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/8/isos/aarch64/Rocky-aarch64-boot.iso.CHECKSUM"
    }

    "9" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-x86_64-boot.iso"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-x86_64-boot.iso.CHECKSUM"
    }
    "9.aarch64" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-aarch64-boot.iso"
      iso_checksum = "file:https://download.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-aarch64-boot.iso.CHECKSUM"
    }
  }
}
