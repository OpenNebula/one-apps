variable "appliance_name" {
  type    = string
  default = "fedora"
}

variable "version" {
  type    = string
  default = "37"
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

variable "fedora" {
  type   = map(map(string))

  default = {
    "37" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/Fedora-Cloud-Base-37-1.7.x86_64.qcow2"
      iso_checksum = "b5b9bec91eee65489a5745f6ee620573b23337cbb1eb4501ce200b157a01f3a0"
    }
    "38" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
      iso_checksum = "d334670401ff3d5b4129fcc662cf64f5a6e568228af59076cc449a4945318482"
    }
  }
}
