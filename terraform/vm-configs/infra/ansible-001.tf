module "ansible_vm" {
  source = "../../modules/init_vm/"

  vm_name   = "ansible-001"
  vm_id     = 3011
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/infra/cloud-init/ansible-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/infra/cloud-init/ansible-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = [
    {
      bridge = "vmbr0"
      ip     = "192.168.1.32/24"
    },
    {
      bridge = "infra"
      ip     = "10.30.0.20/24"
    }
  ]
  ssh_public_key = var.ssh_public_key

  pm_node = var.pm_node

  depends_on = [module.proxy_vm]
}

