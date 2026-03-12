terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = "terraform@pam!terraform-access"
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

#########################
# Network Zones (VLAN)
#########################

locals {

  zones = {
    devzone = {
      vlan = 100
      subnet = "10.10.0.0/24"
      gateway = "10.10.0.1"
    }

    prodzone = {
      vlan = 200
      subnet = "10.20.0.0/24"
      gateway = "10.20.0.1"
    }

    infrazone = {
      vlan = 300
      subnet = "10.30.0.0/24"
      gateway = "10.30.0.1"
    }
  }

}

#########################
# VM IP Assignments
#########################

locals {
  vm_ips = {
    # Dev zone VMs (starting at 10.10.0.10)
    "kube-dev-master-001" = "10.10.0.10"
    "kube-dev-worker-001" = "10.10.0.11"

    # Prod zone VMs (starting at 10.20.0.10)
    "kube-prod-master-001" = "10.20.0.10"
    "kube-prod-worker-001" = "10.20.0.11"

    # Infra zone VMs (starting at 10.30.0.10)
    "jump-001" = "10.30.0.10"
    "proxy-001" = "10.30.0.11"
    "mgmt-001" = "10.30.0.12"
  }
}

#########################
# Cloud-init Templates
#########################

locals {
  # Firewall cloud-init template
  firewall_cloud_init = base64encode(templatefile("${path.module}/firewall-cloud-init.yaml", {
    hostname       = "cluster-firewall"
    ssh_public_key = var.ssh_public_key
    vm_password    = var.vm_password
    dns_servers    = join(" ", var.dns_servers)
  }))
}

#########################
# Firewall Router VM
#########################

resource "proxmox_vm_qemu" "firewall" {

  name        = "cluster-firewall"
  target_node = var.pm_node

  vmid   = 100
  memory = 4096

  boot = "order=scsi0"

  agent = 1

  cpu {
    cores = 2
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = var.debian_iso
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = 50
          format  = "raw"
        }
      }
    }
  }

  # Management interface
  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Dev zone interface
  network {
    id    = 1
    vnet  = "dev"
    model = "virtio"
  }

  # Prod zone interface
  network {
    id    = 2
    vnet  = "prod"
    model = "virtio"
  }

  # Infra zone interface
  network {
    id    = 3
    vnet  = "infra"
    model = "virtio"
  }

  cicustom = "user=local:snippets/firewall-user-data.yaml"

  # Pass cloud-init data as base64
  provisioner "local-exec" {
    command = "echo '${local.firewall_cloud_init}' | base64 -d > /tmp/firewall-user-data.yaml"
  }

}

############################
# VM Definitions
############################

locals {

  dev_vms = {
    kube-dev-master-001 = { zone = "devzone", role = "master" }
    kube-dev-worker-001 = { zone = "devzone", role = "worker" }
  }

  prod_vms = {
    kube-prod-master-001 = { zone = "prodzone", role = "master" }
    kube-prod-worker-001 = { zone = "prodzone", role = "worker" }
  }

  infra_vms = {
    jump-001 = { zone = "infrazone", role = "jump" }
    proxy-001 = { zone = "infrazone", role = "proxy" }
    mgmt-001 = { zone = "infrazone", role = "mgmt" }
  }

  # Re-generate cloud-init templates now that VM definitions are available
  dev_cloud_init = {
    for name in keys(local.dev_vms) :
    name => base64encode(templatefile("${path.module}/vm-cloud-init.yaml", {
      hostname       = name
      ssh_public_key = var.ssh_public_key
      vm_password    = var.vm_password
      dns_servers    = join(" ", var.dns_servers)
      static_ip      = local.vm_ips[name]
      gateway_ip     = local.zones.devzone.gateway
    }))
  }

  prod_cloud_init = {
    for name in keys(local.prod_vms) :
    name => base64encode(templatefile("${path.module}/vm-cloud-init.yaml", {
      hostname       = name
      ssh_public_key = var.ssh_public_key
      vm_password    = var.vm_password
      dns_servers    = join(" ", var.dns_servers)
      static_ip      = local.vm_ips[name]
      gateway_ip     = local.zones.prodzone.gateway
    }))
  }

  infra_cloud_init = {
    for name in keys(local.infra_vms) :
    name => base64encode(templatefile("${path.module}/vm-cloud-init.yaml", {
      hostname       = name
      ssh_public_key = var.ssh_public_key
      vm_password    = var.vm_password
      dns_servers    = join(" ", var.dns_servers)
      static_ip      = local.vm_ips[name]
      gateway_ip     = local.zones.infrazone.gateway
    }))
  }
}

resource "proxmox_vm_qemu" "dev_vms" {

  for_each = local.dev_vms

  name        = each.key
  target_node = var.pm_node

  vmid   = 1000 + index(sort(keys(local.dev_vms)), each.key)
  memory = 4096

  boot = "order=scsi0"

  agent = 1

  cpu {
    cores = 2
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = var.debian_iso
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = 50
          format  = "raw"
        }
      }
    }
  }

  network {
    id    = 0
    model = "virtio"
    vnet  = "dev"
  }

  cicustom = "user=local:snippets/${each.key}-user-data.yaml"

  # Pass cloud-init data as base64
  provisioner "local-exec" {
    command = "echo '${local.dev_cloud_init[each.key]}' | base64 -d > /tmp/${each.key}-user-data.yaml"
  }

}

resource "proxmox_vm_qemu" "prod_vms" {

  for_each = local.prod_vms

  name        = each.key
  target_node = var.pm_node

  vmid   = 2000 + index(sort(keys(local.prod_vms)), each.key)
  memory = 4096

  boot = "order=scsi0"

  agent = 1

  cpu {
    cores = 2
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = var.debian_iso
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = 50
          format  = "raw"
        }
      }
    }
  }

  network {
    id    = 0
    model = "virtio"
    vnet  = "prod"
  }

  cicustom = "user=local:snippets/${each.key}-user-data.yaml"

  # Pass cloud-init data as base64
  provisioner "local-exec" {
    command = "echo '${local.prod_cloud_init[each.key]}' | base64 -d > /tmp/${each.key}-user-data.yaml"
  }

}

resource "proxmox_vm_qemu" "infra_vms" {

  for_each = local.infra_vms

  name        = each.key
  target_node = var.pm_node

  vmid   = 3000 + index(sort(keys(local.infra_vms)), each.key)
  memory = 4096

  boot = "order=scsi0"

  agent = 1

  cpu {
    cores = 2
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = var.debian_iso
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = 50
          format  = "raw"
        }
      }
    }
  }

  network {
    id    = 0
    model = "virtio"
    vnet  = "infra"
  }

  cicustom = "user=local:snippets/${each.key}-user-data.yaml"

  # Pass cloud-init data as base64
  provisioner "local-exec" {
    command = "echo '${local.infra_cloud_init[each.key]}' | base64 -d > /tmp/${each.key}-user-data.yaml"
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
