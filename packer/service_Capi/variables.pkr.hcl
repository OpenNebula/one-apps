variable "arch_parameter_map" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/ubuntu2204.qcow2"
    }

    "aarch64" = {
      iso_url = "export/ubuntu2204.aarch64.qcow2"
    }
  }
}
