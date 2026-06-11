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
source "qemu" "SlurmWorker" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"
  cpu_model   = "host"

  iso_url      = lookup(lookup(var.SlurmWorker, var.arch, {}), "iso_url", "")
  iso_checksum = "none"

  headless = var.headless

  firmware     = lookup(lookup(var.arch_vars, var.arch, {}), "firmware", "")
  use_pflash   = lookup(lookup(var.arch_vars, var.arch, {}), "use_pflash", "")
  machine_type = lookup(lookup(var.arch_vars, var.arch, {}), "machine_type", "")
  qemu_binary  = lookup(lookup(var.arch_vars, var.arch, {}), "qemu_binary", "")

  disk_image       = true
  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  format           = "qcow2"
  disk_compression = false
  disk_size        = 10240

  output_directory = var.output_dir

  qemuargs = [
    ["-cpu", "host"],
    ["-cdrom", "${var.input_dir}/${var.appliance_name}-context.iso"],
    ["-serial", "stdio"],
    # MAC addr needs to mach ETH0_MAC from context iso
    ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    ["-device", "virtio-net-pci,netdev=net0,mac=00:11:22:33:44:55"],
  ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}

locals {
  install_nvidia_driver          = var.nvidia_driver_path != "" ? true : false
  nvidia_driver_local_tmp_dir    = "/tmp"
  nvidia_driver_local_tmp_path   = "${local.nvidia_driver_local_tmp_dir}/${basename(var.nvidia_driver_path)}"
  nvidia_driver_remote_dest_dir  = "/tmp"
  nvidia_driver_remote_dest_path = "${local.nvidia_driver_remote_dest_dir}/${basename(var.nvidia_driver_path)}"
}

build {
  sources = ["source.qemu.SlurmWorker"]

  # revert insecure ssh options done by context start_script
  provisioner "shell" {
    scripts = [
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
    sources     = ["appliances/SlurmWorker"]
    destination = "/etc/one-appliance/service.d/"
  }

  provisioner "shell" {
    scripts = ["${var.input_dir}/82-configure-context.sh"]
  }

  provisioner "shell-local" {
    execute_command = ["bash", "-c", "{{.Vars}} {{.Script}}"]
    environment_vars = [
      "DRIVERS_PATH=${var.nvidia_driver_path}",
      "DRIVERS_TMP_DEST_DIR=${local.nvidia_driver_local_tmp_dir}",
    ]
    scripts = ["${var.input_dir}/90-custom-scripts/get_nvidia_driver.sh"]
  }

  provisioner "file" {
    source      = local.install_nvidia_driver ? local.nvidia_driver_local_tmp_path : "/dev/null"
    destination = local.install_nvidia_driver ? local.nvidia_driver_remote_dest_path : "/dev/null"
    generated   = true
  }

  provisioner "shell-local" {
    inline = [<<EOF
        if [ -n "$DRIVERS_TMP_PATH" ]; then
            rm -f "$DRIVERS_TMP_PATH";
        fi
    EOF
    ]
    environment_vars = [
      "DRIVERS_TMP_PATH=${local.install_nvidia_driver ? local.nvidia_driver_local_tmp_path : ""}",
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline = [<<EOF
        if [ -n "$DRIVER_PATH" ]; then
            apt-get update --fix-missing;
            dpkg -i "$DRIVER_PATH";
            apt --fix-broken install --yes;
            rm -f "$DRIVER_PATH";
        fi
    EOF
    ]
    environment_vars = [
      "DRIVER_PATH=${local.install_nvidia_driver ? local.nvidia_driver_remote_dest_path : ""}"
    ]
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"
    inline         = ["/etc/one-appliance/service install && sync"]
    environment_vars = [
      "INSTALL_DRIVERS=${local.install_nvidia_driver ? "false" : "true"}",
    ]
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
