variable "SlurmController" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/ubuntu2404.qcow2"
    }

    "aarch64" = {
      iso_url = "export/ubuntu2404.aarch64.qcow2"
    }
  }
}
