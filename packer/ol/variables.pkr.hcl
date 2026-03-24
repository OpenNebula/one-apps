variable "ol" {
  type = map(map(string))

  # navigate via https://yum.oracle.com/oracle-linux-templates.html
  default = {
    "8.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL8/u10/x86_64/OL8U10_x86_64-kvm-b271.qcow2"
      iso_checksum = "23c72a22201b80c98195212e205c2ec0e2a641dfd5f37374dfe6e4f0639ef311"
    }

    "9.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL9/u7/x86_64/OL9U7_x86_64-kvm-b269.qcow2"
      iso_checksum = "88c75cf913a66227e9ce74b0087ecac4cce1883f3e5649082e982d0d00310f1c"
    }

    "10.x86_64" = {
      iso_url      = "https://yum.oracle.com/templates/OracleLinux/OL10/u1/x86_64/OL10U1_x86_64-kvm-b270.qcow2"
      iso_checksum = "65077d1363f107cd750cdea26c73868c2128b5ed778ee93f0873aa2999228765"
    }
  }
}
