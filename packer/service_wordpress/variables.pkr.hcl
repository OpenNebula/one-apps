variable "appliance_name" {
  type    = string
  default = "service_wordpress"
}

variable "appliance_script" {
  type    = string
  default = "appliances/wordpress.sh"
}

variable "input_dir" {
  type    = string
}

variable "output_dir" {
  type    = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "version" {
  type    = string
  default = ""
}

