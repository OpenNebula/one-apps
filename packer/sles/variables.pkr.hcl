variable "sles_regcode" {
  type    = string
  default = false
}

variable "sles_email" {
  type    = string
  default = false
}

variable "sles" {
  type = map(map(string))

  default = {
    "15.x86_64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "15.aarch64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "16.x86_64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "16.aarch64" = {
      iso_url      = ""
      iso_checksum = ""
    }
  }
}
