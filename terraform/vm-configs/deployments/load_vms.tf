module "deployment_vms" {
  source = "../../modules/init_vm"

  for_each = local.deployment_vms

  vm_name                     = each.key
  vm_id                       = each.value.vm_id

  pm_node                     = var.pm_node

  vm_ci_base_image_file_id    = var.vm_ci_base_image_file_id
  vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/${each.value.vm_ci_base_image_file_id}/userdata.yaml.tftpl"
  vm_ci_userdata_file_path    = "vm-configs/deployments/cloud-init/${each.value.vm_ci_base_image_file_id}/network.yaml.tftpl"

  vm_cpu_cores                = each.value.vm_cpu_cores
  vm_disk_size                = each.value.vm_disk_size
  vm_memory                   = each.value.vm_memory

  vm_network_devices = [
    for net_dev in each.value.vm_network_devices : {
      bridge = net_dev.bridge
      ip     = net_dev.ip
    }
  ]

  vm_password                 = var.vm_password
  ssh_public_key              = var.ssh_public_key
}

