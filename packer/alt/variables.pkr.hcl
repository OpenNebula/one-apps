variable "alt" {
  type = map(map(string))

  default = {
    "10.x86_64" = {
      iso_url      = "https://mirror.yandex.ru/altlinux/p10/images/cloud/x86_64/alt-p10-cloud-x86_64.qcow2"
      iso_checksum = "file:https://mirror.yandex.ru/altlinux/p10/images/cloud/x86_64/SHA256SUM"
    }
  }
}
