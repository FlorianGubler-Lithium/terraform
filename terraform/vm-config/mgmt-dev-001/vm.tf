terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

variable "pm_node" {
  type = string
}

variable "user_data_file_base" {
  type = map(object({
    id = string
  }))
}

variable "network_data_file_base" {
  type = map(object({
    id = string
  }))
}

variable "debian_cloud_image_id" {
  type = string
}

variable "sdn_applier" {}

locals {
  vm_name = basename(path.module)
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = local.vm_name
  node_name = var.pm_node
  vm_id     = 1003

  memory { dedicated = 4096 }

  initialization {
    user_data_file_id    = var.user_data_file_base[local.vm_name].id
    network_data_file_id = var.network_data_file_base["${local.vm_name}"].id
  }

  keyboard_layout = "de-ch"
  boot_order      = ["ide2", "scsi0"]

  agent { enabled = true }
  cpu { cores = 2 }

  disk {
    datastore_id = "local-lvm"
    file_id      = var.debian_cloud_image_id
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge = "dev"
    model  = "virtio"
  }

  depends_on = [var.sdn_applier]
}

output "vm" { value = proxmox_virtual_environment_vm.vm }
