terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">=2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}

#########################
# Automatic node lookup
#########################

data "proxmox_nodes" "cluster_nodes" {}

locals {
  target_node = data.proxmox_nodes.cluster_nodes.names[0]
}

#########################
# Network Zones (VLAN)
#########################

locals {

  zones = {
    devzone = {
      vlan = 100
      subnet = "10.10.0.0/24"
    }

    prodzone = {
      vlan = 200
      subnet = "10.20.0.0/24"
    }

    infrazone = {
      vlan = 300
      subnet = "10.30.0.0/24"
    }
  }

}

#########################
# Firewall Router VM
#########################

resource "proxmox_vm_qemu" "firewall" {

  name        = "cluster-firewall"
  target_node = local.target_node
  clone       = var.firewall_template

  cores  = 2
  memory = 4096

  agent = 1

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  network {
    bridge = "vmbr0"
    tag    = local.zones.devzone.vlan
    model  = "virtio"
  }

  network {
    bridge = "vmbr0"
    tag    = local.zones.prodzone.vlan
    model  = "virtio"
  }

  network {
    bridge = "vmbr0"
    tag    = local.zones.infrazone.vlan
    model  = "virtio"
  }

}

############################
# VM Definitions
############################

locals {

  dev_vms = {
    kube-dev-master-001 = { zone = "devzone", role = "master" }
    kube-dev-worker-001 = { zone = "devzone", role = "worker" }
    kube-dev-worker-002 = { zone = "devzone", role = "worker" }
    mgmt-dev-001 = { zone = "devzone", role = "mgmt" }
  }

  prod_vms = {
    kube-prod-master-001 = { zone = "prodzone", role = "master" }
    kube-prod-worker-002 = { zone = "prodzone", role = "worker" }
    kube-prod-worker-002 = { zone = "prodzone", role = "worker" }
    mgmt-prod-001 = { zone = "prodzone", role = "mgmt" }
  }

  infra_vms = {
    jump-001 = { zone = "infrazone", role = "jump" }
    proxy-001 = { zone = "infrazone", role = "proxy" }
  }

  all_vms = merge(local.dev_vms, local.prod_vms, local.infra_vms)
}

resource "proxmox_vm_qemu" "dev_vms" {

  count = length(local.dev_vms)

  name        = local.dev_vms[count.index]
  target_node = local.target_node
  clone       = var.debian_template

  cores  = 2
  memory = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = local.zones.devzone.vlan
  }

}

resource "proxmox_vm_qemu" "prod_vms" {

  count = length(local.prod_vms)

  name        = local.prod_vms[count.index]
  target_node = local.target_node
  clone       = var.debian_template

  cores  = 2
  memory = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = local.zones.prodzone.vlan
  }

}

resource "proxmox_vm_qemu" "infra_vms" {

  count = length(local.infra_vms)

  name        = local.infra_vms[count.index]
  target_node = local.target_node
  clone       = var.debian_template

  cores  = 2
  memory = 4096

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = local.zones.infrazone.vlan
  }

}
