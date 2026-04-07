module "kube_dev_master" {
  source = "../../modules/init_vm"

  for_each = local.deployment_vms

  vm_name                     = each.key
  pm_node                     = each.value.pm_node
  ssh_public_key              = each.value.ssh_public_key
  vm_ci_base_image_file_id    = each.value.vm_ci_base_image_file_id
  vm_ci_networkdata_file_path = each.value.vm_ci_networkdata_file_path
  vm_ci_userdata_file_path    = each.value.vm_ci_userdata_file_path
  vm_cpu_cores                = each.value.vm_cpu_cores
  vm_disk_size                = each.value.vm_disk_size
  vm_id                       = each.value.vm_id
  vm_memory                   = each.value.vm_memory
  vm_network_devices = [
    for net_dev in each.value.vm_network_devices : {
      bridge = net_dev.bridge
      ip     = net_dev.ip
    }
  ]
  vm_password                 = each.value.vm_password
}

