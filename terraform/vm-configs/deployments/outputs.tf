output "kube_dev_master_vm" {
  description = "Kubernetes Dev Master VM module outputs"
  value       = module.kube_dev_master
}

output "kube_dev_worker_vm" {
  description = "Kubernetes Dev Worker VM module outputs"
  value       = module.kube_dev_worker
}

output "kube_prod_master_vm" {
  description = "Kubernetes Prod Master VM module outputs"
  value       = module.kube_prod_master
}

output "kube_prod_worker_vm" {
  description = "Kubernetes Prod Worker VM module outputs"
  value       = module.kube_prod_worker
}

output "mgmt_dev_vm" {
  description = "Management Dev VM module outputs"
  value       = module.mgmt_dev
}

output "mgmt_prod_vm" {
  description = "Management Prod VM module outputs"
  value       = module.mgmt_prod
}

