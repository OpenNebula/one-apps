variable "appliance_name" {
  type    = string
  default = "capone"
}

variable "version" {
  type    = string
  default = "131"
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

variable "capone" {
  type = map(map(string))

  default = {
    "x86_64" = {
      iso_url  = "../one-apps/export/ubuntu2204oneke.qcow2"
      arch     = "x86_64"
      alt_arch = "amd64"
    }

    "aarch64" = {
      iso_url  = "../one-apps/export/ubuntu2204oneke.aarch64.qcow2"
      arch     = "aarch64"
      alt_arch = "arm64"
    }
  }
}