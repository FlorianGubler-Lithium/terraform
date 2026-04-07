output "deployment_vms" {
  description = "All deployment VMs with their metadata for Ansible inventory"
  value = merge([
    for module_name, module_obj in module.instances : {
      (module_name) = module_obj.vm_metadata
    } if can(module_obj.vm_metadata)
  ]...)
}

