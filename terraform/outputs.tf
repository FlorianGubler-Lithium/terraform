# Ansible Inventory Output
# Generates the inventory file from Terraform-managed VMs

locals {
  # Convert the deployment VMs into a flat list
  all_vms = [
    for vm in values(module.deployments_vms.deployment_vms) : vm
  ]

  # Create a map of group names to VMs that belong to each group
  ansible_groups = {
    for group in distinct(flatten([for vm in local.all_vms : vm.groups])) :
    group => [for vm in local.all_vms : vm if contains(vm.groups, group)]
  }

  # Generate inventory content
  ansible_inventory = templatefile("${path.module}/templates/inventory.ini.tpl", {
    ansible_groups = local.ansible_groups
  })
}

output "ansible_inventory_data" {
  description = "Data for generating Ansible inventory"
  value = {
    all_vms = local.all_vms
    groups  = local.ansible_groups
  }
}

output "ansible_inventory" {
  description = "Generated Ansible inventory file"
  value       = local.ansible_inventory
  sensitive   = false
}

# Write inventory file to output directory
resource "local_file" "ansible_inventory" {
  content  = local.ansible_inventory
  filename = "${path.module}/../ansible/inventory.ini"
}

