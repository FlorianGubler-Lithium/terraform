module "firewall_vm" {
  source = "../../modules/init_vm/"

  vm_name   = "firewall-001"
  vm_id     = 100
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/infra/cloud-init/firewall-001/user_data.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/infra/cloud-init/firewall-001/network_data.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = ["dev", "prod", "infra"]
  ssh_public_key = var.ssh_public_key

  pm_node = var.pm_node

  depends_on = [module.proxy_vm]
}