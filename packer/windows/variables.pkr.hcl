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

variable "iso_files" {
  type = map(map(string))
}

variable "disable_administrator" {
  type        = bool
  default     = false
  description = "Whether to disable the Administrator user after initial setup"
}

variable "windows" {
  type = map(map(string))

  default = {
    # Windows 10
    "10Home" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home"
    }
    "10HomeN" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home N"
    }
    "10HomeSingleLanguage" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Home Single Language"
    }
    "10Pro" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro"
    }
    "10ProN" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro N"
    }
    "10ProEducation" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro Education"
    }
    "10ProEducationN" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro Education N"
    }
    "10ProWorkstations" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro for Workstations"
    }
    "10ProWorkstationsN" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Pro N for Workstations"
    }
    "10Education" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Education"
    }
    "10EducationN" = {
      iso          = "windows10ConsumerEditions"
      edition_name = "Windows 10 Education N"
    }
    "10Enterprise" = {
      iso          = "windows10BusinessEditions"
      edition_name = "Windows 10 Enterprise"
    }
    "10enterpriseN" = {
      iso          = "windows10BusinessEditions"
      edition_name = "Windows 10 Enterprise N"
    }
    "10EnterpriseLTSC2015" = {
      iso          = "windows10EnterpriseLTSC2015"
      edition_name = "Windows 10 Enterprise 2015 LTSB"
    }
    "10EnterpriseNLTSC2015" = {
      iso          = "windows10EnterpriseNLTSC2015"
      edition_name = "Windows 10 Enterprise N 2015 LTSB"
    }
    "10EnterpriseLTSC2016" = {
      iso          = "windows10EnterpriseLTSC2016"
      edition_name = "Windows 10 Enterprise 2016 LTSB"
    }
    "10EnterpriseNLTSC2016" = {
      iso          = "windows10EnterpriseLTSC2016"
      edition_name = "Windows 10 Enterprise N 2016 LTSB"
    }
    "10EnterpriseLTSC2019" = {
      iso          = "windows10EnterpriseLTSC2019"
      edition_name = "Windows 10 Enterprise LTSC 2019"
    }
    "10EnterpriseNLTSC2019" = {
      iso          = "windows10EnterpriseLTSC2019"
      edition_name = "Windows 10 Enterprise N LTSC 2019"
    }
    "10EnterpriseLTSC2021" = {
      iso          = "windows10EnterpriseLTSC2021"
      edition_name = "Windows 10 Enterprise LTSC 2021"
    }
    "10EnterpriseNLTSC2021" = {
      iso          = "windows10EnterpriseLTSC2021"
      edition_name = "Windows 10 Enterprise N LTSC 2021"
    }
    # Windows 11
    "11Home" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home"
    }
    "11HomeN" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home N"
    }
    "11HomeSingleLanguage" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Home Single Language"
    }
    "11Pro" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro"
    }
    "11ProN" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro N"
    }
    "11ProEducation" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro Education"
    }
    "11ProEducationN" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro Education N"
    }
    "11ProWorkstations" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro for Workstations"
    }
    "11ProWorkstationsN" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Pro N for Workstations"
    }
    "11Education" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Education"
    }
    "11EducationN" = {
      iso          = "windows11ConsumerEditions"
      edition_name = "Windows 11 Education"
    }
    "11Enterprise" = {
      iso          = "windows11BusinessEditions"
      edition_name = "Windows 11 Enterprise"
    }
    "11enterpriseN" = {
      iso          = "windows11BusinessEditions"
      edition_name = "Windows 11 Enterprise N"
    }
    "11EnterpriseLTSC2024" = {
      iso          = "windows11EnterpriseLTSC2024"
      edition_name = "Windows 11 Enterprise LTSC 2024"
    }
    "11EnterpriseNLTSC2024" = {
      iso          = "windows11EnterpriseLTSC2024"
      edition_name = "Windows 11 Enterprise N LTSC 2024"
    }
    # Windows Server 2016
    "2016Standard" = {
      iso          = "server2016"
      edition_name = "Windows Server 2016 SERVERSTANDARD"
    }
    "2016StandardCore" = {
      iso          = "server2016"
      edition_name = "Windows Server 2016 SERVERSTANDARDCORE"
    }
    "2016Datacenter" = {
      iso          = "server2016"
      edition_name = "Windows Server 2016 SERVERDATACENTER"
    }
    "2016DatacenterCore" = {
      iso          = "server2016"
      edition_name = "Windows Server 2016 SERVERDATACENTERCORE"
    }
    "2016Essentials" = {
      iso          = "server2016Essentials"
      edition_name = "Windows Server 2016 SERVERSOLUTION"
    }
    # Windows Server 2019
    "2019Standard" = {
      iso          = "server2019"
      edition_name = "Windows Server 2019 SERVERSTANDARD"
    }
    "2019StandardCore" = {
      iso          = "server2019"
      edition_name = "Windows Server 2019 SERVERSTANDARDCORE"
    }
    "2019Datacenter" = {
      iso          = "server2019"
      edition_name = "Windows Server 2019 SERVERDATACENTER"
    }
    "2019DatacenterCore" = {
      iso          = "server2019"
      edition_name = "Windows Server 2019 SERVERDATACENTERCORE"
    }
    "2019Essentials" = {
      iso          = "server2019Essentials"
      edition_name = "Windows Server 2019 SERVERSOLUTION"
    }
    # Windows Server 2022
    "2022Standard" = {
      iso          = "server2022"
      edition_name = "Windows Server 2022 SERVERSTANDARD"
    }
    "2022StandardCore" = {
      iso          = "server2022"
      edition_name = "Windows Server 2022 SERVERSTANDARDCORE"
    }
    "2022Datacenter" = {
      iso          = "server2022"
      edition_name = "Windows Server 2022 SERVERDATACENTER"
    }
    "2022DatacenterCore" = {
      iso          = "server2022"
      edition_name = "Windows Server 2022 SERVERDATACENTERCORE"
    }
    # Windows Server 2025
    "2025Standard" = {
      iso          = "server2025"
      edition_name = "Windows Server 2025 SERVERSTANDARD"
    }
    "2025StandardCore" = {
      iso          = "server2025"
      edition_name = "Windows Server 2025 SERVERSTANDARDCORE"
    }
    "2025Datacenter" = {
      iso          = "server2025"
      edition_name = "Windows Server 2025 SERVERDATACENTER"
    }
    "2025DatacenterCore" = {
      iso          = "server2025"
      edition_name = "Windows Server 2025 SERVERDATACENTERCORE"
    }
  }
}
