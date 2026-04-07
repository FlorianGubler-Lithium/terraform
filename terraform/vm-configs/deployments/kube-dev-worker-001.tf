module "kube_dev_worker" {
  source = "../../modules/init_vm"

  vm_name   = "kube-dev-worker-001"
  vm_id     = 1002
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/kube-dev-worker-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-dev-worker-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = [
    {
      bridge = "dev"
      ip     = "10.10.0.102"
    }
  ]
  ssh_public_key = var.ssh_public_key

  pm_node = var.pm_node
}

