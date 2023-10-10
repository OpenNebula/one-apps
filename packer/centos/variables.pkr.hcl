variable "appliance_name" {
  type    = string
  default = "centos"
}

variable "version" {
  type    = string
  default = "7"
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

variable "centos" {
  type   = map(map(string))

  default = {
    "7" = {
      iso_url      = "https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2c"
      iso_checksum = "8540fcfb73b41d2322644b7c4301b52cb1753c6daf9539866214d725870db673"
    }

    "8stream" = {
      iso_url      = "https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
      iso_checksum = "95438a1d3c781871a4bfdedf1d234967f9a70a1119fedbc52c405cb0e7e8a9ad"
    }
  }
}
