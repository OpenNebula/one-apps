variable "appliance_name" {
  type    = string
  default = "service_OneKE"
}

variable "input_dir" {
  type = string
}

variable "output_dir" {
  type = string
}

variable "airgapped" {
  type    = string
  default = "NO"
}

variable "headless" {
  type    = bool
  default = false
}

variable "version" {
  type    = string
  default = ""
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
