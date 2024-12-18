variable "appliance_name" {
  type    = string
  default = "debian"
}

variable "version" {
  type    = string
  default = "10"
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

variable "debian" {
  type = map(map(string))

  default = {
    "11" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bullseye/latest/SHA512SUMS"
    }

    "11.aarch64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-generic-arm64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bullseye/latest/SHA512SUMS"
    }

    "12" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bookworm/latest/SHA512SUMS"
    }

    "12.aarch64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bookworm/latest/SHA512SUMS"
    }
  }
}
