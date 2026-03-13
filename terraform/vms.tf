############################
# VM Definitions (Locals)
############################

locals {
  dev_vms = {
    kube-dev-master-001 = { role = "master" }
    kube-dev-worker-001 = { role = "worker" }
    mgmt-001 = { role = "mgmt" }
  }

  prod_vms = {
    kube-prod-master-001 = { role = "master" }
    kube-prod-worker-001 = { role = "worker" }
    mgmt-001 = { role = "mgmt" }
  }

  infra_vms = {
    jump-001 = { role = "jump" }
    proxy-001 = { role = "proxy" }
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
    network_data_file_id = proxmox_virtual_environment_file.network_config_firewall.id
  }

  keyboard_layout = "de-ch"
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

  depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
}

#########################
# Dev VMs
#########################

# resource "proxmox_virtual_environment_vm" "dev_vms" {
#   for_each = local.dev_vms
#
#   name      = each.key
#   node_name = var.pm_node
#   vm_id     = 1000 + index(sort(keys(local.dev_vms)), each.key)
#
#   memory {
#     dedicated = 4096
#   }
#
#   initialization {
#     user_data_file_id = proxmox_virtual_environment_file.cloud_config_dev[each.key].id
#     network_data_file_id = proxmox_virtual_environment_file.network_config_dev.id
#   }
#
#   keyboard_layout = "de-ch"
#   boot_order = ["ide2", "scsi0"]
#
#   agent {
#     enabled = true
#   }
#
#   cpu {
#     cores = 2
#   }
#
#   disk {
#     datastore_id = "local-lvm"
#     file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
#     interface    = "scsi0"
#     size         = 20
#   }
#
#   network_device {
#     bridge = "dev"
#     model  = "virtio"
#   }
#
#   depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
# }
#
# #########################
# # Prod VMs
# #########################
#
# resource "proxmox_virtual_environment_vm" "prod_vms" {
#   for_each = local.prod_vms
#
#   name      = each.key
#   node_name = var.pm_node
#   vm_id     = 2000 + index(sort(keys(local.prod_vms)), each.key)
#
#   memory {
#     dedicated = 4096
#   }
#
#   initialization {
#     user_data_file_id = proxmox_virtual_environment_file.cloud_config_prod[each.key].id
#     network_data_file_id = proxmox_virtual_environment_file.network_config_prod.id
#   }
#
#   keyboard_layout = "de-ch"
#   boot_order = ["ide2", "scsi0"]
#
#   agent {
#     enabled = true
#   }
#
#   cpu {
#     cores = 2
#   }
#
#   disk {
#     datastore_id = "local-lvm"
#     file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
#     interface    = "scsi0"
#     size         = 20
#   }
#
#   network_device {
#     bridge = "prod"
#     model  = "virtio"
#   }
#
#   depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
# }
#
# #########################
# # Infra VMs
# #########################
#
# resource "proxmox_virtual_environment_vm" "infra_vms" {
#   for_each = local.infra_vms
#
#   name      = each.key
#   node_name = var.pm_node
#   vm_id     = 3000 + index(sort(keys(local.infra_vms)), each.key)
#
#   memory {
#     dedicated = 4096
#   }
#
#   initialization {
#     user_data_file_id = proxmox_virtual_environment_file.cloud_config_infra[each.key].id
#     network_data_file_id = proxmox_virtual_environment_file.network_config_infra.id
#   }
#
#   keyboard_layout = "de-ch"
#   boot_order = ["ide2", "scsi0"]
#
#   agent {
#     enabled = true
#   }
#
#   cpu {
#     cores = 2
#   }
#
#   disk {
#     datastore_id = "local-lvm"
#     file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
#     interface    = "scsi0"
#     size         = 20
#   }
#
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
#
#   network_device {
#     bridge = "infra"
#     model  = "virtio"
#   }
#
#   depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
# }

