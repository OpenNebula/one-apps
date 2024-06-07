variable "appliance_name" {
  type    = string
  default = "devuan"
}

variable "version" {
  type    = string
  default = "4"
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

variable "devuan" {
  type = map(map(string))

  default = {
    "4" = {
      iso_url      = "https://files.devuan.org/devuan_chimaera/installer-iso/devuan_chimaera_4.0.0_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_chimaera/installer-iso/SHA256SUMS"
    }

    "5" = {
      iso_url      = "https://files.devuan.org/devuan_daedalus/installer-iso/devuan_daedalus_5.0.1_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_daedalus/installer-iso/SHA256SUMS.txt"
    }
  }
}

variable "boot_cmd" {
  type = map(list(string))

  default = {
    "3" = ["<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>  auto=true url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/devuan3.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
    "4" = ["<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>  auto=true url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/devuan4.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
    "5" = ["4<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs> url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/devuan5.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
  }
}
