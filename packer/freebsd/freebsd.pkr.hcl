# Build VM image
source "qemu" "freebsd" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = lookup(lookup(var.freebsd, var.version, {}), "iso_url", "")
  iso_checksum     = lookup(lookup(var.freebsd, var.version, {}), "iso_checksum", "")

  headless         = var.headless

  boot_wait        = "120s"
  boot_command    =  lookup(var.boot_cmd, var.version, [])

  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 4096

  output_directory = var.output_dir

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
  sources = ["source.qemu.freebsd"]

  # be carefull with shell inline provisioners, FreeBSD csh is tricky
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    scripts         = ["${var.input_dir}/mkdir"]
  }

  provisioner "file" {
    destination = "/tmp/context"
    source      = "context-linux/out/"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    scripts         = ["${var.input_dir}/script.sh"]
  }
}
