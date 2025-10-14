packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "1.1.0"
    }
  }
}

variable "appliance_name" {
  # e.g.: debian13
  type    = string
}

variable "distro" {
  # e.g.: debian
  type = string
}

variable "version" {
  # e.g.: 13
  type    = string
}

variable "arch" {
  type    = string
  default = "x86_64"
}

variable "command_format" {
  type = string
  default = "sudo -iu root {{.Vars}} bash {{.Path}}"
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

variable "arch_vars" {
  type = map(map(string))

  default = {
    "x86_64" = {
      firmware     = null
      use_pflash   = true
      machine_type = "pc"
      qemu_binary  = "/usr/bin/qemu-system-x86_64"
    }

    "aarch64" = {
      firmware     = "/usr/share/AAVMF/AAVMF_CODE.fd"
      use_pflash   = false
      machine_type = "virt,gic-version=max"
      qemu_binary  = "/usr/bin/qemu-system-aarch64"
    }
  }
}
