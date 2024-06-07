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

  default = {
    "8" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL8/u9/x86_64/OL8U9_x86_64-kvm-b219.qcow2"
      iso_checksum = "1ee6715b322b88f57a92b9c19c3c281710c707adaceca2b914f032a4107b99fc"
    }

    "9" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL9/u3/x86_64/OL9U3_x86_64-kvm-b220.qcow2"
      iso_checksum = "20aeb49c7fb1166622c1ed1dce49267f3229a508934cf756180e5ba7ef17eb0c"
    }
  }
}
