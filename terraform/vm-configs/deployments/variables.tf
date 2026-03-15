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

variable "k8s_version" {
  type = string
  description = "Kubernetes version to install (e.g., 1.30.0)"
  default = "1.30.0"
}

variable "k8s_pod_cidr_dev" {
  type = string
  description = "Pod CIDR for dev Kubernetes cluster"
  default = "172.16.0.0/16"
}

variable "k8s_pod_cidr_prod" {
  type = string
  description = "Pod CIDR for prod Kubernetes cluster"
  default = "172.17.0.0/16"
}

variable "github_runner_token_dev" {
  type = string
  description = "GitHub Actions runner token for dev environment"
  sensitive = true
  default = ""
}

variable "github_runner_token_prod" {
  type = string
  description = "GitHub Actions runner token for prod environment"
  sensitive = true
  default = ""
}

variable "github_runner_org" {
  type = string
  description = "GitHub organization for runner registration"
  default = ""
}

