variable "appliance_name" {
  type    = string
  default = "windows"
}

variable "version" {
  type    = string
  default = "10Home"
}

variable "input_dir" {
  type = string
}

variable "output_dir" {
  type = string
}

variable "headless" {
  type    = bool
  default = true
}


variable "language" {
  type = string
  default = "en-US"
}

variable "windows" {
  type = map(map(string))

  default = {
    "10Home" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Home"
    }
    "10HomeN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Home N"
    }
    "10HomeSingleLanguage" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Home Single Language"
    }
    "10Pro" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro"
    }
    "10ProN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro N"
    }
    "10ProEducation" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro Education"
    }
    "10ProEducationN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro Education N"
    }
    "10ProWorkstations" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro for Workstations"
    }
    "10ProWorkstationsN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Pro N for Workstations"
    }
    "10Education" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Education"
    }
    "10EducationN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Education"
    }
    "10Enterprise" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Enterprise"
    }
    "10enterpriseN" = {
      iso_url      = "packer/windows/iso/Win10_22H2_English_x64v1.iso"
      iso_checksum = "sha256:A6F470CA6D331EB353B815C043E327A347F594F37FF525F17764738FE812852E"
      edition_name = "Windows 10 Enterprise N"
    }
    "11Home" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Home"
    }
    "11HomeN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Home N"
    }
    "11HomeSingleLanguage" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Home Single Language"
    }
    "11Pro" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro"
    }
    "11ProN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro N"
    }
    "11ProEducation" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro Education"
    }
    "11ProEducationN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro Education N"
    }
    "11ProWorkstations" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro for Workstations"
    }
    "11ProWorkstationsN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Pro N for Workstations"
    }
    "11Education" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Education"
    }
    "11EducationN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Education"
    }
    "11Enterprise" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Enterprise"
    }
    "11enterpriseN" = {
      iso_url      = "packer/windows/iso/Win11_23H2_English_x64v2.iso"
      iso_checksum = "sha256:36DE5ECB7A0DAA58DCE68C03B9465A543ED0F5498AA8AE60AB45FB7C8C4AE402"
      edition_name = "Windows 11 Enterprise N"
    }

  }
}