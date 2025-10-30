variable "KaaS" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/alpine321.qcow2"
    }

    "aarch64" = {
      iso_url = "export/alpine321.aarch64.qcow2"
    }
  }
}
