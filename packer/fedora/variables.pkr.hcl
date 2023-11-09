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
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/37/Cloud/x86_64/images/Fedora-Cloud-37-1.7-x86_64-CHECKSUM"
    }
    "38" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-38-1.6-x86_64-CHECKSUM"
    }
  }
}
