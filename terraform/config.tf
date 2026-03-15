locals {
  # Proxmox API Endpoint and Node Configuration
  pm_api_url = "https://192.168.1.25:8006"
  pm_node = "prx-001"

  # GitHub Runner Configuration
  github_runner_org = "FlorianGubler-Lithium"
  github_runner_version = "v2.332.0"

  # Proxmox VM Configuration
  backend_network_configurations = {
    dev = {
      cidr      = "10.10.0.0/24"
      gateway   = "10.10.0.1"
      tag = 100
      managed   = true
    }
    prod = {
      cidr      = "10.20.0.0/24"
      gateway   = "10.20.0.1"
      tag = 200
      managed   = true
    }
    infra = {
      cidr      = "10.30.0.0/24"
      gateway   = "10.30.0.1"
      tag = 300
      managed   = true
    }
    # VMBR0 is the default bridge on Proxmox not a vnet
    vmbr0 = {
      cidr      = "192.168.1.0/24"
      gateway   = "192.168.1.1"
      managed   = false
    }
  }
}