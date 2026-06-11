variable "nvidia_driver_path" {
  type    = string
  default = ""
}

variable "SlurmWorker" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url = "export/ubuntu2604.qcow2"
    }

    "aarch64" = {
      iso_url = "export/ubuntu2604.aarch64.qcow2"
    }
  }
}
