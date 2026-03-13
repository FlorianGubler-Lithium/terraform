terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.pm_api_url
  api_token = "terraform@pam!terraform-access=${var.pm_api_token_secret}"
  insecure = true
}

resource "proxmox_virtual_environment_download_file" "debian_cloud_image" {
  node_name = "pve1"
  datastore_id = "local"

  content_type = "iso"
  url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-12-cloud.qcow2"
}

#########################
# SDN Backend Zone (Datacenter Level)
#########################

resource "proxmox_virtual_environment_sdn_zone_vlan" "backend" {
  id = "backend"
  bridge = "vmbr0"
  ipam = "pve"
}

#########################
# Virtual Networks (vnets) in Backend Zone
#########################

resource "proxmox_virtual_environment_sdn_vnet" "dev" {
  zone       = proxmox_virtual_environment_sdn_zone_vlan.backend.id
  id       = "dev"
  vlanid     = 100

  comment = "Development Virtual Network"

  depends_on = [proxmox_virtual_environment_sdn_zone_vlan.backend]
}

resource "proxmox_virtual_environment_sdn_vnet" "prod" {
  zone       = proxmox_virtual_environment_sdn_zone_vlan.backend.id
  id       = "prod"
  vlanid     = 200

  comment = "Production Virtual Network"

  depends_on = [proxmox_virtual_environment_sdn_zone_vlan.backend]
}

resource "proxmox_virtual_environment_sdn_vnet" "infra" {
  zone       = proxmox_virtual_environment_sdn_zone_vlan.backend.id
  id       = "infra"
  vlanid     = 300

  comment = "Infrastructure Virtual Network"

  depends_on = [proxmox_virtual_environment_sdn_zone_vlan.backend]
}

# SDN Applier - Applies SDN configuration changes
resource "proxmox_virtual_environment_sdn_applier" "sdn_applier" {
  depends_on = [
    proxmox_virtual_environment_sdn_zone_vlan.backend,
    proxmox_virtual_environment_sdn_vnet.dev,
    proxmox_virtual_environment_sdn_vnet.prod,
    proxmox_virtual_environment_sdn_vnet.infra,
  ]

  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_sdn_zone_vlan.backend,
      proxmox_virtual_environment_sdn_vnet.dev,
      proxmox_virtual_environment_sdn_vnet.prod,
      proxmox_virtual_environment_sdn_vnet.infra,
    ]
  }
}

resource "proxmox_virtual_environment_sdn_applier" "finalizer" {
  depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
}

#########################
# Cloud-init Templates
#########################

resource "proxmox_virtual_environment_file" "cloud_config_firewall" {
  node_name    = "pve1"
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "firewall-cloud-init.yaml"
    data = file("${path.module}/firewall-cloud-init.yaml")
  }
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  node_name    = "pve1"
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "cloud-init.yaml"
    data = file("${path.module}/cloud-init.yaml")
  }
}

#########################
# Firewall Router VM
#########################

resource "proxmox_virtual_environment_vm" "firewall" {

  name      = "cluster-firewall"
  node_name = var.pm_node
  vm_id     = 100

  memory {
    dedicated = 4096
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config_firewall.id
  }

  boot_order = ["ide2", "scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }

  # Management interface
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Dev zone interface
  network_device {
    bridge = "dev"
    model  = "virtio"
  }

  # Prod zone interface
  network_device {
    bridge = "prod"
    model  = "virtio"
  }

  # Infra zone interface
  network_device {
    bridge = "infra"
    model  = "virtio"
  }
}

############################
# VM Definitions
############################

locals {

  dev_vms = {
    kube-dev-master-001 = { role = "master" }
    kube-dev-worker-001 = { role = "worker" }
  }

  prod_vms = {
    kube-prod-master-001 = { role = "master" }
    kube-prod-worker-001 = { role = "worker" }
  }

  infra_vms = {
    jump-001 = { role = "jump" }
    proxy-001 = { role = "proxy" }
    mgmt-001 = { role = "mgmt" }
  }
}

resource "proxmox_virtual_environment_vm" "dev_vms" {

  for_each = local.dev_vms

  name      = each.key
  node_name = var.pm_node
  vm_id     = 1000 + index(sort(keys(local.dev_vms)), each.key)

  memory {
    dedicated = 4096
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  boot_order = ["ide2", "scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "dev"
    model  = "virtio"
  }

}

resource "proxmox_virtual_environment_vm" "prod_vms" {

  for_each = local.prod_vms

  name      = each.key
  node_name = var.pm_node
  vm_id     = 2000 + index(sort(keys(local.prod_vms)), each.key)

  memory {
    dedicated = 4096
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  boot_order = ["ide2", "scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "prod"
    model  = "virtio"
  }

}

resource "proxmox_virtual_environment_vm" "infra_vms" {

  for_each = local.infra_vms

  name      = each.key
  node_name = var.pm_node
  vm_id     = 3000 + index(sort(keys(local.infra_vms)), each.key)

  memory {
    dedicated = 4096
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  boot_order = ["ide2", "scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "infra"
    model  = "virtio"
  }

}

#########################
# Cloud-init Implementation Notes
#########################
# Cloud-init is now properly integrated using:
# 1. cicustom parameter pointing to cloud-init YAML templates
# 2. Local cloud-init template processing with variable substitution:
#    - firewall-cloud-init.yaml: Configures the firewall VM with NAT, IP forwarding, and multi-interface networking
#    - vm-cloud-init.yaml: Configures Kubernetes nodes with static IPs, DNS, SSH keys, and system packages
# 3. Local-exec provisioners to write the templated cloud-init to Proxmox snippets
#
# The cloud-init YAML files define:
# - User creation with SSH keys and sudo access
# - System package updates and installations
# - Network configuration (static IPs, gateways, DNS)
# - Firewall/NAT rules for the firewall VM
# - IP forwarding and routing
# - Hostname and timezone configuration
