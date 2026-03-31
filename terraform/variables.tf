variable "pm_api_token_secret" {
  type        = string
  sensitive   = true
  description = "Proxmox API token secret"
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

variable "github_pat" {
  type = string
  description = "GitHub Personal Access Token for managing runners and accessing private repositories"
  sensitive = true
}

# Kubernetes configuration variables
variable "k8s_version" {
  type        = string
  description = "Kubernetes version to install"
  default     = "1.30.0"
}

variable "k8s_pod_cidr" {
  type        = string
  description = "CIDR for Kubernetes pod network"
  default     = "172.16.0.0/16"
}

variable "crio_version" {
  type        = string
  description = "CRI-O container runtime version"
  default     = "1.30"
}

variable "calico_version" {
  type        = string
  description = "Calico CNI version"
  default     = "v3.27.0"
}

# Proxy configuration
variable "http_proxy" {
  type        = string
  description = "HTTP proxy URL"
  default     = "http://10.30.0.11:3128"
}

variable "https_proxy" {
  type        = string
  description = "HTTPS proxy URL"
  default     = "http://10.30.0.11:3128"
}

variable "no_proxy" {
  type        = string
  description = "No-proxy list"
  default     = "localhost,127.0.0.1,10.0.0.0/8,192.168.0.0/16"
}

# GitHub runner configuration
variable "github_runner_org" {
  type        = string
  description = "GitHub organization for self-hosted runners"
}

variable "github_runner_version" {
  type        = string
  description = "GitHub Actions runner version"
  default     = "2.332.0"
}
