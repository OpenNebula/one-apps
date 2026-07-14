variable "ol" {
  type = map(map(string))

  # navigate via https://yum.oracle.com/oracle-linux-templates.html
  default = {
    "8.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL8/u10/x86_64/OL8U10_x86_64-kvm-b271.qcow2"
      iso_checksum = "23c72a22201b80c98195212e205c2ec0e2a641dfd5f37374dfe6e4f0639ef311"
    }

    "9.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL9/u7/x86_64/OL9U7_x86_64-kvm-b289.qcow2"
      iso_checksum = "81b61a7b3fb3279d8758c82c625cce7c770123f193cb37960971ba58aa9e025f"
    }

    "10.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL10/u1/x86_64/OL10U1_x86_64-kvm-b291.qcow2"
      iso_checksum = "8e59326c4bf7cfa58a6cac404db8ed583fe3a5f4c460e2b73c64988785bb4f0f"
    }
  }
}
