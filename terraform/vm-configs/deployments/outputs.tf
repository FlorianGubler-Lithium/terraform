output "deployment_vms" {
  description = "All deployment VMs with their metadata for Ansible inventory"
  value = {
    mgmt_dev  = module.mgmt_dev.vm_metadata
    mgmt_prod = module.mgmt_prod.vm_metadata
  }
}

