source "qemu" "rocky" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = lookup(lookup(var.rocky, var.version, {}), "iso_url", "")
  iso_checksum     = lookup(lookup(var.rocky, var.version, {}), "iso_checksum", "")

  headless         = var.headless

  http_directory   = "${var.input_dir}"
  boot_command     = ["<tab><bs><bs><bs><bs><bs> append rd.live.check=0 inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.appliance_name}.ks<enter><wait>"]
  boot_wait        = "20s"

  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = true

  output_directory = "${var.output_dir}"

  qemuargs         = [ ["-serial", "stdio"],
                       ["-cpu", "host"]
                     ]
  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_wait_timeout = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}

build {
  sources = ["source.qemu.rocky"]

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
    execute_command   = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "OUTPUT_DIR=${var.output_dir}",
      "APPLIANCE_NAME=${var.appliance_name}",
      ]
    scripts = [ "packer/postprocess.sh" ]
  }
}
