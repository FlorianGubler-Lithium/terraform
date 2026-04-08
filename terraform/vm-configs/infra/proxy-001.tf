module "proxy_vm" {
  source = "../../modules/init_vm/"

  vm_name   = "proxy-001"
  vm_id     = 3000
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/infra/cloud-init/proxy-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/infra/cloud-init/proxy-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = [
    {
      bridge = "vmbr0"
      ip     = "192.168.1.31"
    },
    {
      bridge = "infra"
      ip     = "10.30.0.11"
    }
  ]
  ssh_public_key = var.ssh_public_key

  pm_node = var.pm_node
}