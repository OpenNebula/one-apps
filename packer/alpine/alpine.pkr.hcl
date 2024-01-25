source "qemu" "alpine" {
  cpus        = 2
  memory      = 2048
  accelerator = "kvm"

  iso_url      = lookup(lookup(var.alpine, var.version, {}), "iso_url", "")
  iso_checksum = lookup(lookup(var.alpine, var.version, {}), "iso_checksum", "")

  headless = var.headless

  http_directory = "${var.input_dir}"
  boot_command = [
    "root<enter>",
    "ifconfig eth0 up && udhcpc -i eth0<enter><wait1>",
    "wget -qO alpine.init http://{{ .HTTPIP }}:{{ .HTTPPort }}/alpine.init<enter><wait1>",
    "/bin/ash alpine.init<enter><wait20>"
  ]
  boot_wait = "20s"

  disk_cache       = "unsafe"
  disk_interface   = "virtio"
  net_device       = "virtio-net"
  disk_size        = 256
  format           = "qcow2"
  disk_compression = false

  output_directory = "${var.output_dir}"

  qemuargs = [
    ["-cpu", "host"],
    ["-serial", "stdio"],
  ]

  ssh_username     = "root"
  ssh_password     = "opennebula"
  ssh_timeout      = "900s"
  shutdown_command = "poweroff"
  vm_name          = "${var.appliance_name}"
}

build {
  sources = ["source.qemu.alpine"]

  provisioner "shell" { inline = ["mkdir /context"] }

  provisioner "file" {
    source      = "context-linux/out/"
    destination = "/context"
  }

  provisioner "shell" {
    execute_command = "{{.Vars}} ash {{.Path}}"

    # execute *.sh + *.sh.<version> from input_dir
    scripts = sort(concat(
      [for s in fileset(".", "*.sh") : "${var.input_dir}/${s}"],
      [for s in fileset(".", "*.sh.${var.version}") : "${var.input_dir}/${s}"]
    ))
    expect_disconnect = true
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
