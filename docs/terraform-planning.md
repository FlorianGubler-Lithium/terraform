# Terraform Infrastructure Planning

## Current State Analysis

The existing Terraform configuration provides a good foundation with:
- ✅ Proxmox provider configuration
- ✅ VLAN zone definitions (100, 200, 300)
- ✅ VM count and organization by zone
- ✅ Basic VM resource definitions

### Gaps & Improvements Needed

1. **Proxy VM Network Configuration**
   - Current: Single VLAN interface per VM
   - Needed: Proxy VM should have dual interfaces (VLAN 300 + direct Proxmox bridge access)

2. **Ansible Inventory Generation**
   - Current: Static inventory.ini with hardcoded IPs
   - Needed: Dynamic inventory generation from Terraform outputs

3. **Network Bridge Configuration**
   - Current: None - assumes vmbr0 already configured
   - Needed: Terraform documentation on required Proxmox bridge setup

4. **VM Provisioning Details**
   - Current: Missing cloud-init configuration
   - Needed: SSH keys, hostname setup, network configuration via cloud-init

5. **Firewall VM Configuration**
   - Current: Defined but incomplete
   - Needed: Full routing/bridging configuration for VLAN management

6. **Output Organization**
   - Current: No outputs defined
   - Needed: Terraform outputs for IPs, hostnames for Ansible

## Implementation Plan

### Step 1: Enhance Terraform Variables

Add new variables for:
- Cloud-init templates/scripts path
- Default gateway and DNS configuration
- Resource naming conventions
- VM resource specifications (CPU, RAM adjustable by type)

### Step 2: Refactor VM Definitions

```hcl
# New structure supporting role-based specs
locals {
  vm_specs = {
    master   = { cores = 2, memory = 4096 }
    worker   = { cores = 2, memory = 4096 }
    proxy    = { cores = 2, memory = 2048 }
    mgmt     = { cores = 2, memory = 4096 }
    firewall = { cores = 2, memory = 4096 }
  }
}
```

### Step 3: Add Cloud-Init Configuration

- SSH key injection for ansible user
- Hostname configuration matching VM name
- Network interface configuration for zones
- Initial package updates

### Step 4: Implement Dual-NIC for Proxy

```hcl
resource "proxmox_vm_qemu" "proxy_vm" {
  # ...existing...
  
  network {
    # Interface 1: Infra zone VLAN
    model  = "virtio"
    bridge = "vmbr0"
    tag    = local.zones.infrazone.vlan
  }
  
  network {
    # Interface 2: External access to Proxmox host network
    model  = "virtio"
    bridge = "vmbr0"
    # No tag = untagged = access to external network
  }
}
```

### Step 5: Generate Terraform Outputs

```hcl
output "dev_zone_ips" {
  value = {
    for name, vm in proxmox_vm_qemu.dev_vms : name => vm.default_ipv4_address
  }
}

output "prod_zone_ips" {
  value = {
    for name, vm in proxmox_vm_qemu.prod_vms : name => vm.default_ipv4_address
  }
}

output "infra_zone_ips" {
  value = {
    for name, vm in proxmox_vm_qemu.infra_vms : name => vm.default_ipv4_address
  }
}

output "inventory" {
  value = templatefile("${path.module}/inventory.tpl", {
    dev_master  = proxmox_vm_qemu.dev_vms["kube-dev-master-001"].default_ipv4_address
    dev_workers = [for k, v in proxmox_vm_qemu.dev_vms : v.default_ipv4_address if can(regex("worker", k))]
    # ... similar for prod and infra
  })
}
```

### Step 6: Firewall VM Routing Setup

Configure the firewall VM to:
1. Enable IPv4 forwarding
2. Configure iptables/nftables rules for VLAN routing
3. Set up NAT for external access through proxy VM

## Prerequisites for Terraform Apply

1. **Proxmox Access**
   - API user with VM management permissions
   - TLS certificate validation or insecure flag (current: insecure)

2. **VM Templates**
   - `firewall_template`: Pre-configured router image (e.g., Ubuntu 22.04 with UFW)
   - `debian_template`: Standard Debian 12 clone source

3. **Network Prerequisites**
   - vmbr0 bridge configured on Proxmox host
   - VLAN capabilities enabled on Proxmox network interfaces
   - Proper MTU settings (1500 standard, 1550 with VLAN overhead)

4. **Variables Configuration**
   - Create `terraform.tfvars` with API credentials
   - Set target Proxmox node name
   - Confirm template names match actual templates

## Deployment Commands

```bash
# 1. Initialize Terraform
terraform init

# 2. Validate configuration
terraform validate

# 3. Plan infrastructure
terraform plan -out=tfplan

# 4. Apply infrastructure
terraform apply tfplan

# 5. Generate Ansible inventory from outputs
terraform output -raw inventory > ../ansible/inventory.ini

# 6. Export IP mappings for reference
terraform output -json > terraform-outputs.json
```

## Post-Apply Validation

After Terraform apply:
1. Verify all VMs created: `qm list` on Proxmox
2. Check VM network configuration: `ip addr show` on each VM
3. Test zone isolation: ping between zones should fail
4. Verify proxy VM can access external network
5. Confirm SSH access to all VMs from management host

## Rollback Strategy

```bash
# To destroy all resources (WARNING: DATA LOSS)
terraform destroy

# To rollback specific resource
terraform destroy -target proxmox_vm_qemu.dev_vms["vm-name"]

# To modify and reapply
terraform plan -out=tfplan
terraform apply tfplan
```

## Considerations for Multi-Host Scaling

When adding more Proxmox hosts:
1. Update `pm_node` variable with host count
2. Add `target_node` variable to VM resource for host selection
3. Configure bridge replication across hosts
4. Setup storage replication if needed

Example for future expansion:
```hcl
variable "target_nodes" {
  type    = list(string)
  default = ["pve-1"]
  # Future: ["pve-1", "pve-2", "pve-3"]
}

# Distribute VMs across nodes
resource "proxmox_vm_qemu" "dev_vms" {
  for_each = local.dev_vms
  target_node = var.target_nodes[
    sum([for k, v in local.dev_vms : 1 if k <= each.key]) % length(var.target_nodes)
  ]
}
```

## Next Steps

1. ✏️ Update terraform/variables.tf with new variable definitions
2. ✏️ Enhance terraform/main.tf with cloud-init and proxy dual-NIC
3. ✏️ Create terraform/outputs.tf with Ansible inventory generation
4. ✏️ Create terraform/inventory.tpl for Ansible inventory template
5. ✏️ Document Proxmox prerequisites and template setup
6. ✏️ Create terraform/terraform.tfvars.example with required variables

