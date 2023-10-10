variable "appliance_name" {
  type    = string
  default = "alpine"
}

variable "version" {
  type    = string
  default = "316"
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

variable "alpine" {
  type   = map(map(string))

  default = {
    "316" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-virt-3.16.7-x86_64.iso"
      iso_checksum = "6b447e9b2e2ca561c01b03a7b21b6839c718ed85323d2d100ff2e10ea5191470"
    }

    "317" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-virt-3.17.5-x86_64.iso"
      iso_checksum = "d3aec585da8327095edb37b4b7b5eed4623a993196edf12e74641ee5f16291f6"
    }
  }
}
