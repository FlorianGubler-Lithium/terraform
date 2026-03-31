# Generate dynamic Ansible inventory from VM metadata
# This file creates ansible/inventory.ini organized by environment and role

locals {
  # Collect all VM metadata for inventory generation
  all_vms = merge(
    { for k, v in module.mgmt_dev.*.vm_metadata : "mgmt_dev" => v if length(module.mgmt_dev) > 0 },
    { for k, v in module.mgmt_prod.*.vm_metadata : "mgmt_prod" => v if length(module.mgmt_prod) > 0 },
    # Add k8s VMs when enabled
    { for k, v in module.kube_dev_master.*.vm_metadata : "kube_dev_master" => v if length(module.kube_dev_master) > 0 },
    { for k, v in module.kube_dev_worker.*.vm_metadata : "kube_dev_worker" => v if length(module.kube_dev_worker) > 0 },
    { for k, v in module.kube_prod_master.*.vm_metadata : "kube_prod_master" => v if length(module.kube_prod_master) > 0 },
    { for k, v in module.kube_prod_worker.*.vm_metadata : "kube_prod_worker" => v if length(module.kube_prod_worker) > 0 },
  )

  # Organize VMs by group
  k8s_masters_dev = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "dev" && v.role == "k8s_master"
  }
  k8s_workers_dev = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "dev" && v.role == "k8s_worker"
  }
  k8s_masters_prod = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "prod" && v.role == "k8s_master"
  }
  k8s_workers_prod = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "prod" && v.role == "k8s_worker"
  }
  github_runners_dev = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "dev" && v.role == "github_runner"
  }
  github_runners_prod = {
    for k, v in local.all_vms : v.name => v
    if v.environment == "prod" && v.role == "github_runner"
  }
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    k8s_masters_dev    = local.k8s_masters_dev
    k8s_workers_dev    = local.k8s_workers_dev
    k8s_masters_prod   = local.k8s_masters_prod
    k8s_workers_prod   = local.k8s_workers_prod
    github_runners_dev = local.github_runners_dev
    github_runners_prod = local.github_runners_prod
  })

  depends_on = [
    module.mgmt_dev,
  ]
}

output "ansible_inventory_file" {
  value       = local_file.ansible_inventory.filename
  description = "Path to generated Ansible inventory file"
}

