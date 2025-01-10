variable "appliance_name" {
  type    = string
  default = "service_VRouter"
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
