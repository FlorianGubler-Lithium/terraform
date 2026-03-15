variable "pm_node" {
  type = string
}

variable "vm_password" {
  type = string
  description = "The password for the VM's root user."
  sensitive = true
}

variable "vm_ci_base_image_file_id" {
  type        = string
  description = "The file ID of the base image to be used for the VM."
}

variable "ssh_public_key" {
  type = string
  description = "The SSH public key to be added to the VM for authentication."
  sensitive = true
}

