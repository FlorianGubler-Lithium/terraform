##########################
# Download Cloud Images to Proxmox Storage
##########################

resource "proxmox_virtual_environment_download_file" "vm_ci_base_image" {
  node_name = local.pm_node
  datastore_id = "local"

  content_type = "import"
  url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-cloud.qcow2"
  overwrite = true # Download image can change as "latest" will be updated and we want to keep it up to date
}

############################
# Infrastructure VM Module
############################

module "infra_vms" {
  source = "./vm-configs/infra"

  pm_node               = local.pm_node
  vm_ci_base_image_file_id = proxmox_virtual_environment_download_file.vm_ci_base_image.id
  vm_password = var.vm_password
  ssh_public_key = var.ssh_public_key

  depends_on = [proxmox_virtual_environment_sdn_applier.sdn_applier]
}
