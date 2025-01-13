variable "appliance_name" {
  type    = string
  default = "amazon"
}

variable "version" {
  type    = string
  default = "2023"
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

variable "amazon" {
  type = map(map(string))

  default = {
    "2" = {
      # navigate via https://cdn.amazonlinux.com/os-images/latest/kvm/
      iso_url      = "https://cdn.amazonlinux.com/os-images/2.0.20241031.0/kvm/amzn2-kvm-2.0.20241031.0-x86_64.xfs.gpt.qcow2"
      iso_checksum = "file:https://cdn.amazonlinux.com/os-images/2.0.20241031.0/kvm/SHA256SUMS"
    }
    "2023" = {
      # navigate via https://cdn.amazonlinux.com/al2023/os-images/latest/
      iso_url      = "https://cdn.amazonlinux.com/al2023/os-images/2023.6.20250107.0/kvm/al2023-kvm-2023.6.20250107.0-kernel-6.1-x86_64.xfs.gpt.qcow2"
      iso_checksum = "file:https://cdn.amazonlinux.com/al2023/os-images/2023.6.20250107.0/kvm/SHA256SUMS"
    }
  }
}
