#########################
# Cloud-init Configuration Files
#########################

# Firewall cloud-init with hostname substitution
resource "proxmox_virtual_environment_file" "cloud_config_firewall" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "firewall-cloud-init.yaml"
    data = templatefile("${path.module}/cloud-init/userdata/firewall-cloud-init.yaml", {
      hostname      = "cluster-firewall"
      vm_password   = var.vm_password
      dns_servers   = jsonencode(var.dns_servers)
      ssh_public_key = var.ssh_public_key
    })
  }
}

# Firewall network configuration
resource "proxmox_virtual_environment_file" "network_config_firewall" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "firewall-network-config.yaml"
    data = file("${path.module}/cloud-init/network/firewall-network-config.yaml")
  }
}

# Dev VMs network configuration
resource "proxmox_virtual_environment_file" "network_config_dev" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "dev-network-config.yaml"
    data = file("${path.module}/cloud-init/network/dev-network-config.yaml")
  }
}

# Dev VMs cloud-init with per-VM hostname substitution
resource "proxmox_virtual_environment_file" "cloud_config_dev" {
  for_each = local.dev_vms

  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "cloud-init-${each.key}.yaml"
    data = templatefile("${path.module}/cloud-init/userdata/vm-cloud-init.yaml", {
      hostname      = each.key
      vm_password   = var.vm_password
      dns_servers   = jsonencode(var.dns_servers)
      ssh_public_key = var.ssh_public_key
    })
  }
}

# Prod VMs network configuration
resource "proxmox_virtual_environment_file" "network_config_prod" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "prod-network-config.yaml"
    data = file("${path.module}/cloud-init/network/prod-network-config.yaml")
  }
}

# Prod VMs cloud-init with per-VM hostname substitution
resource "proxmox_virtual_environment_file" "cloud_config_prod" {
  for_each = local.prod_vms

  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "cloud-init-${each.key}.yaml"
    data = templatefile("${path.module}/cloud-init/userdata/vm-cloud-init.yaml", {
      hostname      = each.key
      vm_password   = var.vm_password
      dns_servers   = jsonencode(var.dns_servers)
      ssh_public_key = var.ssh_public_key
    })
  }
}

# Infra VMs network configuration
resource "proxmox_virtual_environment_file" "network_config_infra" {
  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "infra-network-config.yaml"
    data = file("${path.module}/cloud-init/network/infra-network-config.yaml")
  }
}

# Infra VMs cloud-init with per-VM hostname substitution
resource "proxmox_virtual_environment_file" "cloud_config_infra" {
  for_each = local.infra_vms

  node_name = var.pm_node
  datastore_id = "local"

  content_type = "snippets"

  source_raw {
    file_name = "cloud-init-${each.key}.yaml"
    data = templatefile("${path.module}/cloud-init/userdata/vm-cloud-init.yaml", {
      hostname      = each.key
      vm_password   = var.vm_password
      dns_servers   = jsonencode(var.dns_servers)
      ssh_public_key = var.ssh_public_key
    })
  }
}

