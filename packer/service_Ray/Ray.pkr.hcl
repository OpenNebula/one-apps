source "null" "null" { communicator = "none" }

# Prior to setting up the appliance or distro, the context packages need to be generated first
# These will then be installed as part of the setup process
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

# A Virtual Machine is created with qemu in order to run the setup from the ISO on the CD-ROM
# Here are the details about the VM virtual hardware
source "qemu" "Ray" {
  cpus        = 2
  memory      = 4096
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
  disk_size        = 8192

  output_directory = var.output_dir

  qemuargs = [["-serial", "stdio"],
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

# Once the VM launches the following logic will be executed inside it to customize what happens inside
# Essentially, a bunch of scripts are pulled from ./appliances and placed inside the Guest OS
# There are shared libraries for ruby and bash. Bash is used in this example
build {
  sources = ["source.qemu.Ray"]

  # revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = ["${var.input_dir}/81-configure-ssh.sh"]
  }

  ##############################################
  # BEGIN placing script logic inside Guest OS #
  ##############################################

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline = [
      "install -o 0 -g 0 -m u=rwx,g=rx,o=   -d /etc/one-appliance/{,service.d/,lib/}",
      "install -o 0 -g 0 -m u=rwx,g=rx,o=rx -d /opt/one-appliance/{,bin/}",
    ]
  }

  # Script Required by a further step
  provisioner "file" {
    sources = [
      "appliances/scripts/net-90-service-appliance",
      "appliances/scripts/net-99-report-ready",
    ]
    destination = "/etc/one-appliance/"
  }

  provisioner "file" {
    sources     = ["appliances/lib/helpers.rb"]
    destination = "/etc/one-appliance/lib/"
  }

  provisioner "file" {
    source      = "appliances/service.rb"
    destination = "/etc/one-appliance/service"
  }

  provisioner "file" {
    sources     = [
        "appliances/Ray/main.rb",
        "appliances/Ray/config.rb"
    ]
    destination = "/etc/one-appliance/service.d/"
  }

  provisioner "file" {
    sources     = [
        "appliances/Ray/config.yaml.template"
        ]
    destination = "/root/" #TODO: Change
  }


  provisioner "shell" {
    scripts = ["${var.input_dir}/82-configure-context.sh"]
  }


  #######################################################################
  # Setup appliance: Execute install step                               #
  # https://github.com/OpenNebula/one-apps/wiki/apps_intro#installation #
  #######################################################################
  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline         = ["/etc/one-appliance/service install && sync"]
  }

  # Remove machine ID from the VM and get it ready for continuous cloud use
  # https://github.com/OpenNebula/one-apps/wiki/tool_dev#appliance-build-process
  post-processor "shell-local" {
    execute_command = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "OUTPUT_DIR=${var.output_dir}",
      "APPLIANCE_NAME=${var.appliance_name}",
    ]
    scripts = ["packer/postprocess.sh"]
  }
}
