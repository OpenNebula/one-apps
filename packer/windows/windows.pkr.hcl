# Build VM image
source "qemu" "windows" {
  communicator = "none"
  machine_type = "q35"
  efi_boot     = true
  cores        = 2
  memory       = 4096
  accelerator  = "kvm"

  iso_url      = lookup(lookup(var.isoFiles, lookup(lookup(var.windows, var.version, {}), "iso", ""), {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.isoFiles, lookup(lookup(var.windows, var.version, {}), "iso", ""), {}), "iso_checksum", "")

  floppy_files = [
    "${path.root}/Run-Scripts.ps1",
    "context-windows/out/one-context-*.msi"
  ]
  floppy_dirs = [
    "${path.root}/scripts"
  ]
  floppy_content = {
    "Autounattend.xml" = templatefile("autounattend.pkrtpl", {
      edition_name = lookup(lookup(var.windows, var.version, {}), "edition_name", "")
      language     = var.language
    })
    "OOBEunattend.xml" = templatefile("OOBEunattend.pkrtpl", {
      language              = var.language
      disable_administrator = var.disable_administrator
    })
  }
  headless = var.headless

  boot_command      = ["<enter><enter><enter><enter><enter><enter><enter><enter><enter><enter>"]
  boot_key_interval = "1s"
  boot_wait         = "1s"

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
