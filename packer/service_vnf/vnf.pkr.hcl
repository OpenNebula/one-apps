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
source "qemu" "vnf" {
  cpus             = 2
  memory           = 2048
  accelerator      = "kvm"

  iso_url          = "export/alpine318.qcow2"
  iso_checksum     = "none"

  headless         = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 2048

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
  sources = ["source.qemu.vnf"]

  # update & revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = [
      "${var.input_dir}/10-update.sh",
      "${var.input_dir}/81-configure-ssh.sh"]
  }

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/one-appliance/service.d",
      "chmod 0750 /etc/one-appliance",
      "mkdir -p /opt/one-appliance/bin",
      "chmod -R 0755 /opt/one-appliance/"]
  }

  provisioner "file" {
    destination = "/etc/one-appliance/net-90"
    source      = "appliances/scripts/context_service_net-90.sh"
  }

  provisioner "file" {
    destination = "/etc/one-appliance/net-99"
    source      = "appliances/scripts/context_service_net-99.sh"
  }

  provisioner "file" {
    destination = "/etc/one-appliance/service"
    source      = "appliances/service"
  }

  provisioner "file" {
    destination = "/etc/one-appliance/service.d/common.sh"
    source      = "appliances/lib/common.sh"
  }

  provisioner "file" {
    destination = "/etc/one-appliance/service.d/functions.sh"
    source      = "appliances/lib/functions.sh"
  }

  provisioner "file" {
    destination = "/opt/one-appliance/bin/context-helper"
    source      = "appliances/lib/context-helper.py"
  }

  provisioner "file" {
    destination = "/etc/one-appliance/service.d/appliance.sh"
    source      = "appliances/vnf.sh"
  }

  provisioner "file" {
    destination = "/opt/one-appliance/"
    source      = "appliances/lib/artifacts/vnf"
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

  provisioner "shell" {
    scripts = [ "${var.input_dir}/82-configure-context.sh" ]
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
