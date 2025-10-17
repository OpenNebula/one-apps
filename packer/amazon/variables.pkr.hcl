variable "amazon" {
  type = map(map(string))

  default = {
    "2.x86_64" = {
      # navigate via https://cdn.amazonlinux.com/os-images/latest/kvm/
      iso_url      = "https://cdn.amazonlinux.com/os-images/2.0.20250512.0/kvm/amzn2-kvm-2.0.20250512.0-x86_64.xfs.gpt.qcow2"
      iso_checksum = "file:https://cdn.amazonlinux.com/os-images/2.0.20250512.0/kvm/SHA256SUMS"
    }
    "2023.x86_64" = {
      # navigate via https://cdn.amazonlinux.com/al2023/os-images/latest/
      iso_url      = "https://cdn.amazonlinux.com/al2023/os-images/2023.7.20250512.0/kvm/al2023-kvm-2023.7.20250512.0-kernel-6.1-x86_64.xfs.gpt.qcow2"
      iso_checksum = "file:https://cdn.amazonlinux.com/al2023/os-images/2023.7.20250512.0/kvm/SHA256SUMS"
    }
  }
}
