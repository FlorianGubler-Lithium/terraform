# Documentation Index

Welcome to the Lithium Infrastructure documentation! This repository contains complete infrastructure-as-code for a homeserver with Proxmox, Kubernetes, and ArgoCD.

## Quick Navigation

### 🚀 Getting Started
- **[Quick Start](quick-start.md)** - 10-minute setup guide (TL;DR version)
- **[Deployment Guide](deployment-guide.md)** - Comprehensive step-by-step deployment with troubleshooting

### 📐 Architecture & Design
- **[Architecture Overview](architecture.md)** - System design, network zones, VM specifications, security boundaries
- **[Network Design](network-design.md)** - VLAN topology, IP planning, firewall rules, DNS configuration
- **[Terraform Planning](terraform-planning.md)** - Infrastructure-as-Code design, VM specifications, prerequisites

### 🛠️ Implementation
- **[Ansible Strategy](ansible-strategy.md)** - Playbook structure, roles, variable management, execution flow
- **[ArgoCD Integration](argocd-integration.md)** - GitOps workflow, application definitions, secret management

### 📋 Operations
- **[Operations Runbook](operations-runbook.md)** - Daily/weekly tasks, common operations, escalation procedures
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues, diagnostics, recovery procedures
- **[This Index](INDEX.md)** - Documentation navigation guide

---

## By Use Case

### I want to set up the infrastructure
1. Read: [Quick Start](quick-start.md)
2. Follow: [Deployment Guide](deployment-guide.md)
3. Reference: [Architecture Overview](architecture.md) for context

### I need to understand the system design
1. Start: [Architecture Overview](architecture.md)
2. Deep dive: [Network Design](network-design.md)
3. Infrastructure details: [Terraform Planning](terraform-planning.md)

### I'm deploying new applications
1. Reference: [ArgoCD Integration](argocd-integration.md) - Application definitions
2. Follow: GitOps workflow in ArgoCD guide
3. Monitor: Via Kubernetes dashboard or `kubectl`

### Something is broken
1. Check: [Troubleshooting Guide](troubleshooting.md)
2. Search: By symptom and expected behavior
3. Escalate: Follow procedures in [Operations Runbook](operations-runbook.md)

### I'm running daily operations
1. Use: [Operations Runbook](operations-runbook.md)
2. Reference: Command cheat sheets
3. Monitor: Daily health checks

---

## Documentation Structure

```
docs/
├── INDEX.md                      # This file
├── quick-start.md               # 10-minute TL;DR setup
├── deployment-guide.md          # Comprehensive step-by-step
├── architecture.md              # System design & overview
├── network-design.md            # Network topology & configuration
├── terraform-planning.md        # IaC design & specifications
├── ansible-strategy.md          # Configuration management
├── argocd-integration.md        # GitOps & continuous deployment
├── operations-runbook.md        # Daily operations & procedures
├── troubleshooting.md           # Issue diagnosis & resolution
└── README.md                    # Project overview
```

---

## Key Concepts

### Three Network Zones

| Zone | VLAN | Subnet | Purpose | Access |
|------|------|--------|---------|--------|
| **Dev** | 100 | 10.10.0.0/24 | Development K8s cluster | Internal only |
| **Prod** | 200 | 10.20.0.0/24 | Production K8s cluster | Internal only |
| **Infra** | 300 | 10.30.0.0/24 | Management & proxy | Internal + external |

### VM Architecture

```
Proxmox Host
├── Firewall (manages VLAN routing)
├── Dev Zone: 1 Master + 2 Workers + 1 Management VM
├── Prod Zone: 1 Master + 2 Workers + 1 Management VM
└── Infra Zone: 1 Management Console + 1 HTTP Proxy
```

### Infrastructure as Code

- **Terraform**: Provisions VMs, networks, firewall rules
- **Ansible**: Configures systems, installs Kubernetes, deploys services
- **Helm/ArgoCD**: Manages all cluster resources declaratively via Git
- **Git**: Single source of truth for all configuration

### Deployment Automation

```
Git Repository
    ↓
    ├─→ GitHub Actions (CI tests)
    └─→ ArgoCD (continuous deployment)
         ├─→ Dev Cluster (auto-sync)
         └─→ Prod Cluster (auto-sync with approval)
```

---

## Common Scenarios

### Scenario: Deploy a new service

**Path**: [ArgoCD Integration](argocd-integration.md) → Create Application → Commit to Git → ArgoCD syncs automatically

**Time**: 5-10 minutes

**Risk**: Low (can easily rollback via Git)

### Scenario: Add a second Kubernetes cluster

**Path**: [Terraform Planning](terraform-planning.md) → Update Terraform → Run playbooks → Add to ArgoCD

**Time**: 30-45 minutes

**Risk**: Medium (requires testing new zone)

### Scenario: Recover from node failure

**Path**: [Troubleshooting Guide](troubleshooting.md) → Diagnose → [Operations Runbook](operations-runbook.md) → Rebuild

**Time**: 15-30 minutes

**Risk**: Medium (cluster continues running on remaining nodes)

### Scenario: Perform Kubernetes upgrade

**Path**: [Operations Runbook](operations-runbook.md) → Follow upgrade procedure → Validate

**Time**: 1-2 hours

**Risk**: High (requires careful sequencing)

---

## Decision Trees

### "System isn't working - where do I start?"

```
├─ Check if it's a network issue
│  └─ [Network Design](network-design.md) → Topology & rules
│  └─ [Troubleshooting](troubleshooting.md) → Network section
│
├─ Check if it's a Kubernetes issue
│  └─ [Troubleshooting](troubleshooting.md) → Kubernetes section
│  └─ Check node/pod status with kubectl
│
├─ Check if it's an infrastructure issue
│  └─ [Troubleshooting](troubleshooting.md) → VM/Proxmox section
│  └─ Check Proxmox host status
│
├─ Check if it's an ArgoCD issue
│  └─ [Troubleshooting](troubleshooting.md) → ArgoCD section
│  └─ Check application sync status
│
└─ If still unresolved
   └─ [Operations Runbook](operations-runbook.md) → Escalation procedures
   └─ Collect logs and contact team
```

### "How do I do X?"

```
Deploying an app?
  → [ArgoCD Integration](argocd-integration.md) → Application definitions

Scaling a deployment?
  → [Operations Runbook](operations-runbook.md) → Common tasks → Scaling

Upgrading Kubernetes?
  → [Operations Runbook](operations-runbook.md) → Common tasks → Updating K8s

Adding a new network zone?
  → [Network Design](network-design.md) → Plan IP ranges
  → [Terraform Planning](terraform-planning.md) → Add VMs
  → [Ansible Strategy](ansible-strategy.md) → Bootstrap

Changing network topology?
  → [Network Design](network-design.md) → Design new layout
  → [Terraform Planning](terraform-planning.md) → Update infrastructure

Accessing a VM?
  → SSH: ssh ubuntu@<ip-address>
  → Console: via Proxmox web UI
  → qm: qm enter <vmid>
```

---

## Glossary

| Term | Definition |
|------|-----------|
| **ArgoCD** | GitOps continuous deployment tool for Kubernetes |
| **CICD** | Continuous Integration/Continuous Deployment pipeline |
| **CNI** | Container Network Interface (pod networking) |
| **ETCD** | Kubernetes cluster state database |
| **GitOps** | Infrastructure management via Git version control |
| **Helm** | Kubernetes package manager |
| **IaC** | Infrastructure as Code (Terraform) |
| **K8s** | Kubernetes (container orchestration) |
| **Proxmox** | Virtualization platform (hypervisor) |
| **VLAN** | Virtual Local Area Network (network isolation) |

---

## Version Information

- **Created**: March 2026
- **Kubernetes**: 1.28.x
- **Proxmox**: 7.x or 8.x
- **Terraform**: 1.5+
- **Ansible**: 2.12+
- **ArgoCD**: 2.8+

---

## Contributing to Documentation

When updating documentation:

1. Keep it accurate and up-to-date
2. Use examples from actual deployments
3. Include troubleshooting steps
4. Cross-reference related docs
5. Use clear, technical language
6. Include command examples
7. Note any security implications

---

## Document Maintenance

Each document should be reviewed and updated:

- **Monthly**: Quick Start and Deployment Guide
- **Quarterly**: Architecture and Network Design
- **As needed**: Troubleshooting and Operations Runbook
- **After changes**: All affected documentation

---

## External References

- [Proxmox Documentation](https://pve.proxmox.com/wiki/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)

---

## Support & Contact

For issues or questions:

1. Check relevant documentation section
2. Review [Troubleshooting Guide](troubleshooting.md)
3. Contact infrastructure team: [team email/slack]
4. Create issue in GitHub repository

---

**Last Updated**: March 2026
**Next Review**: June 2026

