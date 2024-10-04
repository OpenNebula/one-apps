variable "appliance_name" {
  type    = string
  default = "kubeadm"
}

variable "version" {
  type    = string
  default = "131"
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

variable "kubeadm" {
  type = map(map(string))

  default = {
    "131" = {
      iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
    }
  }
}
