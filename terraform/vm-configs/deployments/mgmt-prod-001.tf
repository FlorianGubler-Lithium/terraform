module "mgmt_prod" {
  source = "../../modules/init_vm"

  vm_name   = "mgmt-prod-001"
  vm_id     = 2003
  vm_password = var.vm_password
  vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/mgmt-prod-001/userdata.yaml.tftpl"
  vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/mgmt-prod-001/network.yaml.tftpl"
  vm_ci_base_image_file_id = var.vm_ci_base_image_file_id
  vm_memory = 4096
  vm_cpu_cores = 2
  vm_disk_size = 20
  vm_network_devices = ["prod"]
  ssh_public_key = var.ssh_public_key

  extra_vars = {
    github_runner_setup_script_content = base64encode(file("vm-configs/deployments/scripts/github-runner-setup.sh"))
    github_runner_token = var.github_runner_token_dev
    github_runner_org = var.github_runner_org
  }

  pm_node = var.pm_node
}

