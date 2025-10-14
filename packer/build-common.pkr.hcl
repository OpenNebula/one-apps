build {
  sources = ["source.qemu.${var.distro}"]

  provisioner "shell" { inline = ["mkdir /context"] }

  provisioner "file" {
    source      = "context-linux/out/"
    destination = "/context"
  }

  provisioner "shell" {
    execute_command = var.command_format

    # execute *.sh + *.sh.<version> from input_dir
    scripts = sort(concat(
      [for s in fileset(".", "**.sh") : "${var.input_dir}/${s}"],
      [for s in fileset(".", "**.sh.${var.version}") : "${var.input_dir}/${s}"]
    ))

    environment_vars = [
      "DIST_VER=${var.version}",
      "DIST_ARCH=${var.arch}",
    ]
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
