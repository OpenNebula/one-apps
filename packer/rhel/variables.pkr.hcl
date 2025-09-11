variable "appliance_name" {
  type    = string
  default = "rhel"
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
    "8" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "9" = {
      iso_url      = ""
      iso_checksum = ""
    }

    "10" = {
      iso_url      = ""
      iso_checksum = ""
    }
  }
}
