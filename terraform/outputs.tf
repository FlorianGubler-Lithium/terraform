# Terraform Outputs for Kubernetes Infrastructure

#########################
# Firewall VM Outputs
#########################

output "firewall_vmid" {
  description = "Firewall VM ID"
  value       = proxmox_virtual_environment_vm.firewall.vm_id
}

output "firewall_name" {
  description = "Firewall VM hostname"
  value       = proxmox_virtual_environment_vm.firewall.name
}

#########################
# Dev Zone VM Outputs
#########################

output "dev_vms" {
  description = "Dev zone VM details"
  value = {
    for name, vm in proxmox_virtual_environment_vm.dev_vms : name => {
      vmid   = vm.vm_id
      name   = vm.name
      role   = local.dev_vms[name].role
    }
  }
}

#########################
# Prod Zone VM Outputs
#########################

output "prod_vms" {
  description = "Prod zone VM details"
  value = {
    for name, vm in proxmox_virtual_environment_vm.prod_vms : name => {
      vmid   = vm.vm_id
      name   = vm.name
      role   = local.prod_vms[name].role
    }
  }
}

#########################
# Infra Zone VM Outputs
#########################

output "infra_vms" {
  description = "Infra zone VM details"
  value = {
    for name, vm in proxmox_virtual_environment_vm.infra_vms : name => {
      vmid   = vm.vm_id
      name   = vm.name
      role   = local.infra_vms[name].role
    }
  }
}

#########################
# Ansible Inventory Output
#########################

output "inventory" {
  description = "Ansible inventory in INI format"
  value = templatefile("${path.module}/inventory.tpl", {
    firewall = {
      vmid = proxmox_virtual_environment_vm.firewall.vm_id
      name = proxmox_virtual_environment_vm.firewall.name
    }
    dev_vms  = { for name, vm in proxmox_virtual_environment_vm.dev_vms : name => { vmid = vm.vm_id, role = local.dev_vms[name].role } }
    prod_vms = { for name, vm in proxmox_virtual_environment_vm.prod_vms : name => { vmid = vm.vm_id, role = local.prod_vms[name].role } }
    infra_vms = { for name, vm in proxmox_virtual_environment_vm.infra_vms : name => { vmid = vm.vm_id, role = local.infra_vms[name].role } }
  })
}

#########################
# Summary Output
#########################

output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    total_vms = (
      1 +  # firewall
      length(local.dev_vms) +
      length(local.prod_vms) +
      length(local.infra_vms)
    )
    firewall = 1
    dev_vms  = length(local.dev_vms)
    prod_vms = length(local.prod_vms)
    infra_vms = length(local.infra_vms)
  }
}

