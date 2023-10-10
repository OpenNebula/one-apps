variable "appliance_name" {
  type    = string
  default = "devuan"
}

variable "version" {
  type    = string
  default = "3"
}

variable "input_dir" {
  type    = string
}

variable "output_dir" {
  type    = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "devuan" {
  type   = map(map(string))

  default = {
    "3" = {
      iso_url      = "https://files.devuan.org/devuan_beowulf/installer-iso/devuan_beowulf_3.1.1_amd64_server.iso"
      iso_checksum = "e6e3fc1bdbf626a871d8c27608129c4788623121c8ea059f60607a93c30892de"
    }

    "4" = {
      iso_url      = "https://files.devuan.org/devuan_chimaera/installer-iso/devuan_chimaera_4.0.0_amd64_server.iso"
      iso_checksum = "b2c0d159e9d7219422ef9e40673c3126aee118b57df79484384e7995abd2ba0f"
    }
  }
}
