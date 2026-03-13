variable "pm_api_url" {
  type        = string
  description = "Proxmox API URL"
}

variable "pm_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
}

variable "pm_node" {
  description = "Target Proxmox node"
  type        = string
}

variable "vm_password" {
  type        = string
  sensitive   = true
  description = "Default password for VMs"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
  sensitive   = true
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers for VMs"
  default     = ["8.8.8.8", "8.8.4.4"]
}
