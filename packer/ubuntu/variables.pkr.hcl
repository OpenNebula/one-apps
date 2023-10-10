variable "appliance_name" {
  type    = string
  default = "ubuntu"
}

variable "version" {
  type    = string
  default = "2004"
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

variable "ubuntu" {
  type   = map(map(string))

  default = {
    "2004" = {
      iso_url      = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
      iso_checksum = "bfa805bde8f2d199b8e4a306a3a5823e18b1547833b90d60d8a689e7270e43ff"
    }

    "2004min" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img"
      iso_checksum = "a48ab165c635403c2481d372d9bc8996e7ec93750b3a475b048e861d1caba7aa"
    }

    "2204" = {
      iso_url      = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      iso_checksum = "6bb5247f87919b803c211afd1af74b3096be6e834dac29cfac711dad72eafea8"
    }

    "2204min" = {
      iso_url      = "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img"
      iso_checksum = "afb95ee9e75a46c0d987daae3db5d0d344770004bfa359b1775fcf22cd98ca27"
    }
  }
}
