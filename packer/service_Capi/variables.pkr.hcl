variable "appliance_name" {
  type    = string
  default = "Capi"
}

variable "input_dir" {
  type = string
}

variable "output_dir" {
  type = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "version" {
  type    = string
  default = ""
}

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