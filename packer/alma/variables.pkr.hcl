variable "appliance_name" {
  type    = string
  default = "alma"
}

variable "version" {
  type    = string
  default = "8"
}

variable "input_dir" {
  type    = string
}

variable "output_dir" {
  type    = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "alma" {
  type   = map(map(string))

  default = {
    "8" = {
      iso_url      = "https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
      iso_checksum = "c0ad09255d91288dac590d99c95197d83a2846f1bcbec3f4222fb04265a2a4d7"
    }

    "9" = {
      iso_url      = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
      iso_checksum = "207d885ca8140e3106098e946cfc04088b0e21f50d24815051520d452eae0a50"
    }
  }
}
