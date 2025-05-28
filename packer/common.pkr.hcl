packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "1.1.0"
    }
  }
}

variable "arch" {
  type    = string
  default = "x86_64"
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
