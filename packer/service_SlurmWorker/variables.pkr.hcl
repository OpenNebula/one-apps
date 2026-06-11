variable "nvidia_driver_path" {
  type    = string
  default = ""
}

variable "SlurmWorker" {
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
