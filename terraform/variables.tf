variable "pm_api_url" {
  type = string
}

variable "pm_user" {
  type = string
}

variable "pm_password" {
  type      = string
  sensitive = true
}

variable "pm_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "firewall_template" {
  type      = string
  sensitive = true
}

variable "debian_template" {
  type      = string
  sensitive = true
}

variable "vm_password" {
  type      = string
  sensitive = true
}
