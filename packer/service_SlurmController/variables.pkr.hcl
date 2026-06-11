variable "SlurmController" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/debian13.qcow2"
    }

    "aarch64" = {
      iso_url = "export/debian13.aarch64.qcow2"
    }
  }
}
