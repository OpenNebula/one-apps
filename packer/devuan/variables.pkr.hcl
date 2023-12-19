variable "appliance_name" {
  type    = string
  default = "devuan"
}

variable "version" {
  type    = string
  default = "3"
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

variable "devuan" {
  type = map(map(string))

  default = {
    "3" = {
      iso_url      = "https://files.devuan.org/devuan_beowulf/installer-iso/devuan_beowulf_3.1.1_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_beowulf/installer-iso/SHA256SUMS"
    }

    "4" = {
      iso_url      = "https://files.devuan.org/devuan_chimaera/installer-iso/devuan_chimaera_4.0.0_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_chimaera/installer-iso/SHA256SUMS"
    }
  }
}
