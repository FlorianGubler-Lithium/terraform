# Ansible Configuration Strategy

## Overview

Ansible orchestrates the entire post-VM provisioning workflow:
1. **Proxy Setup**: Configure HTTP proxy service for outbound traffic
2. **Kubernetes Clustering**: Bootstrap k8s-dev and k8s-prod clusters
3. **Network Validation**: Verify zone isolation and connectivity
4. **ArgoCD Deployment**: Install and configure GitOps automation

## Inventory Structure

### Current State
- Static `ansible/inventory.ini` with hardcoded IPs
- Issue: Manual IP updates required after VM creation

### Target State
- Dynamic inventory generated from Terraform outputs
- Dynamic inventory script reading from Proxmox API
- Host grouping by zone, role, and cluster

### Proposed Inventory Structure

```ini
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3

# Dev Kubernetes Cluster
[k8s_dev_masters]
kube-dev-master-001 ansible_host=10.10.0.10

[k8s_dev_workers]
kube-dev-worker-001 ansible_host=10.10.0.11
kube-dev-worker-002 ansible_host=10.10.0.12

[k8s_dev:children]
k8s_dev_masters
k8s_dev_workers

# Prod Kubernetes Cluster
[k8s_prod_masters]
kube-prod-master-001 ansible_host=10.20.0.10

[k8s_prod_workers]
kube-prod-worker-001 ansible_host=10.20.0.11
kube-prod-worker-002 ansible_host=10.20.0.12

[k8s_prod:children]
k8s_prod_masters
k8s_prod_workers

# Infrastructure
[infra_management]
mgmt-console-001 ansible_host=10.30.0.10

[infra_proxy]
http-proxy-001 ansible_host=10.30.0.11

[infra_firewall]
cluster-firewall ansible_host=10.30.0.1

[infra:children]
infra_management
infra_proxy
infra_firewall

# Zone-level grouping
[devzone:children]
k8s_dev
mgmt-dev-001

[prodzone:children]
k8s_prod
mgmt-prod-001

[infrazone:children]
infra

# Global groups
[k8s_masters:children]
k8s_dev_masters
k8s_prod_masters

[k8s_workers:children]
k8s_dev_workers
k8s_prod_workers

[k8s_all:children]
k8s_masters
k8s_workers

[proxy]
http-proxy-001
```

## Playbook Structure

### Directory Layout
```
ansible/
├── playbooks/
│   ├── 00-base-setup.yml          # Common tasks for all VMs
│   ├── 01-proxy-setup.yml         # HTTP proxy configuration
│   ├── 02-k8s-prerequisites.yml   # Kubernetes dependencies
│   ├── 03-k8s-bootstrap.yml       # Master init and worker join
│   ├── 04-k8s-networking.yml      # CNI and network policies
│   ├── 05-argocd-setup.yml        # ArgoCD installation
│   └── bootstrap-all.yml          # Main orchestration playbook
├── roles/
│   ├── base/
│   │   └── tasks/main.yml         # System updates, SSH keys
│   ├── proxy/
│   │   ├── tasks/main.yml
│   │   ├── templates/squid.conf.j2
│   │   └── handlers/main.yml
│   ├── k8s-control/
│   │   ├── tasks/main.yml         # kubeadm init
│   │   └── templates/kubeadm-config.yaml.j2
│   ├── k8s-node/
│   │   ├── tasks/main.yml         # kubeadm join
│   │   └── files/
│   ├── k8s-cni/
│   │   ├── tasks/main.yml         # Flannel or Calico
│   │   └── files/cni-*.yaml
│   ├── k8s-storage/
│   │   └── tasks/main.yml         # Local path provisioner
│   └── argocd/
│       ├── tasks/main.yml
│       ├── templates/
│       └── files/
├── group_vars/
│   ├── k8s_all.yml                # Kubernetes-wide vars
│   ├── k8s_dev.yml                # Dev-specific vars
│   ├── k8s_prod.yml               # Prod-specific vars
│   ├── proxy.yml                  # Proxy-specific vars
│   └── all.yml                    # Global variables
├── host_vars/
│   └── kube-dev-master-001.yml    # Host-specific overrides
├── templates/
│   ├── inventory.tpl              # For Terraform output
│   └── ...
└── inventory.ini                  # Generated from Terraform
```

## Variable Management

### Group Variables (group_vars/)

**k8s_all.yml** - Common Kubernetes config:
```yaml
# Container runtime
container_runtime: containerd
containerd_version: 1.7.x

# Kubernetes versions
kubernetes_version: 1.28.x
kubeadm_version: 1.28.x
kubelet_version: 1.28.x
kubectl_version: 1.28.x

# Network
pod_network_cidr: 10.244.0.0/16
service_cidr: 10.96.0.0/12

# Certificate configuration
cert_duration: 87600h  # 10 years

# Proxy settings
http_proxy: "http://10.30.0.11:3128"
https_proxy: "http://10.30.0.11:3128"
no_proxy: "localhost,127.0.0.1,10.0.0.0/8,.local"
```

**k8s_dev.yml** - Dev-specific:
```yaml
cluster_name: dev
cluster_domain: dev.lithium.local
kubeadm_token_ttl: 2h  # Short lived for dev
allow_privileged: yes   # Relax security for testing
```

**k8s_prod.yml** - Prod-specific:
```yaml
cluster_name: prod
cluster_domain: prod.lithium.local
kubeadm_token_ttl: 24h
allow_privileged: no
audit_logging: yes
```

**proxy.yml** - Proxy configuration:
```yaml
proxy_port: 3128
proxy_cache_size: 5000  # MB
proxy_max_connections: 1000
upstream_dns:
  - 8.8.8.8
  - 1.1.1.1
```

### Host Variables (host_vars/)

For cluster-specific overrides or unique configurations.

## Playbook Descriptions

### 00-base-setup.yml
Runs on all VMs:
- System package updates
- SSH key distribution
- Hostname configuration
- Time synchronization (NTP)
- Logging setup
- Security hardening (basic)

### 01-proxy-setup.yml
Runs on `proxy` hosts:
- Install proxy software (Squid)
- Configure proxy service
- Setup logging and monitoring hooks
- Enable at boot

### 02-k8s-prerequisites.yml
Runs on `k8s_all` hosts:
- Install container runtime (containerd)
- Install kubeadm, kubelet, kubectl
- Configure cgroup driver
- Enable required kernel modules
- Setup kubelet configuration

### 03-k8s-bootstrap.yml
- Masters: `kubeadm init` with zone-specific CIDR
- Workers: Get join command from master, execute `kubeadm join`
- Validate nodes are ready

### 04-k8s-networking.yml
- Install CNI plugin (Flannel/Calico)
- Configure network policies for zone isolation
- Setup CoreDNS
- Validate DNS resolution

### 05-argocd-setup.yml
- Create argocd namespace
- Install ArgoCD Helm chart
- Create GitHub repository secret
- Create Application CRD for infrastructure sync
- Wait for ArgoCD server ready

### bootstrap-all.yml
Main orchestration:
```yaml
---
- name: Bootstrap Lithium Infrastructure
  hosts: localhost
  gather_facts: no
  tasks:
    - name: Run base setup
      include: playbooks/00-base-setup.yml

    - name: Setup proxy
      include: playbooks/01-proxy-setup.yml

    - name: Setup Kubernetes prerequisites
      include: playbooks/02-k8s-prerequisites.yml

    - name: Bootstrap Kubernetes clusters
      include: playbooks/03-k8s-bootstrap.yml

    - name: Setup Kubernetes networking
      include: playbooks/04-k8s-networking.yml

    - name: Setup ArgoCD
      include: playbooks/05-argocd-setup.yml
```

## Execution Flow

### Initial Setup (Manual)
```bash
cd /path/to/lithium-infra

# 1. Configure Terraform
export PM_API_URL="https://proxmox.example.com:8006/api2/json"
export PM_USER="terraform@pam"
export PM_PASSWORD="..."

# 2. Apply infrastructure
cd terraform
terraform init
terraform apply

# 3. Generate Ansible inventory
terraform output -raw inventory > ../ansible/inventory.ini

# 4. Verify connectivity
cd ../ansible
ansible all -i inventory.ini -m ping
```

### Bootstrap Playbook
```bash
# Option A: Run everything
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml

# Option B: Run step by step
ansible-playbook -i inventory.ini playbooks/00-base-setup.yml
ansible-playbook -i inventory.ini playbooks/01-proxy-setup.yml
ansible-playbook -i inventory.ini playbooks/02-k8s-prerequisites.yml
ansible-playbook -i inventory.ini playbooks/03-k8s-bootstrap.yml
ansible-playbook -i inventory.ini playbooks/04-k8s-networking.yml
ansible-playbook -i inventory.ini playbooks/05-argocd-setup.yml
```

## Configuration Management Strategy

### Pre-Configuration (Cloud-Init)
- SSH keys
- Hostname
- Network basic setup
- Initial package cache update

### Pre-Service Installation (Ansible - playbook 00)
- Full system update
- Required packages for Kubernetes
- Security hardening
- Logging

### Service Installation & Configuration
- Proxy (playbook 01)
- Kubernetes (playbooks 02-04)
- ArgoCD (playbook 05)

### Post-Installation Maintenance
- GitOps: All changes via Helm/ArgoCD
- Configuration: ConfigMaps and Secrets managed by ArgoCD
- Updates: GitOps workflow for infrastructure upgrades

## Error Handling & Validation

Each playbook includes:
```yaml
- name: Validate task completion
  assert:
    that:
      - service_running | bool
      - node_ready | bool
    fail_msg: "Service not ready"
    success_msg: "Service validated"
```

## Idempotency

All playbooks designed to be:
- **Idempotent**: Safe to run multiple times
- **Re-runnable**: Can fix issues by re-running
- **Zone-specific**: Can target single zone for updates

Example:
```bash
# Update only dev cluster
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml \
  --limit k8s_dev

# Re-run ArgoCD setup for prod
ansible-playbook -i inventory.ini playbooks/05-argocd-setup.yml \
  --limit kube-prod-master-001
```

## Future Enhancements

1. **Ansible Vault**: Encrypt sensitive variables
2. **Dynamic Inventory**: Script to query Proxmox API directly
3. **Health Checks**: Monitoring integration after setup
4. **Backup Hooks**: Snapshot creation integration
5. **Upgrade Playbooks**: Kubernetes cluster upgrades

