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
  disk_size = lookup({
    "2204oneke"         = 3072
    "2204oneke.aarch64" = 3072
  }, var.version, 0)
}

# Build VM image
source "qemu" "ubuntu" {
  cpus        = 2
  cpu_model   = "host"
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.ubuntu, var.version, {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.ubuntu, var.version, {}), "iso_checksum", "")

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

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" { inline = ["mkdir /context"] }

  provisioner "file" {
    source      = "context-linux/out/"
    destination = "/context"
  }

  provisioner "shell" {
    execute_command = "sudo -iu root {{.Vars}} bash {{.Path}}"

    # execute *.sh + *.sh.<version> from input_dir
    scripts = sort(concat(
      [for s in fileset(".", "*.sh") : "${var.input_dir}/${s}"],
      [for s in fileset(".", "*.sh.${var.version}") : "${var.input_dir}/${s}"]
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
