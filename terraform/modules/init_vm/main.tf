resource "proxmox_virtual_environment_file" "ci_userdata" {
  node_name    = var.pm_node
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "ci-${var.vm_name}-userdata.yaml"
    data = templatefile("${path.root}/${var.vm_ci_userdata_file_path}", {
      hostname       = var.vm_name
      vm_password    = var.vm_password
      ssh_public_key = var.ssh_public_key
    })
  }
}

resource "proxmox_virtual_environment_file" "ci_networkdata" {
  node_name    = var.pm_node
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "ci-${var.vm_name}-networkdata.yaml"
    data = templatefile("${path.root}/${var.vm_ci_networkdata_file_path}", {
      hostname       = var.vm_name
      vm_password    = var.vm_password
      ssh_public_key = var.ssh_public_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.pm_node
  vm_id     = var.vm_id

  memory { dedicated = var.vm_memory }

  initialization {
    user_data_file_id    = proxmox_virtual_environment_file.ci_userdata.id
    network_data_file_id = proxmox_virtual_environment_file.ci_networkdata.id
  }

  keyboard_layout = "de-ch"
  boot_order      = ["ide2", "scsi0"]

  agent { enabled = true }
  cpu { cores = var.vm_cpu_cores }

  disk {
    datastore_id = "local-lvm"
    file_id      = var.vm_ci_base_image_file_id
    interface    = "scsi0"
    size         = var.vm_disk_size
  }

  dynamic "network_device" {
    for_each = var.vm_network_devices
    content {
      bridge = network_device.value
      model  = "virtio"
    }
  }
}

output "vm" { value = proxmox_virtual_environment_vm.vm }