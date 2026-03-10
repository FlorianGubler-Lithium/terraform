# Deployment Guide - Complete Infrastructure Bootstrapping

- ArgoCD: https://argo-cd.readthedocs.io/
- Kubernetes: https://kubernetes.io/docs/
- Ansible: https://docs.ansible.com/
- Terraform: https://www.terraform.io/docs
- Proxmox: https://pve.proxmox.com/wiki/
Or check individual tool documentation:

- `docs/argocd-integration.md`: GitOps workflow
- `docs/ansible-strategy.md`: Playbook structure and roles
- `docs/network-design.md`: Network topology and routing
- `docs/architecture.md`: System design and components
For detailed troubleshooting, refer to:

## Support & Debugging

5. **Documentation**: Create runbooks for operations and disaster recovery
4. **Security Hardening**: Implement network policies, RBAC, pod security
3. **Enable Backups**: Configure VM snapshot schedules and etcd backups
2. **Configure Monitoring**: Setup Prometheus/Grafana for cluster monitoring
1. **Deploy Application Workloads**: Add application definitions to cicd/ folder

## Next Steps

- [ ] Monitoring configured and alerting tested
- [ ] Team access credentials distributed securely
- [ ] Initial state documented and backed up
- [ ] Network isolation validated (zone separation)
- [ ] HTTP proxy forwarding traffic correctly
- [ ] DNS resolution working internally and externally
- [ ] Git repository synced to ArgoCD
- [ ] ArgoCD server accessible and authenticated
- [ ] Kubernetes nodes showing as `Ready`
- [ ] All Ansible playbooks executed successfully
- [ ] SSH access working from management host
- [ ] All VMs running and responding to ping

## Post-Deployment Checklist

```
ssh ubuntu@10.30.0.11 "sudo systemctl restart squid"
# Restart proxy service

curl -x http://10.30.0.11:3128 https://api.github.com
ssh ubuntu@10.30.0.11 "sudo tail -f /var/log/squid/access.log" &
# Monitor proxy traffic

ssh ubuntu@10.30.0.11 "cat /etc/squid/squid.conf | grep acl"
# Check proxy ACLs

curl -x http://10.30.0.11:3128 -v https://www.google.com
# Test proxy directly
```bash
**Solutions:**

**Symptoms:** Connection timeout, 403 errors, or incomplete proxying

### Issue: Proxy not accessible or not forwarding traffic

```
ssh ubuntu@10.10.0.11 "sudo kubeadm join 10.10.0.10:6443 --token=... --discovery-token-ca-cert-hash=sha256:..."
# Manually join (if needed)

ssh ubuntu@10.10.0.10 "kubeadm token create --print-join-command"
# Verify join command

ssh ubuntu@10.10.0.11 "sudo journalctl -u kubelet -n 50"
# Check kubelet logs

ssh ubuntu@10.10.0.11 "sudo systemctl status kubelet"
# Check kubelet status on worker
```bash
**Solutions:**

**Symptoms:** Workers show `NotReady` status, join command fails

### Issue: Kubernetes nodes not joining cluster

```
ansible all -i inventory.ini -m shell -a "ip route"
# Verify network connectivity

ssh -v -i ~/.ssh/id_lithium ubuntu@10.10.0.10
# SSH directly to test

ansible all -i inventory.ini -m shell -a "sudo ufw status"
# Check firewall rules on VMs

sleep 180 && ansible all -i inventory.ini -m ping
# Ensure VMs are fully booted
```bash
**Solutions:**

**Symptoms:** `SSH connection refused` or `No route to host`

### Issue: Ansible connectivity fails

```
sudo cat /var/log/cloud-init-output.log
# Check cloud-init logs (inside VM)

qm status 101
# Check VM status

qm start 101
# Manually start VM

ssh root@proxmox "tail -100 /var/log/syslog | grep qemu"
# Check Proxmox logs
```bash
**Solutions:**

**Symptoms:** VMs created but not starting, or stuck in creation

### Issue: VMs not booting after Terraform apply

## Troubleshooting Common Issues

- `docs/scaling-guide.md`: Adding more Kubernetes clusters
- `docs/disaster-recovery.md`: Recovery procedures
- `docs/troubleshooting.md`: Common issues and solutions
- `docs/quick-start.md`: Getting started guide for team members
Create or update these documents:

### Step 5.3: Team Documentation

```
git push
git commit -m "Add deployment documentation and initial state snapshots"
git add docs/
cd ..
# Git commit documentation

kubectl get nodes -o yaml > ../docs/k8s-nodes-initial.yaml
kubectl -n argocd get secret > ../docs/k8s-secrets-initial.yaml
# Export Kubernetes configurations

terraform show > ../docs/terraform-state-initial.json
cd terraform
# Export current Terraform state
```bash

### Step 5.2: Backup Initial State

- Escalation procedures
- Common troubleshooting steps
- Kubernetes cluster health checks
- VM restart procedures
- Emergency shutdown procedures
Create a file `docs/operations-runbook.md` with:

### Step 5.1: Create Operations Runbook

## Phase 5: Final Checks & Documentation

```
nslookup argocd-server.argocd.svc.cluster.local
# Test service discovery

# Expected: Should resolve to GitHub's IP
nslookup github.com
# Test external DNS (via proxy)

# Expected: Should resolve to 10.96.0.1 (dev) or 10.97.0.1 (prod)
nslookup kubernetes.default.svc.cluster.local
# Test internal DNS (Kubernetes DNS)

ssh ubuntu@10.10.0.10
# SSH to a VM
```bash

### Step 4.5: DNS Resolution Validation

```
# Expected: HTTP 200 (or successful connection)
ssh ubuntu@10.10.0.10 "curl -x http://10.30.0.11:3128 https://www.google.com"
# Test proxy from another VM

sudo tail -100 /var/log/squid/access.log
# Check proxy logs

# Expected: active (running)
sudo systemctl status squid
# Verify proxy service is running

ssh ubuntu@10.30.0.11
# SSH to proxy VM
```bash

### Step 4.4: Firewall & Proxy Validation

```
kubectl -n argocd describe application infrastructure
# View sync details

# Expected output: Synced (or OutOfSync if Git has changes)
kubectl -n argocd get application infrastructure -o jsonpath='{.status.sync.status}'
# Check infrastructure application sync status

kubectl -n argocd get applications
# Verify ArgoCD can sync from Git
```bash

### Step 4.3: ArgoCD Sync Validation

```
kubectl delete deployment test-nginx
# Cleanup

kubectl get pods -o wide
# Verify pods are running on different nodes

kubectl wait deployment/test-nginx --for condition=available --timeout=300s
# Wait for deployment

EOF
        - containerPort: 80
        ports:
        image: nginx:latest
      - name: nginx
      containers:
    spec:
        app: nginx
      labels:
    metadata:
  template:
      app: nginx
    matchLabels:
  selector:
  replicas: 2
spec:
  name: test-nginx
metadata:
kind: Deployment
apiVersion: apps/v1
kubectl apply -f - << 'EOF'
# Deploy test application
```bash

### Step 4.2: Kubernetes Validation

```
# Expected: HTTP 200 or connection success
ssh ubuntu@10.10.0.10 "curl -x http://10.30.0.11:3128 https://api.github.com"
# Test proxy access

# Expected: No response or timeout (blocked by firewall/VLAN)
ssh ubuntu@10.10.0.10 "ping -c 1 10.20.0.10"
# From dev master, try to ping prod master (should fail without firewall)
# Test zone isolation

ssh ubuntu@10.10.0.10 "ip addr show; ip route"
# SSH to each VM and verify network
```bash

### Step 4.1: Network Connectivity Validation

## Phase 4: Validation & Post-Deployment

```
# Password: (from above command)
# Username: admin
# https://localhost:8443
# Access via browser

kubectl -n argocd port-forward svc/argocd-server 8443:443 &
# Forward port to access ArgoCD UI

  -o jsonpath="{.data.password}" | base64 -d; echo
kubectl -n argocd get secret argocd-initial-admin-secret \
# Get ArgoCD admin password

# ... (more pods)
# argocd-server-xxxx                      1/1     Running   0          2m
# argocd-dex-server-xxxx                  1/1     Running   0          2m
# argocd-application-controller-0         1/1     Running   0          2m
# NAME                                    READY   STATUS    RESTARTS   AGE
# Expected output:

kubectl -n argocd get pods
# Check ArgoCD pods
```bash

### Step 3.5: Verify ArgoCD Installation

```
kubectl cluster-info
# Check cluster info

# Expected: All system pods in Running state
kubectl get pods -A

# kube-dev-worker-002    Ready    <none>          1m    v1.28.0
# kube-dev-worker-001    Ready    <none>          1m    v1.28.0
# kube-dev-master-001    Ready    control-plane   2m    v1.28.0
# NAME                   STATUS   ROLES           AGE   VERSION
# Expected output:
kubectl get nodes
# Inside master VM

ssh ubuntu@10.10.0.10
# Check dev cluster
```bash

### Step 3.4: Verify Kubernetes Clusters

- 05-argocd-setup: 3-5 minutes
- 04-k8s-networking: 5 minutes (CNI deployment)
- 03-k8s-bootstrap: 5-10 minutes (init + join + validation)
- 02-k8s-prerequisites: 10-15 minutes (includes package downloads via proxy)
- 01-proxy-setup: 2-3 minutes
- 00-base-setup: 5-10 minutes
**Expected playbook execution times:**

```
ansible-playbook -i inventory.ini playbooks/05-argocd-setup.yml -v
# Step 6: Install ArgoCD

ansible-playbook -i inventory.ini playbooks/04-k8s-networking.yml -v
# Step 5: Configure Kubernetes networking

ansible-playbook -i inventory.ini playbooks/03-k8s-bootstrap.yml -v
# Step 4: Bootstrap Kubernetes clusters

ansible-playbook -i inventory.ini playbooks/02-k8s-prerequisites.yml -v
# Step 3: Install Kubernetes prerequisites

ansible-playbook -i inventory.ini playbooks/01-proxy-setup.yml -v
# Step 2: Setup HTTP proxy

ansible-playbook -i inventory.ini playbooks/00-base-setup.yml -v
# Step 1: Base system setup

# Option B: Run playbooks step-by-step (for debugging)

ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml -v
# Option A: Run all playbooks in sequence (recommended for first deployment)
```bash

### Step 3.3: Run Bootstrap Playbooks

```
EOF
no_proxy: "localhost,127.0.0.1,10.0.0.0/8,.local"
https_proxy: "http://10.30.0.11:3128"
http_proxy: "http://10.30.0.11:3128"
# Proxy (if needed)

service_cidr: 10.96.0.0/12
pod_network_cidr: 10.244.0.0/16
# Network

kubectl_version: 1.28.0
kubelet_version: 1.28.0
kubeadm_version: 1.28.0
kubernetes_version: 1.28.0
container_runtime: containerd
# Kubernetes Configuration
cat > group_vars/k8s_all.yml << 'EOF'
# Create k8s-wide variables

mkdir -p group_vars host_vars
# Create group vars directory if not present
```bash

Create and update group variable files:

### Step 3.2: Configure Group Variables

```
ssh -i ~/.ssh/id_lithium ubuntu@10.10.0.10
# SSH directly to debug

ansible kube-dev-master-001 -i inventory.ini -m ping -v
# Test individual VM

sleep 60 && ansible all -i inventory.ini -m ping
# Wait a bit longer and retry
# If some VMs don't respond yet, they may still be booting
```bash
**Troubleshooting SSH issues:**

```
# ... (for all VMs)
# }
#     "ping": "pong"
#     "changed": false,
# kube-dev-master-001 | SUCCESS => {
# Expected output:

ansible all -i inventory.ini -m ping
# Test connectivity to all VMs

sleep 120
# Wait for VMs to be fully booted and SSH ready (this may take 2-3 minutes)

cd ../ansible
```bash

### Step 3.1: Verify Connectivity

## Phase 3: Ansible Configuration & Orchestration

```
# ... (more VMs)
# vmid 102: running (dev worker-1)
# vmid 101: running (dev master)
# vmid 100: running (firewall VM)
# Expected output:

ssh root@proxmox.your-domain.com "qm status 100-112"
# On Proxmox host, verify VMs are running
```bash

### Step 2.5: Verify VM Creation

```
# ... (more groups)
# kube-dev-worker-001 ansible_host=10.10.0.11
# [k8s_dev_workers]
# kube-dev-master-001 ansible_host=10.10.0.10
# [k8s_dev_masters]
# Expected structure:

cat ../ansible/inventory.ini
# Verify inventory was generated

terraform output -raw inventory > ../ansible/inventory.ini
# Export Terraform outputs for Ansible
```bash

### Step 2.4: Generate Ansible Inventory

```
# inventory = "..."
# infra_zone_ips = {...}
# prod_zone_ips = {...}
# dev_zone_ips = {...}
# Outputs:
# Output summary:

# Apply complete! Resources added: 10
# ...
# proxmox_vm_qemu.firewall: Still creating... [10s elapsed]
# proxmox_vm_qemu.firewall: Creating...
# Progress output:
# This will take 15-20 minutes (VMs are cloning from template)

terraform apply tfplan
# Apply the plan (creates VMs on Proxmox)
```bash

### Step 2.3: Apply Infrastructure

- Check memory/CPU allocation aligns with your hardware
- Confirm VLAN tags are correct (100, 200, 300)
- Verify VM counts match your requirements (1 firewall, 3 dev VMs, 3 prod VMs, 2 infra VMs)
**Review the plan carefully:**

```
# ... (more resources)
# + proxmox_vm_qemu.dev_vms[kube-dev-worker-001]
# + proxmox_vm_qemu.dev_vms[kube-dev-master-001]
# + proxmox_vm_qemu.firewall
# Changes to be applied:
#
# Plan: 10 to add, 0 to change, 0 to destroy.
# Expected output:

terraform plan -out=tfplan
# Generate and review deployment plan
```bash

### Step 2.2: Plan Infrastructure

```
#   - telmate/proxmox: version >= 2.9
#   - hashicorp/null: version ~> 3.2
# Providers required:
# Terraform has been successfully configured!
# Output should show:

terraform init
# Initialize Terraform (downloads providers)

cd terraform
```bash

### Step 2.1: Initialize Terraform

## Phase 2: Terraform Infrastructure Provisioning

```
ls -la ~/.ssh/id_lithium*
# For now, verify key is ready
# Test SSH to management host (will be created by Terraform)

ssh-keygen -t ed25519 -C "lithium-ansible" -f ~/.ssh/id_lithium -N ""
# Generate SSH key for ansible (if not present)
```bash

### Step 1.5: Prepare SSH Access

```
# 9001      firewall-template    stopped    4096       2     4096
# 9000      debian-template      stopped    2048       2     2048
# VMID      NAME                 STATUS     MEM(MB)    CPUS  MAXMEM
# Output should show templates

ssh root@proxmox.your-domain.com "qm list"
# SSH to Proxmox host
```bash

### Step 1.4: Verify Template IDs

```
# Expected output: "Success! The configuration is valid."

terraform -chdir=terraform validate
terraform -chdir=terraform init
# Or use Terraform to validate

  -H "Authorization: PVEAPIToken=terraform@pam!lithium-token=xxxxx" | jq .
  "https://proxmox.your-domain.com:8006/api2/json/nodes" \
curl -k -X GET \
# Test Proxmox API access
```bash

### Step 1.3: Verify Proxmox Connectivity

```
# https://www.terraform.io/cloud/docs/vcs
# Or use Terraform Cloud/Enterprise for credential management

export TF_VAR_vm_password="your-vm-password"
export TF_VAR_pm_password="your-password"
# Use environment variables instead of storing in file
```bash
**Security Best Practices:**

```
vm_password       = "your-vm-password"  # Initial password (change after bootstrap)
debian_template   = "9000"              # Template ID (verify: qm list | grep debian)
firewall_template = "9001"              # Template ID (verify: qm list | grep firewall)

pm_node     = "pve-1"                  # Your Proxmox node name
pm_password = "your-secure-password"  # Or use environment variable: TF_VAR_pm_password
pm_user     = "terraform@pam"
pm_api_url  = "https://proxmox.your-domain.com:8006/api2/json"
# terraform/terraform.tfvars
```hcl

Create `terraform/terraform.tfvars` with your environment-specific settings:

### Step 1.2: Configure Terraform Variables

```
# Expected: ansible/ cicd/ docs/ terraform/ .git
ls -la
# Verify directory structure

cd lithium-infra
git clone https://github.com/your-org/lithium-infra.git
# Clone the infrastructure repository
```bash

### Step 1.1: Clone Repository

## Phase 1: Bootstrap Preparation

  - Store in secure location or Terraform variables
  - Scope: `repo` (full control)
- Personal Access Token (PAT) for ArgoCD:
- Repository: `https://github.com/your-org/lithium-infra.git`
- GitHub account with SSH key configured

### GitHub Repository Access

```
qm template 9000
qm shutdown 9000
# 4. Sysprep and convert to template

sudo apt update && sudo apt install -y cloud-init qemu-guest-agent
# (from within VM)
# 3. Install cloud-init and guest agent

# ... complete Debian installation via VNC ...
qm start 9000
# 2. Start VM and install Debian 12

  --scsi0 local-lvm:20 --net0 virtio,bridge=vmbr0 --name debian-template
qm create 9000 --memory 2048 --cores 2 --scsihw virtio-scsi-pci \
# 1. Create VM from ISO
# On Proxmox host
```bash
**Template Creation Example:**

  - Minimal disk footprint (~5GB)
  - OpenSSH server configured
  - QEMU Guest Agent installed
  - Cloud-init enabled
- **debian_template**: Standard Debian 12 clone source

  - Example: Create from ISO with `/usr/local/bin/setup-firewall.sh` script
  - Network bridge configuration scripts included
  - UFW/iptables configured
  - Debian 12 or Ubuntu 22.04 Server
- **firewall_template**: Pre-configured router image
**VM Templates:**

```
# If not present, apply network configuration from network-design.md

cat /proc/net/vlan/config
# Verify VLAN support

ip link show vmbr0  # Should show VLAN-aware bridge
# Verify bridge configuration

ssh root@proxmox.example.com
# SSH into Proxmox host
```bash
**Required Configuration:**

- VLAN trunking: Enabled on physical interface
- MTU: 1500 bytes minimum
- Proxmox host must have vmbr0 bridge with VLAN support enabled
**Network Configuration:**

### Proxmox Host Prerequisites

```
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
# Install ArgoCD CLI

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# Install Helm

sudo apt install -y terraform ansible kubectl git jq curl gpg
sudo apt update
```bash
**Installation (Ubuntu/Debian):**

```
brew install --cask argocd-cli
brew install terraform ansible kubectl helm git jq
```bash
**Installation (macOS with Homebrew):**

- jq (JSON processor)
- SSH client
- Git CLI
- Helm >= 3.12
- kubectl >= 1.28
- Ansible >= 2.12
- Terraform >= 1.5.0
**Software Requirements:**

The management host is your laptop/workstation that will coordinate the entire setup.

### Management Host Requirements

## Prerequisites

**Total deployment time: 90-150 minutes**

4. **Validation & post-deployment checks** (15 minutes)
3. **Ansible configuration & orchestration** (30-45 minutes)
2. **Terraform infrastructure provisioning** (15-20 minutes)
1. **Prerequisites validation** (30 minutes)

This guide provides step-by-step instructions for bootstrapping the entire Lithium infrastructure from a management host. The process consists of:

## Overview

