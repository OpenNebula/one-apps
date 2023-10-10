# Build cloud init iso
source "file" "user_data" {
  source = "${var.input_dir}/cloud-init.yml"
  target = "${var.input_dir}/${var.appliance_name}-userdata"
}

build {
  sources = ["sources.file.user_data"]

  provisioner "shell-local" {
    inline = [
      "cloud-localds ${var.input_dir}/${var.appliance_name}-cloud-init.iso ${var.input_dir}/${var.appliance_name}-userdata",
    ]
  }
}

# Build VM image
source "qemu" "alt" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = lookup(lookup(var.alt, var.version, {}), "iso_url", "")
  iso_checksum     = lookup(lookup(var.alt, var.version, {}), "iso_checksum", "")

  headless         = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"

  output_directory = var.output_dir

  qemuargs         = [ ["-serial", "stdio"],
                       ["-cpu", "host"],
                       ["-cdrom", "${var.input_dir}/${var.appliance_name}-cloud-init.iso"]
                     ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_wait_timeout = "900s"
  vm_name          = "${var.appliance_name}"
}

build {
  sources = ["source.qemu.alt"]

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
