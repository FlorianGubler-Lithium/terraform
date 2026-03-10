# Quick Start Guide

## For Impatient Users (TL;DR)

Complete infrastructure setup from zero: **~2 hours with all prerequisites installed**

### Prerequisites (one-time setup)
```bash
# Install tools
brew install terraform ansible kubectl helm git jq

# Clone repo
git clone https://github.com/your-org/lithium-infra.git
cd lithium-infra

# Setup credentials
export TF_VAR_pm_password="your-proxmox-password"
export TF_VAR_vm_password="your-vm-password"
```

### Deploy Everything
```bash
# 1. Infrastructure (15-20 min)
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output -raw inventory > ../ansible/inventory.ini

# 2. Configuration (30-45 min)
cd ../ansible
sleep 120  # Wait for VMs to boot
ansible all -i inventory.ini -m ping
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml -v

# 3. Verify (5 min)
ssh ubuntu@10.10.0.10 "kubectl get nodes"
# Expected: 3 nodes, all Ready
```

### Access Your Cluster

```bash
# Copy kubeconfig from master
scp -i ~/.ssh/id_lithium ubuntu@10.10.0.10:~/.kube/config ~/.kube/config.lithium-dev

# Use it
export KUBECONFIG=~/.kube/config.lithium-dev
kubectl get nodes

# Access ArgoCD
kubectl -n argocd port-forward svc/argocd-server 8443:443
# Browser: https://localhost:8443
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Step-by-Step Quick Start (10 minutes)

### Step 1: Prepare Management Host

```bash
# Verify tools installed
terraform -version          # >= 1.5
ansible --version          # >= 2.12
kubectl version --client   # >= 1.28
helm version              # >= 3.12

# Clone and navigate
git clone https://github.com/your-org/lithium-infra.git
cd lithium-infra
```

### Step 2: Configure Proxmox Access

Create `terraform/terraform.tfvars`:
```hcl
pm_api_url        = "https://proxmox.local:8006/api2/json"
pm_user           = "terraform@pam"
pm_password       = "password"
pm_node           = "pve-1"
firewall_template = "9001"
debian_template   = "9000"
vm_password       = "initial-password"
```

### Step 3: Deploy Infrastructure

```bash
cd terraform
terraform init && terraform plan -out=tfplan && terraform apply tfplan
terraform output -raw inventory > ../ansible/inventory.ini
cd ..
```

**What this does:**
- Creates 10 VMs (1 firewall, 3 dev, 3 prod, 2 infra)
- Configures VLAN isolation (zones 100, 200, 300)
- Generates Ansible inventory

### Step 4: Bootstrap Configuration

```bash
cd ansible

# Wait for VMs
sleep 120

# Verify connectivity
ansible all -i inventory.ini -m ping

# Run bootstrap
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml
```

**What this does:**
- Updates all systems
- Installs Kubernetes on all nodes
- Initializes dev & prod clusters
- Installs ArgoCD and links to Git repo
- Configures HTTP proxy for outbound traffic

### Step 5: Verify Deployment

```bash
# SSH to dev master
ssh ubuntu@10.10.0.10

# Check nodes
kubectl get nodes          # Should show 3 nodes, all Ready
kubectl get pods -A        # System pods should be Running

# Check ArgoCD
kubectl -n argocd get pods # Should show controller, server, dex
```

### Step 6: Access ArgoCD

```bash
# Create port forward
kubectl -n argocd port-forward svc/argocd-server 8443:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Open browser: https://localhost:8443
# Login with username "admin" and password from above
```

---

## Common Commands

### Cluster Operations

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check specific cluster (from master)
ssh ubuntu@10.10.0.10 kubectl get nodes
ssh ubuntu@10.20.0.10 kubectl get nodes

# Scale deployment
kubectl scale deployment -n argocd argocd-server --replicas=3

# Update via ArgoCD
kubectl -n argocd patch application infrastructure --type merge \
  -p '{"status": {"operationState": {"phase": "Running"}}}'
```

### Network Validation

```bash
# Test zone isolation
ping 10.10.0.10  # Dev
ping 10.20.0.10  # Prod
ping 10.30.0.10  # Infra

# Test proxy
curl -x http://10.30.0.11:3128 https://api.github.com

# Check DNS
nslookup kubernetes.default.svc.cluster.local 10.10.0.1
nslookup github.com
```

### Infrastructure Management

```bash
# View Terraform state
terraform -chdir=terraform show

# List all VMs
ssh root@proxmox "qm list"

# Shutdown VM (graceful)
ssh root@proxmox "qm shutdown 101 --timeout=300"

# Restart VM
ssh root@proxmox "qm start 101"

# Export VM config
ssh root@proxmox "qm config 101"
```

### Troubleshooting

```bash
# Check Ansible inventory
ansible all -i ansible/inventory.ini --list-hosts

# Run playbook with verbose output
ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap-all.yml -v

# SSH to specific VM
ssh -i ~/.ssh/id_lithium ubuntu@10.10.0.10

# Check VM system logs
ssh ubuntu@10.10.0.10 "sudo journalctl -n 50"

# Monitor proxy traffic
ssh ubuntu@10.30.0.11 "sudo tail -f /var/log/squid/access.log"
```

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│           Proxmox Host                               │
├──────────────────────────────────────────────────────┤
│  Dev Zone (10.10.0.0/24, VLAN 100)                  │
│    ├─ kube-dev-master-001 (10.10.0.10)              │
│    ├─ kube-dev-worker-001 (10.10.0.11)              │
│    └─ kube-dev-worker-002 (10.10.0.12)              │
│                                                      │
│  Prod Zone (10.20.0.0/24, VLAN 200)                 │
│    ├─ kube-prod-master-001 (10.20.0.10)             │
│    ├─ kube-prod-worker-001 (10.20.0.11)             │
│    └─ kube-prod-worker-002 (10.20.0.12)             │
│                                                      │
│  Infra Zone (10.30.0.0/24, VLAN 300)                │
│    ├─ mgmt-console-001 (10.30.0.10)                 │
│    └─ http-proxy-001 (10.30.0.11)                   │
│                                                      │
│  Firewall VM (manages VLAN routing)                  │
└──────────────────────────────────────────────────────┘
```

---

## What's Deployed

### Kubernetes Clusters
- **Dev Cluster** (10.10.0.0/24): 1 master + 2 workers
- **Prod Cluster** (10.20.0.0/24): 1 master + 2 workers
- Both running Kubernetes 1.28.x with Flannel CNI

### Infrastructure Services
- **HTTP Proxy** (Squid): Centralized egress control
- **ArgoCD**: GitOps automation for declarative deployment
- **Sealed-Secrets**: Encrypted secret management
- **Cert-Manager**: Automatic HTTPS certificate management
- **Traefik**: Ingress controller for external traffic
- **Prometheus/Grafana**: Monitoring (optional)
- **Metallic Load Balancer**: For bare-metal deployments (if configured)

### Network
- VLAN isolation between zones
- Firewall VM enforces traffic policies
- Proxy VM provides centralized egress
- All infrastructure as code via Terraform

---

## Next Steps

1. **Review Architecture**: Read `docs/architecture.md` for system design
2. **Deploy Applications**: Create app definitions in `cicd/` and sync with ArgoCD
3. **Setup Monitoring**: Configure Prometheus scrape targets
4. **Enable Backups**: Configure VM snapshots and etcd backups
5. **Document Operations**: Create runbooks for your team

---

## Need Help?

- **Deployment Issues**: See `docs/deployment-guide.md` troubleshooting section
- **Network Problems**: Check `docs/network-design.md` for topology details
- **Ansible Playbooks**: Refer to `docs/ansible-strategy.md` for execution flow
- **ArgoCD Operations**: See `docs/argocd-integration.md` for GitOps workflows
- **General Questions**: Check `docs/` folder for complete documentation

---

## Environment Info

- **Proxmox Version**: 7.x or 8.x
- **Kubernetes Version**: 1.28.x (configurable)
- **Container Runtime**: containerd
- **OS**: Debian 12 or Ubuntu 22.04 LTS
- **Infrastructure as Code**: Terraform 1.5+
- **Configuration Management**: Ansible 2.12+
- **Deployment Automation**: ArgoCD 2.8+

