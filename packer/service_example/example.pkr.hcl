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
source "qemu" "example" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = "export/alma8.qcow2"
  iso_checksum = "none"

  headless = var.headless

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  skip_resize_disk = true

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
  sources = ["source.qemu.example"]

  # revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = ["${var.input_dir}/81-configure-ssh.sh"]
  }

  ##############################################
  # BEGIN placing script logic inside Guest OS #
  ##############################################

  provisioner "shell" {
    inline = [
      "mkdir -p /etc/one-appliance/service.d",
      "chmod 0750 /etc/one-appliance",
      "mkdir -p /opt/one-appliance/bin",
      "chmod -R 0755 /opt/one-appliance/"
    ]
  }

  # Script Required by a further step
  provisioner "file" {
    source      = "appliances/legacy/scripts/context_service_net-90.sh"
    destination = "/etc/one-appliance/net-90"
  }

  # Script Required by a further step
  provisioner "file" {
    source      = "appliances/legacy/scripts/context_service_net-99.sh"
    destination = "/etc/one-appliance/net-99"
  }

  # Contains the appliance service management tool
  # https://github.com/OpenNebula/one-apps/wiki/apps_intro#appliance-life-cycle
  provisioner "file" {
    source      = "appliances/legacy/service"
    destination = "/etc/one-appliance/service"
  }

  # Bash library for easier custom implementation in bash logic
  provisioner "file" {
    source      = "appliances/legacy/lib/common.sh"
    destination = "/etc/one-appliance/service.d/common.sh"
  }

  # Bash library for easier custom implementation in bash logic
  provisioner "file" {
    source      = "appliances/legacy/lib/functions.sh"
    destination = "/etc/one-appliance/service.d/functions.sh"
  }

  # required by common.sh
  provisioner "file" {
    source      = "appliances/legacy/lib/context-helper.py"
    destination = "/opt/one-appliance/bin/context-helper"
  }

  # The newer ruby logic libraries can be used instead of bash.
  # Note bash handlers are located at ./appliances/legacy and ./appliances/legacy/lib

  // provisioner "file" {
  //   sources = [
  //     "appliances/service",
  //     "appliances/scripts/net-90",
  //     "appliances/scripts/net-99",
  //   ]
  //   destination = "/etc/one-appliance/"
  // }
  // provisioner "file" {
  //   sources     = ["appliances/lib/helpers.rb"]
  //   destination = "/etc/one-appliance/lib/"
  // }

  # Pull your own custom logic here
  provisioner "file" {
    source      = "appliances/example/example.sh" # location of the file in the git repo. Flexible
    destination = "/etc/one-appliance/service.d/appliance.sh" # path in the Guest OS. Strict, always the same
  }

  #######################################################################
  # Setup appliance: Execute install step                               #
  # https://github.com/OpenNebula/one-apps/wiki/apps_intro#installation #
  #######################################################################
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
    scripts = ["${var.input_dir}/82-configure-context.sh"]
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
