variable "appliance_name" {
  type    = string
  default = "ol"
}

variable "version" {
  type    = string
  default = "8"
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

variable "ol" {
  type = map(map(string))

  # navigate via https://yum.oracle.com/oracle-linux-templates.html
  default = {
    "8" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL8/u10/x86_64/OL8U10_x86_64-kvm-b258.qcow2"
      iso_checksum = "9b1f8a4eadc3f6094422674ec0794b292a28ee247593e74fe7310f77ecb8b9b9"
    }

    "9" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL9/u5/x86_64/OL9U5_x86_64-kvm-b259.qcow2"
      iso_checksum = "f1b8f0ca281570dda5e844485d6a300d1a13a629272ffdff4ec84bf56b76b1fc"
    }
  }
}
