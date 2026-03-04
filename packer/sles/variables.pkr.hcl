variable "sle_regcode" {
  type    = string
  default = false
}

variable "sle_email" {
  type    = string
  default = false
}

variable "sle" {
  type = map(map(string))

  default = {
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
