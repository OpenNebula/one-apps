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
  type    = string
  default = "en-US"
}

variable "isoFiles" {
  type = map(map(string))
}

variable "windows" {
  type = map(map(string))

  default = {
    # Windows 10
    "10Home" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home"
    }
    "10HomeN" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home N"
    }
    "10HomeSingleLanguage" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home Single Language"
    }
    "10Pro" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro"
    }
    "10ProN" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro N"
    }
    "10ProEducation" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro Education"
    }
    "10ProEducationN" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro Education N"
    }
    "10ProWorkstations" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro for Workstations"
    }
    "10ProWorkstationsN" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro N for Workstations"
    }
    "10Education" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Education"
    }
    "10EducationN" = {
      iso = "windows10ConsumerEditions"
      edition_name = "Windows 10 Education N"
    }
    "10Enterprise" = {
      iso = "windows10BusinessEditions"
      edition_name = "Windows 10 Enterprise"
    }
    "10enterpriseN" = {
      iso = "windows10BusinessEditions"
      edition_name = "Windows 10 Enterprise N"
    }
    # Windows 11
    "11Home" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home"
    }
    "11HomeN" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home N"
    }
    "11HomeSingleLanguage" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home Single Language"
    }
    "11Pro" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro"
    }
    "11ProN" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro N"
    }
    "11ProEducation" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro Education"
    }
    "11ProEducationN" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro Education N"
    }
    "11ProWorkstations" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro for Workstations"
    }
    "11ProWorkstationsN" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro N for Workstations"
    }
    "11Education" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Education"
    }
    "11EducationN" = {
      iso = "windows11ConsumerEditions"
      edition_name = "Windows 11 Education"
    }
    "11Enterprise" = {
      iso = "windows11BusinessEditions"
      edition_name = "Windows 11 Enterprise"
    }
    "11enterpriseN" = {
      iso = "windows11BusinessEditions"
      edition_name = "Windows 11 Enterprise N"
    }
    # Windows Server 2016
    "2016Standard" = {
      iso = "server2016"
      edition_name = "Windows Server 2016 SERVERSTANDARD"
    }
    "2016StandardCore" = {
      iso = "server2016"
      edition_name = "Windows Server 2016 SERVERSTANDARDCORE"
    }
    "2016Datacenter" = {
      iso = "server2016"
      edition_name = "Windows Server 2016 SERVERDATACENTER"
    }
    "2016DatacenterCore" = {
      iso = "server2016"
      edition_name = "Windows Server 2016 SERVERDATACENTERCORE"
    }
    "2016Essentials" = {
      iso = "server2016Essentials"
      edition_name = "Windows Server 2016 SERVERSOLUTION"
    }
    # Windows Server 2019
    "2019Standard" = {
      iso = "server2019"
      edition_name = "Windows Server 2019 SERVERSTANDARD"
    }
    "2019StandardCore" = {
      iso = "server2019"
      edition_name = "Windows Server 2019 SERVERSTANDARDCORE"
    }
    "2019Datacenter" = {
      iso = "server2019"
      edition_name = "Windows Server 2019 SERVERDATACENTER"
    }
    "2019DatacenterCore" = {
      iso = "server2019"
      edition_name = "Windows Server 2019 SERVERDATACENTERCORE"
    }
    "2019Essentials" = {
      iso = "server2019Essentials"
      edition_name = "Windows Server 2019 SERVERSOLUTION"
    }
    # Windows Server 2022
    "2022Standard" = {
      iso = "server2022"
      edition_name = "Windows Server 2022 SERVERSTANDARD"
    }
    "2022StandardCore" = {
      iso = "server2022"
      edition_name = "Windows Server 2022 SERVERSTANDARDCORE"
    }
    "2022Datacenter" = {
      iso = "server2022"
      edition_name = "Windows Server 2022 SERVERDATACENTER"
    }
    "2022DatacenterCore" = {
      iso = "server2022"
      edition_name = "Windows Server 2022 SERVERDATACENTERCORE"
    }
  }
}