variable "VRouter" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/alpine320.qcow2"
    }

    "aarch64" = {
      iso_url = "export/alpine320.aarch64.qcow2"
    }
  }
}
