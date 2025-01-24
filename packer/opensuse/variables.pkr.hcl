variable "appliance_name" {
  type    = string
  default = "opensuse"
}

variable "version" {
  type    = string
  default = "15"
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

variable "opensuse" {
  type = map(map(string))

  default = {
    "15" = {
      iso_url      = "https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2"
      iso_checksum = "37773ac8af27c2d7a710a130ce2ea153ef75a4b2b8904b52de02900ade1545ff"
    }
    "15.aarch64" = {
      iso_url      = "https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.aarch64-Cloud.qcow2"
      iso_checksum = "00cbb55fe0328c0a1c5a61f1a1419b5052b25325d32f1c368767f0dee04c2a57"
    }
  }
}

# Workaround for https://github.com/openSUSE/MirrorCache/issues/528

variable "iso_prefix" {
  type = string
  default = "openSUSE-Leap-15.6-Minimal-VM.x86_64"
}

variable "checksum_file" {
  type = string
  default = "/tmp/checksum.sha256"
}

variable "checksum_url" {
  type = string
  default = "https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2.sha256"
}
