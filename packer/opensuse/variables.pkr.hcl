variable "opensuse" {
  type = map(map(string))

  default = {
    "15.x86_64" = {
      iso_url      = "https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2"
      iso_checksum = "file:https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2.sha256"
    }
    "15.aarch64" = {
      iso_url      = "https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.aarch64-Cloud.qcow2"
      iso_checksum = "file:https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.aarch64-Cloud.qcow2.sha256"
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
