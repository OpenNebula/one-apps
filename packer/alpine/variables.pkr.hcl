variable "appliance_name" {
  type    = string
  default = "alpine"
}

variable "version" {
  type    = string
  default = "316"
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

variable "alpine" {
  type = map(map(string))

  default = {
    "316" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-virt-3.16.7-x86_64.iso"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-virt-3.16.7-x86_64.iso.sha256"
    }

    "317" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-virt-3.17.5-x86_64.iso"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-virt-3.17.5-x86_64.iso.sha256"
    }

    "318" = {
      iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-virt-3.18.4-x86_64.iso"
      iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-virt-3.18.4-x86_64.iso.sha256"
    }
  }
}
