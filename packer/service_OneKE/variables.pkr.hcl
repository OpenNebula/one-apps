variable "appliance_name" {
  type    = string
  default = "service_OneKE"
}

variable "input_dir" {
  type    = string
}

variable "output_dir" {
  type    = string
}

variable "airgapped" {
  type    = string
  default = "NO"
}

variable "headless" {
  type    = bool
  default = false
}

variable "version" {
  type    = string
  default = ""
}
