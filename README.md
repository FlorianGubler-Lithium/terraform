# Lithium Infrastructure

Complete Infrastructure-as-Code for a homeserver with Proxmox, Kubernetes, and GitOps automation.

## Overview

Lithium is a production-grade home infrastructure setup featuring:

- **3 Isolated Network Zones** (Dev, Prod, Infra) via VLAN isolation
- **2 Kubernetes Clusters** (Dev & Prod) with 3 nodes each (1 master + 2 workers)
- **Infrastructure Services** (HTTP proxy, management console, ArgoCD)
- **Complete IaC** via Terraform + Ansible
- **GitOps Automation** using ArgoCD for continuous deployment
- **Security by Default** with network isolation and centralized egress control

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/your-org/lithium-infra.git
cd lithium-infra

# 2. Configure Proxmox access
export TF_VAR_pm_password="your-proxmox-password"
export TF_VAR_vm_password="your-vm-password"

# 3. Deploy infrastructure (15-20 minutes)
cd terraform && terraform init && terraform apply -auto-approve

# 4. Generate inventory from Terraform outputs
terraform output -raw inventory > ../ansible/inventory.ini

# 5. Bootstrap all services (30-45 minutes)
cd ../ansible && ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml

# 6. Access your cluster
ssh ubuntu@10.10.0.10  # Dev master
kubectl get nodes
```

**Total deployment time: ~90 minutes** (with prerequisites installed)

👉 **[Read the Quick Start Guide](docs/quick-start.md)** for detailed instructions

## Architecture

```
Proxmox Host
├── Dev Zone (10.10.0.0/24, VLAN 100)
│   ├── kube-dev-master-001 (10.10.0.10)
│   ├── kube-dev-worker-001 (10.10.0.11)
│   └── kube-dev-worker-002 (10.10.0.12)
│
├── Prod Zone (10.20.0.0/24, VLAN 200)
│   ├── kube-prod-master-001 (10.20.0.10)
│   ├── kube-prod-worker-001 (10.20.0.11)
│   └── kube-prod-worker-002 (10.20.0.12)
│
├── Infra Zone (10.30.0.0/24, VLAN 300)
│   ├── mgmt-console-001 (10.30.0.10) - GitHub Actions runner
│   └── http-proxy-001 (10.30.0.11) - Centralized egress control
│
└── Firewall VM (manages VLAN routing and inter-zone policies)
```

👉 **[Full Architecture Details](docs/architecture.md)**

## Documentation

| Document | Purpose |
|----------|---------|
| **[INDEX.md](docs/INDEX.md)** | Documentation navigation and decision trees |
| **[Quick Start](docs/quick-start.md)** | 10-minute setup guide (TL;DR) |
| **[Deployment Guide](docs/deployment-guide.md)** | Step-by-step deployment with troubleshooting |
| **[Architecture](docs/architecture.md)** | System design, zones, security boundaries |
| **[Network Design](docs/network-design.md)** | VLAN topology, IP planning, firewall rules |
| **[Terraform Planning](docs/terraform-planning.md)** | IaC design, VM specs, prerequisites |
| **[Ansible Strategy](docs/ansible-strategy.md)** | Playbook structure, roles, variables |
| **[ArgoCD Integration](docs/argocd-integration.md)** | GitOps workflow, app definitions |
| **[Operations Runbook](docs/operations-runbook.md)** | Daily tasks, common operations, escalation |
| **[Troubleshooting](docs/troubleshooting.md)** | Issue diagnosis and resolution |

**Start here:** [Documentation Index](docs/INDEX.md)

## Key Features

### Infrastructure as Code
- **Terraform**: Provisions 10 VMs with VLAN isolation, networking, firewall rules
- **Ansible**: Configures systems, installs Kubernetes, deploys services
- **Helm**: Packages all infrastructure components
- **Git**: Single source of truth for all configuration

### Kubernetes
- **2 Clusters**: Dev (testing) and Prod (stable)
- **Version**: 1.28.x (configurable)
- **CNI**: Flannel for pod networking
- **Storage**: Local path provisioner (upgradeable to distributed storage)
- **Ingress**: Traefik for external access

### Network Isolation
- **3 VLAN Zones**: Dev (100), Prod (200), Infra (300)
- **Firewall VM**: Enforces inter-zone traffic policies
- **Proxy VM**: Centralized HTTP/HTTPS egress control
- **Security**: All zones isolated, all external access routed through proxy

### GitOps
- **ArgoCD**: Continuous deployment from Git
- **Automatic Sync**: Infrastructure changes via commit
- **Self-Healing**: Cluster corrects drift from desired state
- **Sealed Secrets**: Encrypted credential management

### Monitoring & Operations
- **Health Checks**: Daily validation procedures
- **Backups**: Etcd snapshots and VM snapshots
- **Logs**: Centralized access to system, pod, and network logs
- **Runbooks**: Procedures for common operations and emergencies

## Repository Structure

```
lithium-infra/
├── terraform/              # Infrastructure provisioning
│   ├── main.tf            # VM and network definitions
│   ├── variables.tf       # Input variables
│   └── terraform.tfvars   # Configuration (gitignored)
│
├── ansible/               # Configuration management
│   ├── playbooks/         # Bootstrap and operational playbooks
│   ├── roles/             # Ansible roles (base, k8s, proxy, etc.)
│   ├── group_vars/        # Group-specific variables
│   ├── host_vars/         # Host-specific overrides
│   └── inventory.ini      # Generated from Terraform outputs
│
├── cicd/                  # Helm charts and K8s resources
│   ├── argocd/           # ArgoCD core deployment
│   ├── traefik/          # Ingress controller
│   ├── prometheus/       # Monitoring
│   ├── grafana/          # Dashboards
│   ├── sealed-secrets/   # Secret encryption
│   ├── cert-manager/     # HTTPS certificates
│   ├── metallb/          # Load balancer
│   └── applications/     # App definitions per environment
│
├── docs/                  # Complete documentation
│   ├── INDEX.md          # Navigation and decision trees
│   ├── quick-start.md    # 10-minute setup
│   ├── deployment-guide.md
│   ├── architecture.md
│   ├── network-design.md
│   ├── terraform-planning.md
│   ├── ansible-strategy.md
│   ├── argocd-integration.md
│   ├── operations-runbook.md
│   └── troubleshooting.md
│
└── README.md             # This file
```

## Prerequisites

### Management Host (Your Laptop/Workstation)
- Terraform 1.5+
- Ansible 2.12+
- kubectl 1.28+
- Helm 3.12+
- Git & SSH client

**Install (macOS):** `brew install terraform ansible kubectl helm git jq`

**Install (Ubuntu/Debian):** `sudo apt install terraform ansible kubectl helm git jq`

### Proxmox Host
- Proxmox 7.x or 8.x
- 16+ GB RAM (minimum, 32+ GB recommended)
- 100+ GB disk space for VMs
- VM templates configured (see [Deployment Guide](docs/deployment-guide.md))
- VLAN-capable network interface

### Network
- 3x /24 subnets allocated (10.10.0.0/24, 10.20.0.0/24, 10.30.0.0/24)
- Proxmox host must be reachable from management host
- Internet access for package downloads (via proxy VM)

## Getting Started

### 1. Read Documentation (30 minutes)
Start with [Documentation Index](docs/INDEX.md) and [Architecture](docs/architecture.md) to understand the system design.

### 2. Deploy Infrastructure (90 minutes)
Follow [Quick Start](docs/quick-start.md) or detailed [Deployment Guide](docs/deployment-guide.md).

### 3. Verify Installation (15 minutes)
Run health checks and confirm all nodes are Ready: `kubectl get nodes`

### 4. Deploy Applications (Ongoing)
Use [ArgoCD Integration](docs/argocd-integration.md) guide to deploy workloads via GitOps.

### 5. Manage Operations (Ongoing)
Reference [Operations Runbook](docs/operations-runbook.md) for daily tasks and troubleshooting.

## Common Commands

```bash
# View cluster health
kubectl get nodes
kubectl get pods -A

# Access specific cluster
ssh ubuntu@10.10.0.10    # Dev master
ssh ubuntu@10.20.0.10    # Prod master

# Check infrastructure
ssh root@proxmox "qm list"           # List VMs
ansible all -i ansible/inventory.ini -m ping

# Access ArgoCD
kubectl -n argocd port-forward svc/argocd-server 8443:443 &
# https://localhost:8443

# View Terraform state
terraform -chdir=terraform show

# Re-run playbooks
ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap-all.yml
```

**Full command reference:** See [Operations Runbook](docs/operations-runbook.md)

## Troubleshooting

**Something not working?** Check [Troubleshooting Guide](docs/troubleshooting.md)

Common issues:
- **VMs not booting**: See VM Issues section
- **Kubernetes nodes NotReady**: See Kubernetes Issues section
- **Network connectivity broken**: See Network & Connectivity section
- **ArgoCD not syncing**: See ArgoCD Issues section

## Support

1. **Check documentation**: Start with [Documentation Index](docs/INDEX.md)
2. **Search troubleshooting**: [Troubleshooting Guide](docs/troubleshooting.md)
3. **Review logs**: `kubectl logs`, Ansible output, Proxmox logs
4. **Escalate**: Follow procedures in [Operations Runbook](docs/operations-runbook.md)

## Security

This infrastructure is designed with security in mind:

- ✅ **Network Isolation**: VLAN separation prevents zone-to-zone traffic
- ✅ **Egress Control**: All external traffic through proxy VM
- ✅ **Access Control**: SSH only from management, Kubernetes RBAC
- ✅ **Encryption**: TLS for external communications, sealed-secrets for credentials
- ✅ **Auditability**: Terraform/Git history, Kubernetes audit logs

**Security details:** See [Network Design](docs/network-design.md) and [Architecture](docs/architecture.md)

## Maintenance

### Daily
- Health check: All nodes Ready, all pods Running
- Monitor proxy traffic
- Review cluster logs

### Weekly
- Update system packages
- Check certificate expiry
- Clean up old images
- Review disk usage

### Monthly
- Test disaster recovery
- Update documentation
- Plan capacity needs

**Full maintenance schedule:** [Operations Runbook](docs/operations-runbook.md)

## Disaster Recovery

Complete recovery from state loss is possible because:

1. **Infrastructure is code**: Terraform recreates all VMs
2. **Configuration is code**: Ansible restores all settings
3. **Applications are code**: ArgoCD redeploys from Git
4. **Cluster state is backed up**: Etcd snapshots enable point-in-time recovery

**Recovery procedures:** [Operations Runbook](docs/operations-runbook.md) → Disaster Recovery

## Contributing

To contribute to Lithium:

1. Fork the repository
2. Create a feature branch
3. Update code and documentation
4. Submit a pull request
5. Update docs/INDEX.md and relevant guides

Follow Git commits: `infrastructure/feature`, `docs/update`, `fix/issue`

## License

[Your License Here]

## Authors

Created by: [Your Name/Team]

## Changelog

### v1.0.0 (March 2026)
- Initial release with 2 Kubernetes clusters
- 3 VLAN zones with network isolation
- ArgoCD GitOps automation
- Complete documentation

## Roadmap

- [ ] High Availability (multiple masters per cluster)
- [ ] Persistent storage backend (NFS/Ceph)
- [ ] Multi-zone failover
- [ ] Advanced monitoring (Prometheus/Grafana integration)
- [ ] Service mesh (Istio/Linkerd)
- [ ] GitOps OIDC authentication

## Resources

- **Proxmox**: https://pve.proxmox.com/wiki/
- **Terraform**: https://www.terraform.io/docs
- **Ansible**: https://docs.ansible.com/
- **Kubernetes**: https://kubernetes.io/docs/
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Helm**: https://helm.sh/docs/

---

**Questions?** Check [Documentation Index](docs/INDEX.md)

**Ready to deploy?** Start with [Quick Start](docs/quick-start.md)
