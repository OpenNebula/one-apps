# Build VM image
source "qemu" "windows" {
  communicator = "none"
  machine_type = "q35"
  efi_boot     = true
  cores        = 8
  memory       = 6192
  accelerator  = "kvm"

  iso_url      = lookup(lookup(var.windows, var.version, {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.windows, var.version, {}), "iso_checksum", "")

  floppy_files = [
    "${path.root}/Run-Scripts.ps1",
    "context-windows/out/one-context-6.8.1.msi"
  ]
  floppy_dirs = [
    "${path.root}/scripts"
    ]
  floppy_content = {
    "Autounattend.xml" = templatefile("autounattend.pkrtpl", {
        edition_name = lookup(lookup(var.windows, var.version, {}), "edition_name", "")
        language = var.language
      }
    )
    "OOBEunattend.xml" = templatefile("OOBEunattend.pkrtpl", {language = var.language})
  }
  headless = var.headless

  boot_command = ["<enter><wait3><enter><wait3><enter><wait3><enter>"]
  boot_wait    = "5s"

  disk_cache     = "unsafe"
  disk_interface = "virtio"
  disk_discard   = "unmap"

  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = "32G"

  output_directory = var.output_dir

  qemuargs = [
    ["-cpu", "host"],
    ["-usb"],
    ["-device", "usb-tablet"],
    ["-cdrom", "packer/windows/iso/virtio-win.iso"]
  ]
  vm_name          = "${var.appliance_name}"
  shutdown_timeout = "8h"
}

build {
  sources = ["source.qemu.windows"]
}
