variable "appliance_name" {
  type    = string
  default = "debian"
}

variable "version" {
  type    = string
  default = "10"
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

variable "debian" {
  type   = map(map(string))

  default = {
    "10" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/buster/latest/debian-10-generic-amd64.qcow2"
      iso_checksum = "a6293eb7c80ca12cc0c458a540ba11c677e15480f460ad1a271aacda41881687c0486dd80cb5ead7382daa9a93ce6252c72bd5b93a8c44144fc44209a18ac682"
    }
    "11" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
      iso_checksum = "78fe9e9a71fa2d63715a2e156939964b45cfaa5c91b634af1b5a06fa359dd612f027332f65319ec08d4aa204672df95a75812d7a6a016659112b931b4d94f6b6"
    }
    "12" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
      iso_checksum = "b2ddc01e8d13dabbcfde6661541aae92219be2d442653950f0e44613ddebaeb80dc7a83e0202c5509c5e72f4bd1f4edee4c83f35191f2562b3f31e20e9e87ec2"
    }
  }
}
