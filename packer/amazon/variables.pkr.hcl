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
      iso_url      = "https://cdn.amazonlinux.com/os-images/2.0.20231020.1/kvm/amzn2-kvm-2.0.20231020.1-x86_64.xfs.gpt.qcow2"
      iso_checksum = "01d411368e724b6bc5fa448c4a97cc7641fcf0da6e8bba00543310681fa2cd2a"
    }
  }
}
