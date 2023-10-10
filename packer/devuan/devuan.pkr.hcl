source "qemu" "devuan" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = lookup(lookup(var.devuan, var.version, {}), "iso_url", "")
  iso_checksum     = lookup(lookup(var.devuan, var.version, {}), "iso_checksum", "")

  headless         = var.headless

  http_directory   = "${var.input_dir}"
  boot_command     = ["<tab><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>  auto=true url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.appliance_name}.preseed hostname=localhost domain=localdomain interface=auto <enter>"]
  boot_wait        = "10s"

  disk_cache       = "unsafe"
  disk_interface   = "virtio-scsi"
  net_device       = "virtio-net"
  disk_size        = 4096
  format           = "qcow2"

  output_directory = "${var.output_dir}"

  qemuargs         = [ ["-serial", "stdio"],
                       ["-cpu", "host"]
                     ]
  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_wait_timeout = "900s"
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
    execute_command   = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "OUTPUT_DIR=${var.output_dir}",
      "APPLIANCE_NAME=${var.appliance_name}",
      ]
    scripts = [ "packer/postprocess.sh" ]
  }
}
