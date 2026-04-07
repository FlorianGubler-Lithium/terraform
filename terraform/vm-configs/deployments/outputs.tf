output "deployment_vms" {
  description = "All deployment VMs with their metadata for Ansible inventory"
  value = {
    deployment_vms = module.deployment_vms.vm_metadata
  }
}

