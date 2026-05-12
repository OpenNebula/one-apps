variable "devuan" {
  type = map(map(string))

  default = {
    "5.x86_64" = {
      iso_url      = "https://files.devuan.org/devuan_daedalus/installer-iso/devuan_daedalus_5.0.1_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_daedalus/installer-iso/SHA256SUMS.txt"
    }

    "6.x86_64" = {
      iso_url      = "https://files.devuan.org/devuan_excalibur/installer-iso/devuan_excalibur_6.1.1_amd64_server.iso"
      iso_checksum = "file:https://files.devuan.org/devuan_excalibur/installer-iso/SHA256SUMS.txt"
    }
  }
}

variable "boot_cmd" {
  type = map(list(string))

  default = {
    "5" = ["4<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs> url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/devuan5.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
    "6" = ["4<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs> url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/devuan6.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
  }
}
