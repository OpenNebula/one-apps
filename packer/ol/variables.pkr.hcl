variable "appliance_name" {
  type    = string
  default = "ol"
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

variable "ol" {
  type   = map(map(string))

  default = {
    "8" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL8/u8/x86_64/OL8U8_x86_64-kvm-b198.qcow"
      iso_checksum = "67b644451efe5c9c472820922085cb5112e305fedfb5edb1ab7020b518ba8c3b"
    }

    "9" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b197.qcow"
      iso_checksum = "840345cb866837ac7cc7c347cd9a8196c3a17e9c054c613eda8c2a912434c956"
    }
  }
}
