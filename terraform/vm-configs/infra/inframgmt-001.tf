resource "random_password" "semaphore_cookie_hash" {
  length  = 32
  special = true
}

resource "random_password" "semaphore_cookie_encryption" {
  length  = 32
  special = true
}

resource "random_password" "semaphore_access_key_encryption" {
  length  = 32
  special = true
}

module "ansible_vm" {
  source = "../../modules/init_vm/"

  vm_name   = "inframgmt-001"
  vm_id     = 3011
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/infra/cloud-init/inframgmt-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/infra/cloud-init/inframgmt-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = [
    {
      bridge = "vmbr0"
      ip     = "192.168.1.32"
    },
    {
      bridge = "infra"
      ip     = "10.30.0.20"
    }
  ]
  ssh_public_key = var.ssh_public_key

  # Semaphore configuration
  extra_vars = {
    semaphore_version                = var.semaphore_version
    semaphore_admin_password         = var.semaphore_admin_password
    semaphore_db_password            = var.semaphore_db_password
    semaphore_cookie_hash            = base64encode(random_password.semaphore_cookie_hash.result)
    semaphore_cookie_encryption      = base64encode(random_password.semaphore_cookie_encryption.result)
    semaphore_access_key_encryption  = base64encode(random_password.semaphore_access_key_encryption.result)
  }

  pm_node = var.pm_node

  depends_on = [module.proxy_vm]
}

