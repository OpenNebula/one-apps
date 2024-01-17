source "null" "null" { communicator = "none" }

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
source "qemu" "OneKE" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = "export/ubuntu2204.qcow2"
  iso_checksum = "none"

  headless = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 25600

  output_directory = var.output_dir

  qemuargs = [
    ["-serial", "stdio"],
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
  sources = ["source.qemu.OneKE"]

  # update & revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = [
      "${var.input_dir}/10-update.sh",
      "${var.input_dir}/81-configure-ssh.sh",
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "install -o 0 -g 0 -m u=rwx,g=rx,o=   -d /etc/one-appliance/{,service.d/,lib/}",
      "install -o 0 -g 0 -m u=rwx,g=rx,o=rx -d /opt/one-appliance/{,bin/}",
    ]
  }

  provisioner "file" {
    sources = [
      "appliances/service",
      "appliances/scripts/net-90",
      "appliances/scripts/net-99",
    ]
    destination = "/etc/one-appliance/"
  }
  provisioner "file" {
    sources     = ["appliances/lib/helpers.rb"]
    destination = "/etc/one-appliance/lib/"
  }
  provisioner "file" {
    sources     = ["appliances/OneKE"]
    destination = "/etc/one-appliance/service.d/"
  }

  provisioner "shell" {
    scripts = [
      "${var.input_dir}/82-configure-context.sh",
      "${var.input_dir}/83-disable-docs.sh",
    ]
  }

  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    inline           = ["/etc/one-appliance/service install"]
    environment_vars = ["ONE_SERVICE_AIRGAPPED=${var.airgapped}"]
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
