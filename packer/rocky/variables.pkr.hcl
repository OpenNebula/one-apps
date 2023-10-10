variable "appliance_name" {
  type    = string
  default = "rocky"
}

variable "version" {
  type    = string
  default = "8"
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

variable "rocky" {
  type   = map(map(string))

  default = {
    "8" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/8/isos/x86_64/Rocky-x86_64-boot.iso"
      iso_checksum = "96c9d96c33ebacc8e909dcf8abf067b6bb30588c0c940a9c21bb9b83f3c99868"
    }

    "9" = {
      iso_url      = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-x86_64-boot.iso"
      iso_checksum = "11e42da96a7b336de04e60d05e54a22999c4d7f3e92c19ebf31f9c71298f5b42"
    }
  }
}
