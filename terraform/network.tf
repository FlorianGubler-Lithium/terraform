#########################
# SDN Backend Zone (Datacenter Level)
#########################

resource "proxmox_virtual_environment_sdn_applier" "finalizer" {
}

resource "proxmox_virtual_environment_sdn_zone_vlan" "backend" {
  id = "backend"
  bridge = "vmbr0"
  ipam = "pve"

  depends_on = [
    proxmox_virtual_environment_sdn_applier.finalizer
  ]
}

#########################
# Virtual Networks (vnets) in Backend Zone
#########################

resource "proxmox_virtual_environment_sdn_vnet" "backend_vnets" {
  for_each = {
    for k, v in local.network_configurations :
    k => v if try(v.managed, false)
  }

  zone       = proxmox_virtual_environment_sdn_zone_vlan.backend.id
  id       = each.key
  tag     = each.value.tag

  depends_on = [
    proxmox_virtual_environment_sdn_applier.finalizer
  ]
}

resource "proxmox_virtual_environment_sdn_subnet" "backend_dhcp_subnets" {
  for_each = {
    for k, v in local.network_configurations :
    k => v if try(v.managed, false)
  }

  vnet = proxmox_virtual_environment_sdn_vnet.backend_vnets[each.key].id

  cidr    = each.value.cidr
  gateway = each.value.gateway

  dhcp_range = {
    start_address = cidrhost(each.value.cidr, 10)
    end_address   = cidrhost(each.value.cidr, 200)
  }
}

#########################
# SDN Applier
#########################

resource "proxmox_virtual_environment_sdn_applier" "sdn_applier" {
  depends_on = [
    proxmox_virtual_environment_sdn_zone_vlan.backend,
    proxmox_virtual_environment_sdn_vnet.backend_vnets,
    proxmox_virtual_environment_sdn_subnet.backend_dhcp_subnets,
  ]

  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_sdn_zone_vlan.backend,
      proxmox_virtual_environment_sdn_vnet.backend_vnets,
      proxmox_virtual_environment_sdn_subnet.backend_dhcp_subnets,
    ]
  }
}

