variable "vm_name" {
  type = string
  description = "The name of the VM to be created."
}

variable "vm_id" {
  type        = number
  description = "The unique ID for the VM to be created."
}

variable "vm_password" {
  type        = string
  description = "The password for the VM's root user."
}

variable "vm_ci_userdata_file_path" {
  type = string
  description = "The path to the user data file for cloud-init initialization."
}

variable "vm_ci_networkdata_file_path" {
  type = string
  description = "The path to the network data file for cloud-init initialization."
}

variable "vm_ci_base_image_file_id" {
  type        = string
  description = "The file ID of the base image to be used for the VM."
}

variable "vm_memory" {
  type        = number
  description = "The amount of memory (in MB) to be allocated to the VM."
}

variable "vm_cpu_cores" {
  type        = number
  description = "The number of CPU cores to be allocated to the VM."
}

variable "vm_disk_size" {
  type        = number
  description = "The size of the VM's disk (in GB)."
}

variable "vm_network_devices" {
  type = list(object({
    bridge = string
    ip     = optional(string)
  }))
  description = "A list of network devices with bridge name and optional static IP address."
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key to be added to the VM for authentication."
}

variable "pm_node" {
  type = string
  description = "The Proxmox node on which the VM should be created."
}

variable "extra_vars" {
  type = map(any)
  description = "A map of extra variables to be passed to the Ansible playbook for additional configuration."
  default = {}
}

variable "vm_groups" {
  type        = list(string)
  description = "List of groups this VM belongs to (e.g., [\"dev\", \"mgmt\"], [\"prod\", \"k8s\", \"k8s_master\"])"
  default     = []
}
