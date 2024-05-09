source "qemu" "devuan" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.devuan, var.version, {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.devuan, var.version, {}), "iso_checksum", "")

  headless = var.headless

  http_directory = "${var.input_dir}"
  boot_command   = lookup(var.boot_cmd, var.version, [])
  boot_wait      = "10s"

  disk_cache       = "unsafe"
  disk_interface   = "virtio-scsi"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 4096

  output_directory = "${var.output_dir}"

  qemuargs = [
    ["-cpu", "host"],
    ["-serial", "stdio"],
  ]
  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}

build {
  sources = ["source.qemu.devuan"]

  provisioner "shell" { inline = ["mkdir /context"] }

  provisioner "file" {
    source      = "context-linux/out/"
    destination = "/context"
  }

  provisioner "shell" {
    execute_command = "{{.Vars}} bash {{.Path}}"

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
