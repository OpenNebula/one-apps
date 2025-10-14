variable "airgapped" {
  type    = string
  default = "NO"
}

variable "OneKE" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/ubuntu2204oneke.qcow2"
    }

    "aarch64" = {
      iso_url = "export/ubuntu2204oneke.aarch64.qcow2"
    }
  }
}
