# Network Design & Security Architecture

## Network Topology Overview

The infrastructure uses VLAN-based network isolation to create three independent network zones with controlled inter-zone communication and centralized egress control.

```
┌───────────────────────────────────────────────────────────────┐
│                        Proxmox Host                           │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Proxmox Virtual Bridges & VLAN Trunking               │ │
│  │                                                         │ │
│  │  vmbr0 (Untagged) ── External Network                  │ │
│  │  │                                                       │ │
│  │  ├─ VLAN 100 ──────────────────────────────────┐       │ │
│  │  ├─ VLAN 200 ──────────────────────────────────┼─┐     │ │
│  │  ├─ VLAN 300 ──────────────────────────────────┼─┼──┐  │ │
│  │  │                                             │ │  │  │ │
│  │  └─ Firewall VM (4 NICs)                      │ │  │  │ │
│  │                                               │ │  │  │ │
│  └──────────────────────────────────────────────┼─┼──┼──┘  │
│                                                 │ │  │      │
│                              ┌──────────────────┘ │  │      │
│                              │                    │  │      │
│  ┌──────────────────┐ ┌──────▼──────────┐ ┌─────▼──▼────┐ │
│  │  Dev Zone        │ │  Prod Zone      │ │  Infra Zone  │ │
│  │  VLAN 100        │ │  VLAN 200       │ │  VLAN 300    │ │
│  │ 10.10.0.0/24     │ │ 10.20.0.0/24    │ │ 10.30.0.0/24 │ │
│  │                  │ │                 │ │              │ │
│  │ .10 Master       │ │ .10 Master      │ │ .10 Mgmt     │ │
│  │ .11 Worker       │ │ .11 Worker      │ │ .11 Proxy-1  │ │
│  │ .12 Worker       │ │ .12 Worker      │ │ .11 Proxy-2  │ │
│  │ .20 Mgmt (opt)   │ │ .20 Mgmt (opt)  │ │ (dual NIC)   │ │
│  │                  │ │                 │ │              │ │
│  └──────────────────┘ └─────────────────┘ └──────────────┘ │
│                                                               │
└───────────────────────────────────────────────────────────────┘
                              │
                              │ (External Network)
                              │
                    ┌─────────┴──────────┐
                    │                    │
            ┌───────▼────────┐   ┌─────▼───────┐
            │  Management    │   │   External  │
            │  Host          │   │   Networks  │
            │ (SSH/Ansible)  │   │ (Internet)  │
            └────────────────┘   └─────────────┘
```

## VLAN Configuration

### VLAN Breakdown

| Zone | VLAN ID | Subnet | Gateway | Purpose | Broadcast |
|------|---------|--------|---------|---------|-----------|
| Dev | 100 | 10.10.0.0/24 | 10.10.0.1 | Development K8s Cluster | 10.10.0.255 |
| Prod | 200 | 10.20.0.0/24 | 10.20.0.1 | Production K8s Cluster | 10.20.0.255 |
| Infra | 300 | 10.30.0.0/24 | 10.30.0.1 | Management & Proxy | 10.30.0.255 |

### Proxmox Bridge Configuration

Required configuration on Proxmox host (in `/etc/network/interfaces`):

```bash
auto vmbr0
iface vmbr0 inet dhcp
    bridge-ports eth0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# Auto-VLAN tagged bridges (optional - for efficiency)
auto vlan100
iface vlan100 inet static
    address 10.10.0.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0
    vlan-id 100

auto vlan200
iface vlan200 inet static
    address 10.20.0.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0
    vlan-id 200

auto vlan300
iface vlan300 inet static
    address 10.30.0.1
    netmask 255.255.255.0
    vlan-raw-device vmbr0
    vlan-id 300
```

## VM Network Interfaces

### Standard VM (Master/Worker/Management)
```
eth0: VLAN tagged
  - Dev/Prod: Tagged with respective VLAN (100 or 200)
  - Infra Mgmt: Tagged with VLAN 300
  - IP: Assigned via DHCP or static (based on template)
```

### Proxy VM (Dual Interface)
```
eth0: VLAN 300 tagged (Internal Infra Zone)
  - IP: 10.30.0.11
  - Purpose: Communication with management & other zones

eth1: Untagged (Proxmox host network access)
  - IP: <external network IP or DHCP from vmbr0>
  - Purpose: Direct external network access for egress proxy
```

### Firewall VM (4 Interfaces)
```
eth0: Untagged (Management/monitoring)
  - IP: 10.0.0.5 (or DHCP from vmbr0)
  - Purpose: Proxmox management access

eth1: VLAN 100 tagged (Dev Zone)
  - IP: 10.10.0.1
  - Purpose: Dev zone gateway

eth2: VLAN 200 tagged (Prod Zone)
  - IP: 10.20.0.1
  - Purpose: Prod zone gateway

eth3: VLAN 300 tagged (Infra Zone)
  - IP: 10.30.0.1
  - Purpose: Infra zone gateway
```

## IP Address Plan

### Dev Zone (10.10.0.0/24)
```
10.10.0.1   - Firewall/Gateway
10.10.0.10  - kube-dev-master-001
10.10.0.11  - kube-dev-worker-001
10.10.0.12  - kube-dev-worker-002
10.10.0.20  - mgmt-dev-001 (optional)
10.10.0.30-10.10.0.254 - Reserved for future expansion
```

### Prod Zone (10.20.0.0/24)
```
10.20.0.1   - Firewall/Gateway
10.20.0.10  - kube-prod-master-001
10.20.0.11  - kube-prod-worker-001
10.20.0.12  - kube-prod-worker-002
10.20.0.20  - mgmt-prod-001 (optional)
10.20.0.30-10.20.0.254 - Reserved for future expansion
```

### Infra Zone (10.30.0.0/24)
```
10.30.0.1   - Firewall/Gateway
10.30.0.10  - mgmt-console-001
10.30.0.11  - http-proxy-001 (with external access)
10.30.0.20  - Proxy-002 (future HA setup)
10.30.0.30-10.30.0.254 - Reserved
```

### Kubernetes Pod Networks (Internal to each cluster)
```
Dev Cluster Pod Network: 10.244.0.0/16
Prod Cluster Pod Network: 10.245.0.0/16
```

### Kubernetes Service Networks (Internal to each cluster)
```
Dev Cluster Service Network: 10.96.0.0/12
Prod Cluster Service Network: 10.97.0.0/12
```

## Network Policies & Traffic Rules

### Policy Framework

All inter-zone communication must go through the firewall VM. Direct zone-to-zone traffic is blocked at the VLAN level.

### Allowed Flows

```
1. Dev Zone → Firewall → External
   - HTTP/HTTPS: Via proxy VM
   - DNS: 8.8.8.8, 1.1.1.1
   - NTP: External NTP servers
   - Security: TLS for all connections

2. Prod Zone → Firewall → External
   - HTTP/HTTPS: Via proxy VM
   - DNS: 8.8.8.8, 1.1.1.1
   - NTP: External NTP servers
   - Security: TLS required

3. Infra Zone (Management) → Any Zone
   - SSH: To any master/worker node
   - kubectl: To Kubernetes API servers
   - ArgoCD: Git webhooks from external

4. Proxy VM ↔ All Zones
   - Accepts HTTP/HTTPS connections on port 3128
   - Connects to external networks without restriction
   - Can be reached by any VM via http_proxy environment variable

5. External Network → Proxy VM
   - SSH: Optional (for management)
   - HTTP/HTTPS: For container image pulls and external APIs

6. Within Zone
   - All traffic allowed (internal communication)
   - Kubernetes API, etcd, kubelet communication
   - CoreDNS queries
```

### Blocked Flows

```
- Dev Zone ↔ Prod Zone (direct)
- Dev Zone ↔ Infra Zone (direct) - except to proxy
- Prod Zone ↔ Infra Zone (direct) - except to proxy
- Any Zone → External (direct) - must use proxy
- Unencrypted credentials (if detected)
```

### Firewall Rules (iptables/nftables on Firewall VM)

```bash
# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Dev Zone (eth1: 10.10.0.0/24)
iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth1 -o eth2 -j DROP  # No prod access
iptables -A FORWARD -i eth1 -o eth3 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Prod Zone (eth2: 10.20.0.0/24)
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth1 -j DROP  # No dev access
iptables -A FORWARD -i eth2 -o eth3 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Infra Zone (eth3: 10.30.0.0/24)
iptables -A FORWARD -i eth3 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth3 -o eth1 -j ACCEPT  # Can reach dev
iptables -A FORWARD -i eth3 -o eth2 -j ACCEPT  # Can reach prod

# NAT for outbound access through proxy
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

## HTTP Proxy Configuration

### Proxy Service (on 10.30.0.11)

Software: Squid 5.x or 6.x

```
Listening Port: 3128
Cache Size: 5000 MB
Max Connections: 1000

ACL Rules:
- Allow: 10.0.0.0/8 (all internal networks)
- Allow: GitHub.com (for ArgoCD webhooks)
- Allow: Docker Hub, Kubernetes registries
- Deny: All other external

Upstream DNS: 8.8.8.8, 1.1.1.1
```

### VM Proxy Configuration

All VMs set environment variables:
```bash
export http_proxy=http://10.30.0.11:3128
export https_proxy=http://10.30.0.11:3128
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,.local,.lithium
```

Applied in:
- `/etc/environment` (system-wide)
- `/etc/apt/apt.conf.d/proxy.conf` (APT)
- Kubernetes config (container runtime)

## DNS Resolution

### Internal DNS (Within Kubernetes)

Each cluster runs CoreDNS:
- **Dev Cluster**: Handles *.dev.lithium.local
- **Prod Cluster**: Handles *.prod.lithium.local

### External DNS

- **Upstream**: 8.8.8.8, 1.1.1.1 (via proxy)
- **Cluster DNS Service**: 10.96.0.10 (dev), 10.97.0.10 (prod)

### /etc/resolv.conf Configuration

```
# On VMs
nameserver 10.10.0.1      # (dev zone)
nameserver 10.20.0.1      # (prod zone)
nameserver 10.30.0.1      # (infra zone)
nameserver 8.8.8.8        # External (via proxy after k8s setup)
```

## MTU & Network Performance

### MTU Settings

- **Standard Ethernet**: 1500 bytes
- **With VLAN overhead**: 1500 bytes (Proxmox handles)
- **Pod network**: 1450 bytes (for Kubernetes overhead)

Configuration on each VM:
```bash
# Set MTU for VLAN interface
ip link set dev eth0 mtu 1500

# Configure in systemd
echo '[Match]
Name=eth0

[Link]
MTUBytes=1500' > /etc/systemd/network/99-mtu.link
```

## High Availability & Redundancy

### Current Single-Host Setup
- Single Proxmox host
- Single point of failure for entire infrastructure
- Acceptable for homelab, requires backup/snapshot strategy

### Future Multi-Host Setup

When adding a 2nd Proxmox host:

1. **Bridge Replication**
   - Configure VLAN bridges on new host identically
   - Ensure MTU matches across all hosts

2. **VM Distribution**
   - Distribute masters across hosts (HA k8s control plane)
   - Load balance workers

3. **Network Example**
   ```
   Proxmox-1: vlan100, vlan200, vlan300 (Dev Masters)
   Proxmox-2: vlan100, vlan200, vlan300 (Prod Masters + Workers)
   Proxmox-3: vlan100, vlan200, vlan300 (Dev Workers + Proxy)
   ```

4. **Storage Backend**
   - Shared storage (NFS/Ceph) for persistent volumes
   - Separate backup storage for snapshots

## Security Considerations

### Network Segmentation
- ✅ VLAN isolation prevents accidental zone-to-zone traffic
- ✅ Firewall VM enforces traffic policies
- ✅ All external access through single proxy point

### Access Control
- ✅ SSH only from management host to management VM, then to others
- ✅ Kubernetes RBAC for API access
- ✅ No direct external SSH access to any VM

### Data Protection
- ✅ TLS for all external communications
- ✅ Encrypted credentials via Kubernetes secrets
- ✅ Sealed-secrets for GitOps secrets management

### Monitoring & Logging
- ✅ Firewall rule enforcement visibility
- ✅ Proxy access logs for compliance
- ✅ Kubernetes audit logs for API access tracking

## Troubleshooting Guide

### Connectivity Issues

```bash
# Test zone connectivity
ping 10.10.0.10  # Dev zone
ping 10.20.0.10  # Prod zone
ping 10.30.0.1   # Infra gateway

# Test via firewall
traceroute 10.20.0.10  # Should show firewall gateway

# Check firewall rules
ssh firewall 'sudo iptables -L -v'

# Monitor traffic
ssh firewall 'sudo tcpdump -i eth1 icmp'
```

### Proxy Issues

```bash
# Test proxy connectivity
curl -x http://10.30.0.11:3128 https://api.github.com

# Check proxy logs
ssh proxy 'sudo tail -f /var/log/squid/access.log'

# Verify upstream DNS
ssh proxy 'nslookup github.com 8.8.8.8'
```

### VLAN Issues

```bash
# Verify VLAN config on Proxmox
cat /etc/network/interfaces

# Check VM VLAN membership
ssh vm 'ip link show'

# Monitor VLAN traffic
sudo tcpdump -i vlan100 -c 10

# Test VLAN routing
ping -I eth0.100 10.10.0.10
```

## Network Backup & Disaster Recovery

### Backup Strategy
- Configuration files: `/etc/network/interfaces` (Git)
- Firewall rules: Export via `iptables-save`
- VM network configs: Proxmox snapshot (weekly)

### Recovery
1. Restore Proxmox host network configuration
2. Rebuild VMs from snapshots
3. Restore firewall rules via `iptables-restore`
4. Validate connectivity via playbook re-run

