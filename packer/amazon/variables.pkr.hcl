variable "appliance_name" {
  type    = string
  default = "amazon"
}

variable "version" {
  type    = string
  default = "2"
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

variable "amazon" {
  type   = map(map(string))

  default = {
    "2" = {
	               # navigate via https://cdn.amazonlinux.com/os-images/latest/kvm/
      iso_url      = "https://cdn.amazonlinux.com/os-images/2.0.20231101.0/kvm/amzn2-kvm-2.0.20231101.0-x86_64.xfs.gpt.qcow2"
      iso_checksum = "file:https://cdn.amazonlinux.com/os-images/2.0.20231101.0/kvm/SHA256SUMS"
    }
  }
}
