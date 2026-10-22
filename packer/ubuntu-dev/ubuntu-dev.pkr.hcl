variable "opennebula_version" {
  description = "OpenNebula major.minor version; build dependencies use its initial .0 release."
  type        = string
  default     = "7.4"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.opennebula_version))
    error_message = "Use a major.minor version such as 7.4."
  }
}

# Build cloud init iso
source "null" "null" { communicator = "none" }

build {
  sources = ["sources.null.null"]

  provisioner "shell-local" {
    inline = [
      "cloud-localds ${var.input_dir}/${var.appliance_name}-cloud-init.iso ${var.input_dir}/cloud-init.yml",
    ]
  }
}

locals {
  # Allow room for the source package and installed build dependencies.
  disk_size = 20480
}

# Build VM image
source "qemu" "ubuntu-dev" {
  cpus        = 2
  cpu_model   = "host"
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.ubuntu, "${var.version}.${var.arch}", {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.ubuntu, "${var.version}.${var.arch}", {}), "iso_checksum", "")

  firmware     = lookup(lookup(var.arch_vars, var.arch, {}), "firmware", "")
  use_pflash   = lookup(lookup(var.arch_vars, var.arch, {}), "use_pflash", "")
  machine_type = lookup(lookup(var.arch_vars, var.arch, {}), "machine_type", "")
  qemu_binary  = lookup(lookup(var.arch_vars, var.arch, {}), "qemu_binary", "")

  headless = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  skip_resize_disk = local.disk_size == 0 ? true : false
  disk_size        = local.disk_size == 0 ? null : local.disk_size

  output_directory = var.output_dir

  qemuargs = [
    ["-cdrom", "${var.input_dir}/${var.appliance_name}-cloud-init.iso"],
    ["-serial", "stdio"],
  ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}
