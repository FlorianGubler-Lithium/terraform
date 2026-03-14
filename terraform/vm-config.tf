##########################
# VM Configs
##########################

locals {
  # Set of all VM subdirectories in vm-config/
  vm_list = toset(sort(fileset("${path.module}/vm-config", "*")))
}

##########################
# Download Cloud Images to Proxmox Storage
##########################

resource "proxmox_virtual_environment_download_file" "debian_cloud_image" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "import"
  url = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-cloud.qcow2"
  overwrite = true
}

#########################
# Cloud-init Configuration Files
#########################

resource "proxmox_virtual_environment_file" "cloud_user_config" {
  for_each = local.vm_list

  node_name    = var.pm_node
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "${each.key}-cloud-init.yaml"
    data = templatefile("${path.module}/vm-config/${each.key}/userdata.yaml.tftpl", {
      hostname       = each.key
      vm_password    = var.vm_password
      dns_servers    = jsonencode(var.dns_servers)
      ssh_public_key = var.ssh_public_key
    })
  }
}

resource "proxmox_virtual_environment_file" "cloud_network_config" {
  for_each = local.vm_list

  node_name    = var.pm_node
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "${each.key}-network-config.yaml"
    data      = templatefile("${path.module}/vm-config/${each.key}/network.yaml.tftpl", {})
  }
}
