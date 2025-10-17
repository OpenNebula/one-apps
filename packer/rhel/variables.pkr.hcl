variable "rhel_user" {
  type    = string
  default = false
}

variable "rhel_password" {
  type    = string
  default = false
}

variable "rhel" {
  type = map(map(string))

  default = {
    "8.x86_64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "8.aarch64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "9.x86_64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "9.aarch64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "10.x86_64" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "10.aarch64" = {
      iso_url      = ""
      iso_checksum = ""
    }
  }
}
