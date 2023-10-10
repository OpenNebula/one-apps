variable "appliance_name" {
  type    = string
  default = "alt"
}

variable "version" {
  type    = string
  default = "9"
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

variable "alt" {
  type   = map(map(string))

  default = {
    "9" = {
      iso_url      = "https://mirror.yandex.ru/altlinux/p9/images/cloud/x86_64/alt-p9-cloud-x86_64.qcow2"
      iso_checksum = "f3837a01518003f4ecaeca4148c3a1c5904a4657f72d9b55d6e8bd0903ca270f"
    }

    "10" = {
      iso_url      = "https://mirror.yandex.ru/altlinux/p10/images/cloud/x86_64/alt-p10-cloud-x86_64.qcow2"
      iso_checksum = "c20730ca87b8cb026ced7dd254abce05cd0deb33f60f4dab6c17968f8bc968d5"
    }
  }
}
