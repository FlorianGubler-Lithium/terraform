############################
# VM Definitions (Locals)
############################

resource "proxmox_virtual_environment_vm" "all_vms" {
  for_each = local.vm_configs

  name      = each.value.name
  node_name = var.pm_node
  vm_id     = each.value.vm_id

  memory {
    dedicated = each.value.memory
  }

  initialization {
    user_data_file_id    = proxmox_virtual_environment_file.cloud_user_config[each.key].id
    network_data_file_id = proxmox_virtual_environment_file.cloud_network_config[each.key].id
  }

  keyboard_layout = "de-ch"
  boot_order      = ["ide2", "scsi0"]

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu_cores
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.debian_cloud_image.id
    interface    = "scsi0"
    size         = each.value.disk_size
  }

  # Create network devices dynamically based on bridges list
  dynamic "network_device" {
    for_each = each.value.bridges
    content {
      bridge = network_device.value
      model  = "virtio"
    }
  }

  depends_on = [
    proxmox_virtual_environment_sdn_applier.sdn_applier,
    for dep_name in each.value.depends_on_vms :
    proxmox_virtual_environment_vm.all_vms[dep_name]
  ]
}

