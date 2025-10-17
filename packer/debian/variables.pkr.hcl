variable "debian" {
  type = map(map(string))

  default = {
    "11.x86_64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bullseye/latest/SHA512SUMS"
    }

    "11.aarch64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-genericcloud-arm64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bullseye/latest/SHA512SUMS"
    }

    "12.x86_64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bookworm/latest/SHA512SUMS"
    }

    "12.aarch64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-genericcloud-arm64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/bookworm/latest/SHA512SUMS"
    }

    "13.x86_64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"

      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/trixie/latest/SHA512SUMS"
    }

    "13.aarch64" = {
      iso_url      = "https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-genericcloud-arm64.qcow2"
      iso_checksum = "file:https://cdimage.debian.org/cdimage/cloud/trixie/latest/SHA512SUMS"
    }
  }
}
