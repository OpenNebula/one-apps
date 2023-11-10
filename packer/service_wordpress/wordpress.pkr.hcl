source "null" "null" { communicator  = "none" }

build {
  sources = ["source.null.null"]

  provisioner "shell-local" {
    inline = [
      "mkdir -p ${var.input_dir}/context",
      "${var.input_dir}/gen_context > ${var.input_dir}/context/context.sh",
      "mkisofs -o ${var.input_dir}/${var.appliance_name}-context.iso -V CONTEXT -J -R ${var.input_dir}/context",
    ]
  }
}

# Build VM image
source "qemu" "wordpress" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = "export/alma8.qcow2"
  iso_checksum     = "none"

  headless         = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = true

  output_directory = var.output_dir

  qemuargs         = [ ["-serial", "stdio"],
                       ["-cpu", "host"],
                       ["-cdrom", "${var.input_dir}/${var.appliance_name}-context.iso"],
                       # MAC addr needs to mach ETH0_MAC from context iso
                       ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
                       ["-device", "virtio-net-pci,netdev=net0,mac=00:11:22:33:44:55"]
                     ]
  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_wait_timeout = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}

build {
  sources = ["source.qemu.wordpress"]

  # revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = ["${var.input_dir}/81-configure-ssh.sh"]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/one-appliance/service.d",
      "chmod 0750 /etc/one-appliance",
      "mkdir -p /opt/one-appliance/bin",
      "chmod -R 0755 /opt/one-appliance/"
    ]
  }

  provisioner "file" {
    source      = "appliances/scripts/context_service_net-90.sh"
    destination = "/etc/one-appliance/net-90"
  }

  provisioner "file" {
    source      = "appliances/scripts/context_service_net-99.sh"
    destination = "/etc/one-appliance/net-99"
  }

  provisioner "file" {
    source      = "appliances/service"
    destination = "/etc/one-appliance/service"
  }

  provisioner "file" {
    source      = "appliances/lib/common.sh"
    destination = "/etc/one-appliance/service.d/common.sh"
  }

  provisioner "file" {
    source      = "appliances/lib/functions.sh"
    destination = "/etc/one-appliance/service.d/functions.sh"
  }

  provisioner "file" {
    source      = "appliances/lib/context-helper.py"
    destination = "/opt/one-appliance/bin/context-helper"
  }

  provisioner "file" {
    source      = "appliances/wordpress.sh"
    destination = "/etc/one-appliance/service.d/appliance.sh"
  }

  provisioner "shell" {
    inline = [
        "find /opt/one-appliance/ -type f -exec chmod 0640 '{}' \\;",
        "chmod 0755 /opt/one-appliance/bin/*",
        "chmod 0740 /etc/one-appliance/service",
        "chmod 0640 /etc/one-appliance/service.d/*",
        "/etc/one-appliance/service install"
    ]
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
