# Build cloud init iso
source "null" "null" { communicator = "none" }

build {
  sources = ["sources.null.null"]

  provisioner "shell-local" {
    inline = [
      "mkdir -p ${var.input_dir}/context",
      "${var.input_dir}/gen_context > ${var.input_dir}/context/context.sh",
      "mkisofs -o ${var.input_dir}/${var.appliance_name}-context.iso -V CONTEXT -J -R ${var.input_dir}/context",
    ]
  }
}

# Build VM image
source "qemu" "capone" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.capone, var.arch, {}), "iso_url", "")
  iso_checksum = "none"

  headless = var.headless

  firmware     = lookup(lookup(var.arch_vars, var.arch, {}), "firmware", "")
  use_pflash   = lookup(lookup(var.arch_vars, var.arch, {}), "use_pflash", "")
  machine_type = lookup(lookup(var.arch_vars, var.arch, {}), "machine_type", "")
  qemu_binary  = lookup(lookup(var.arch_vars, var.arch, {}), "qemu_binary", "")

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  skip_resize_disk = false
  disk_size        = 10240

  output_directory = var.output_dir

  qemuargs = [
    ["-cpu", "host"],
    ["-cdrom", "${var.input_dir}/${var.appliance_name}-context.iso"],
    ["-serial", "stdio"],
    # MAC addr needs to mach ETH0_MAC from context iso
    ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    ["-device", "virtio-net-pci,netdev=net0,mac=00:11:22:33:44:55"]
  ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}


locals {
  version_no_arch = split(".", var.version).0
}

build {
  sources = ["source.qemu.capone"]

  provisioner "shell" {
    execute_command = "sudo -iu root {{.Vars}} bash {{.Path}}"

    environment_vars = [
      "ALT_ARCH=${lookup(lookup(var.capone, var.arch, {}), "alt_arch", "")}",
    ]

    # execute *.sh + *.sh.<version> from input_dir
    scripts = sort(concat(
      [for s in fileset(".", "*.sh") : "${var.input_dir}/${s}"],
      [for s in fileset(".", "*.sh.${local.version_no_arch}") : "${var.input_dir}/${s}"]
    ))
    expect_disconnect = true
  }

  post-processor "shell-local" {
    execute_command = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "OUTPUT_DIR=${var.output_dir}",
      "APPLIANCE_NAME=${var.appliance_name}",
    ]
    scripts = ["packer/postprocess.sh"]
  }
}
