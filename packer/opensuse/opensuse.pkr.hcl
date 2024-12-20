# Build cloud init iso
source "null" "null" { communicator = "none" }

build {
  sources = ["sources.null.null"]

  provisioner "shell-local" {
    inline = [
      "cloud-localds ${var.input_dir}/${var.appliance_name}-cloud-init.iso ${var.input_dir}/cloud-init.yml",
    ]
  }

  # Workaround for https://github.com/openSUSE/MirrorCache/issues/528
  provisioner "shell-local" {
    inline = [
      # Replace image name for symlinked image on checksum file
      "wget -O ${var.checksum_file} ${var.checksum_url}",
      "sed -i 's/${var.iso_prefix}-.*\\.qcow2/${var.iso_prefix}-Cloud.qcow2/' ${var.checksum_file}",
    ]
  }
}

# Build VM image
source "qemu" "opensuse" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.opensuse, var.version, {}), "iso_url", "")
  # iso_checksum = lookup(lookup(var.opensuse, var.version, {}), "iso_checksum", "")
  iso_checksum = "file:${var.checksum_file}"

  headless = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 4096

  output_directory = var.output_dir

  qemuargs = [
    ["-cpu", "host"],
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
  sources = ["source.qemu.opensuse"]

  /* provisioner "shell" { inline = ["sleep 1000"] } */

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
