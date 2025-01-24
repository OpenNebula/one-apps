variable "appliance_name" {
  type    = string
  default = "fedora"
}

variable "version" {
  type    = string
  default = "39"
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

variable "fedora" {
  type = map(map(string))

  default = {
    "39" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-39-1.5-x86_64-CHECKSUM"
    }
    "39.aarch64" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/aarch64/images/Fedora-Cloud-Base-39-1.5.aarch64.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/39/Cloud/aarch64/images/Fedora-Cloud-39-1.5-aarch64-CHECKSUM"
    }
    "40" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-40-1.14-x86_64-CHECKSUM"
    }
    "40.aarch64" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/aarch64/images/Fedora-Cloud-Base-Generic.aarch64-40-1.14.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/aarch64/images/Fedora-Cloud-40-1.14-aarch64-CHECKSUM"
    }
    "41" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-41-1.4-x86_64-CHECKSUM"
    }
    "41.aarch64" = {
      iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/aarch64/images/Fedora-Cloud-Base-Generic-41-1.4.aarch64.qcow2"
      iso_checksum = "file:https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/aarch64/images/Fedora-Cloud-41-1.4-aarch64-CHECKSUM"
    }
  }
}
