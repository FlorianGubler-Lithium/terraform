module "kube_prod_worker" {
  source = "../../modules/init_vm"

  vm_name   = "kube-prod-worker-001"
  vm_id     = 2002
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-worker-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-worker-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = [
    {
      bridge = "prod"
      ip     = "10.20.0.202"
    }
  ]
  ssh_public_key = var.ssh_public_key

  pm_node = var.pm_node
}

