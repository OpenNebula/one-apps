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
      #iso_checksum = "file:https://download.opensuse.org/distribution/leap/15.6/appliances/openSUSE-Leap-15.6-Minimal-VM.x86_64-Cloud.qcow2.sha256"
      #TEMP: checksum and images seems not synced
      iso_checksum = "a160a84ec760a8beddaeb09579430851e43ac4c36620191305634a46de640c7a"
    }
  }
}
