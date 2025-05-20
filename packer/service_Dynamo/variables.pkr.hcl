variable "appliance_name" {
  type    = string
  default = "Dynamo"
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

variable "nvidia_driver_path" {
  type    = string
  default = ""
}

variable "arch_parameter_map" {
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
