# Lithium Infrastructure Architecture

## Overview

A complete home server infrastructure built on Proxmox with three isolated network zones, each containing Kubernetes clusters or management/networking services. The architecture is fully defined in Infrastructure-as-Code using Terraform and configured via Ansible.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Proxmox Host                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  │   Dev Zone       │  │   Prod Zone      │  │   Infra Zone     │
│  │  (VLAN 100)      │  │  (VLAN 200)      │  │  (VLAN 300)      │
│  │ 10.10.0.0/24     │  │ 10.20.0.0/24     │  │ 10.30.0.0/24     │
│  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│  │ │ k8s-master-1 │ │  │ │ k8s-master-1 │ │  │ │ mgmt-console │ │
│  │ │ (10.10.0.10) │ │  │ │ (10.20.0.10) │ │  │ │ (10.30.0.10) │ │
│  │ └──────────────┘ │  │ └──────────────┘ │  │ └──────────────┘ │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│  │ │ k8s-worker-1 │ │  │ │ k8s-worker-1 │ │  │ │ http-proxy   │ │
│  │ │ (10.10.0.11) │ │  │ │ (10.20.0.11) │ │  │ │ (10.30.0.11) │ │
│  │ └──────────────┘ │  │ └──────────────┘ │  │ │ (ext. access)│ │
│  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ └──────────────┘ │
│  │ │ k8s-worker-2 │ │  │ │ k8s-worker-2 │ │  └──────────────────┘
│  │ │ (10.10.0.12) │ │  │ │ (10.20.0.12) │ │
│  │ └──────────────┘ │  │ └──────────────┘ │
│  └──────────────────┘  └──────────────────┘
│
│  ┌──────────────────────────────────────────┐
│  │      Firewall/Router VM                  │
│  │  - Manages VLAN traffic                  │
│  │  - Routes between zones                  │
│  └──────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
                          │
                          │
                ┌─────────┴─────────┐
                │                   │
         ┌──────▼──────┐      ┌─────▼──────┐
         │  Management │      │   External │
         │    Host     │      │   Network  │
         │(Terraform/  │      │            │
         │Ansible)     │      │            │
         └─────────────┘      └────────────┘
```

## Network Zones

### Dev Zone (VLAN 100)
- **Subnet**: 10.10.0.0/24
- **Purpose**: Development and testing environment
- **VMs**:
  - `kube-dev-master-001` (10.10.0.10): Kubernetes control plane
  - `kube-dev-worker-001` (10.10.0.11): Worker node
  - `kube-dev-worker-002` (10.10.0.12): Worker node
  - `mgmt-dev-001` (10.10.0.20): Management access point (optional)
- **Network Policy**: Internal only, all traffic through firewall

### Prod Zone (VLAN 200)
- **Subnet**: 10.20.0.0/24
- **Purpose**: Production environment
- **VMs**:
  - `kube-prod-master-001` (10.20.0.10): Kubernetes control plane
  - `kube-prod-worker-001` (10.20.0.11): Worker node
  - `kube-prod-worker-002` (10.20.0.12): Worker node
  - `mgmt-prod-001` (10.20.0.20): Management access point (optional)
- **Network Policy**: Internal only, all traffic through firewall

### Infra Zone (VLAN 300)
- **Subnet**: 10.30.0.0/24
- **Purpose**: Infrastructure services and bastion access
- **VMs**:
  - `mgmt-console-001` (10.30.0.10): GitHub Actions runner & management console
  - `http-proxy-001` (10.30.0.11): HTTP/HTTPS proxy for outbound traffic
    - **Special**: Has dual network interfaces (one on VLAN 300, one on Proxmox host network)
- **Network Policy**: Internal access to dev/prod zones; external egress capability via proxy

## VM Specifications

### Kubernetes Master Nodes
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Storage**: Template-based (full clone recommended)
- **Role**: Kubernetes control plane
- **Post-provision**: kubeadm init, CNI installation, ArgoCD setup

### Kubernetes Worker Nodes
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Storage**: Template-based
- **Role**: Application workload execution
- **Post-provision**: kubeadm join cluster

### Management Console
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Purpose**: GitHub Actions self-hosted runner, kubectl access, ArgoCD repo management
- **Network**: Infra zone only

### HTTP Proxy
- **CPU**: 2 cores
- **RAM**: 2 GB
- **Purpose**: Outbound HTTP/HTTPS proxy for all VMs
- **Network**: Dual interface (10.30.0.11 on VLAN 300 + Proxmox host network access)

### Firewall/Router
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Purpose**: VLAN management, inter-zone routing, network security
- **Network**: 4 interfaces (default + 3 VLAN tags)

## Network Communication Patterns

### Allowed Flows
```
Dev Zone ──────────┐
Prod Zone ────────┤──> Firewall ──> HTTP Proxy ──> External Network
Infra Zone ───────┘
                        │
                        └──> Kubernetes API (control plane)
                        └──> Container Registry (external)
                        └──> GitHub (GitOps webhooks)
```

### Blocked Flows
- Direct zone-to-zone communication (all through firewall)
- Direct external network access from dev/prod/infra zones (through proxy)
- Unencrypted credentials in network traffic (TLS/SSH enforced)

## DNS & Service Discovery

- **Internal DNS**: Each Kubernetes cluster runs CoreDNS
- **External DNS**: Managed by GitHub/Proxmox DNS infrastructure
- **Proxy Resolution**: HTTP proxy uses upstream DNS servers

## GitOps Architecture

```
┌────────────────┐
│  GitHub Repo   │
│ (This Project) │
└────────┬───────┘
         │
         │ Webhook
         ▼
┌────────────────────┐
│  ArgoCD Instance   │
│  (k8s-dev & prod)  │
└────────┬───────────┘
         │
         │ Syncs
         ▼
┌────────────────────────────────────┐
│  Helm Charts & K8s Resources       │
│  - cicd/* (all infra packages)     │
│  - Monitoring (Prometheus/Grafana) │
│  - Service Mesh (if used)          │
└────────────────────────────────────┘
```

## Security Boundaries

1. **Network Isolation**: VLAN separation prevents accidental zone-to-zone traffic
2. **Egress Control**: All outbound traffic from dev/prod/infra through HTTP proxy
3. **Access Control**: 
   - Management host: SSH to mgmt-console, then to other zones
   - External users: Through mgmt-console GitHub Actions
   - Inter-cluster: Kubernetes API with RBAC
4. **Credentials Management**: 
   - Terraform secrets (pm_password, etc.) via secure variables
   - Kubernetes secrets via sealed-secrets (cicd/sealed-secrets)
   - GitHub Actions secrets for deployment

## Deployment Phases

### Phase 1: Bootstrap (Manual - Management Host)
- Prerequisites check (Proxmox access, templates, network)
- Terraform apply: Create VMs and firewall configuration
- Ansible inventory generation from Terraform outputs

### Phase 2: Infrastructure Configuration (Ansible)
- Proxy setup: Configure HTTP proxy service
- Kubernetes: kubeadm init/join on all nodes
- Network validation: Verify zone isolation and proxy routing

### Phase 3: GitOps Activation (Ansible/kubectl)
- ArgoCD installation and initial configuration
- Git repository linking
- Application definitions synced from cicd/* folder

### Phase 4: Continuous Management (GitOps)
- All infrastructure changes via Git commits
- ArgoCD automatic sync
- GitHub Actions for testing and validation

## Disaster Recovery

- **VM Backups**: Proxmox snapshots (weekly)
- **Cluster State**: Kubernetes etcd backups (daily)
- **Configuration**: Complete Infrastructure-as-Code (Git history)
- **Recovery Time Objective (RTO)**: 30-60 minutes (full cluster rebuild)
- **Recovery Point Objective (RPO)**: 1 day (last backup)

## Future Expansion

The architecture supports:
- **Additional Proxmox Hosts**: New hosts added to cluster with bridge configuration
- **Additional Kubernetes Clusters**: New VLANs and zones can be added
- **High Availability**: Master node promotion, etcd clustering, load balancing
- **Persistent Storage**: Shared storage backend (NFS/Ceph) for StatefulSets

