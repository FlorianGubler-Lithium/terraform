# Operations Runbook

## Daily Operations

### Morning Health Check

```bash
# 1. Verify all VMs running
ssh root@proxmox.local "qm list" | grep -E "running|stopped"

# 2. Check cluster health
ssh ubuntu@10.10.0.10 "kubectl get nodes && kubectl get pods -A --field-selector=status.phase!=Running"

# 3. Monitor proxy traffic
ssh ubuntu@10.30.0.11 "tail -50 /var/log/squid/access.log"

# 4. Check ArgoCD sync status
ssh ubuntu@10.10.0.10 "kubectl -n argocd get applications"

# All should be:
# ✅ VMs: running
# ✅ Nodes: Ready
# ✅ Pods: Running (or expected state)
# ✅ ArgoCD: Synced
```

### Daily Backup

```bash
# Backup Kubernetes etcd (on each master)
ssh ubuntu@10.10.0.10 << 'EOF'
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd-$(date +%Y%m%d-%H%M%S).db
EOF

# Backup Git repository (if using local Git)
cd lithium-infra && git pull && git status
```

---

## Common Operational Tasks

### Deploying New Application

```bash
# 1. Create Helm chart in cicd/
mkdir -p cicd/my-app/{templates,charts}
cat > cicd/my-app/Chart.yaml << 'EOF'
apiVersion: v2
name: my-app
version: 1.0.0
EOF

# 2. Create application definition
cat > cicd/applications/dev/my-app.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/lithium-infra.git
    path: cicd/my-app
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# 3. Commit and push
git add cicd/
git commit -m "Add my-app deployment"
git push

# 4. Sync ArgoCD (automatic or manual)
kubectl -n argocd patch application my-app --type merge \
  -p '{"status": {"sync": {"status": ""}}}'
```

### Scaling Kubernetes Deployment

```bash
# Scale deployment to 3 replicas
kubectl scale deployment my-app --replicas=3

# Or edit deployment
kubectl edit deployment my-app
# Change spec.replicas to desired count

# Verify scaling
kubectl rollout status deployment/my-app
kubectl get pods -l app=my-app
```

### Updating Kubernetes Version

```bash
# 1. Backup cluster state
kubectl get all -A -o yaml > cluster-backup-v1.28.yaml

# 2. Update on master
ssh ubuntu@10.10.0.10 << 'EOF'
sudo apt update
sudo apt install -y kubelet=1.29.0-00 kubeadm=1.29.0-00 kubectl=1.29.0-00
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.29.0
sudo systemctl restart kubelet
EOF

# 3. Drain and update each worker
for worker in kube-dev-worker-001 kube-dev-worker-002; do
  ssh ubuntu@10.10.0.11  # SSH to master first
  kubectl drain $(hostname) --ignore-daemonsets --delete-local-data
  
  ssh ubuntu@$worker << 'EOF'
sudo apt update
sudo apt install -y kubelet=1.29.0-00 kubeadm=1.29.0-00 kubectl=1.29.0-00
sudo systemctl restart kubelet
EOF

  kubectl uncordon $worker
done

# 4. Verify upgrade
kubectl get nodes
```

### Adding New VLAN/Zone

```bash
# 1. Update Terraform
vim terraform/main.tf
# Add new zone to locals.zones
# Add new VM definitions

terraform plan -out=tfplan
terraform apply tfplan

# 2. Update Ansible inventory
terraform output -raw inventory > ansible/inventory.ini

# 3. Configure new VMs
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/00-base-setup.yml \
  --limit "new_zone_hosts"

# 4. Bootstrap if Kubernetes
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/02-k8s-prerequisites.yml \
  --limit "k8s_new_cluster"
```

### Emergency Shutdown

```bash
# Graceful shutdown of all VMs
for vmid in 100 101 102 103 104 105 106 107 108 109 110 111 112; do
  ssh root@proxmox "qm shutdown $vmid --timeout=300"
done

# Force shutdown if graceful times out
for vmid in 100 101 102 103 104 105 106 107 108 109 110 111 112; do
  ssh root@proxmox "qm stop $vmid"
done

# Verify all stopped
ssh root@proxmox "qm list | grep stopped"
```

### Cold Start Recovery

```bash
# Start Proxmox host and wait for services
# Wait 2 minutes for Proxmox to fully boot

# Start VMs in dependency order:
# 1. Firewall (provides VLAN routing)
ssh root@proxmox "qm start 100 && sleep 30"

# 2. Infra zone (proxy, management)
ssh root@proxmox "qm start 110 && qm start 111 && sleep 60"

# 3. Kubernetes zones (dev, then prod)
ssh root@proxmox "qm start 101 && qm start 102 && qm start 103 && sleep 60"
ssh root@proxmox "qm start 104 && qm start 105 && qm start 106 && sleep 60"

# 4. Verify health
ansible all -i ansible/inventory.ini -m ping
kubectl get nodes  # (from any master)
```

---

## Troubleshooting Flows

### "I can't SSH to a VM"

```bash
# 1. Check if VM is running
ssh root@proxmox "qm status 101"
# If stopped: qm start 101

# 2. Check if it's booted yet
sleep 60 && ssh ubuntu@10.10.0.10
# Give it more time if needed

# 3. Test with root access (if password known)
# Via Proxmox console
ssh root@proxmox "qm enter 101"

# 4. Check Proxmox logs
ssh root@proxmox "tail -100 /var/log/syslog | grep 'qemu.*101'"

# See troubleshooting.md for more solutions
```

### "Kubernetes cluster not healthy"

```bash
# 1. Check nodes
kubectl get nodes
# All should be Ready

# 2. Check pod status
kubectl get pods -A --field-selector=status.phase!=Running
# Should return nothing or only expected pods

# 3. Check system pods specifically
kubectl get pods -n kube-system
# All should be Running

# 4. Check logs of failing pod
kubectl logs -n kube-system <pod-name>

# See troubleshooting.md Kubernetes section for deep dive
```

### "Network between zones is broken"

```bash
# 1. Test zone isolation (expected: no connection)
ssh ubuntu@10.10.0.10 "timeout 5 ping 10.20.0.10" || echo "Correct: blocked"
# Should timeout (expected behavior - zones are isolated)

# 2. Test proxy access (expected: works)
ssh ubuntu@10.10.0.10 "curl -x http://10.30.0.11:3128 https://api.github.com"
# Should succeed

# 3. Check firewall VM is running
ssh root@proxmox "qm status 100"

# 4. Check firewall rules
ssh ubuntu@10.30.0.1 "sudo iptables -L FORWARD -v"

# See troubleshooting.md Network section for deep dive
```

### "ArgoCD not syncing"

```bash
# 1. Check application status
kubectl -n argocd get applications

# 2. Check recent sync attempt
kubectl -n argocd describe application infrastructure | tail -20

# 3. Check controller logs
kubectl logs -n argocd deployment/argocd-application-controller -f

# 4. Verify Git access
ssh ubuntu@10.30.0.10 "git clone https://github.com/your-org/lithium-infra.git"

# See troubleshooting.md ArgoCD section for deep dive
```

---

## Maintenance Windows

### Weekly Tasks

- [ ] Review cluster logs: `kubectl logs -n kube-system --all-containers=true`
- [ ] Check disk usage: `df -h` on all nodes
- [ ] Verify backup completion: `ls -la /backup/`
- [ ] Review proxy logs: `tail -1000 /var/log/squid/access.log`
- [ ] Check certificate expiry: `kubectl get certificate -A`
- [ ] Review node resource usage: `kubectl top nodes`

### Monthly Tasks

- [ ] Update system packages: `ansible all -i inventory.ini -m apt -a "update_cache=yes upgrade=yes"`
- [ ] Clean up old images: `kubectl image prune -a --force`
- [ ] Rotate credentials/tokens (if used)
- [ ] Test disaster recovery procedure
- [ ] Review and update runbooks

### Quarterly Tasks

- [ ] Update Kubernetes version (if new minor release available)
- [ ] Review and optimize resource allocation
- [ ] Plan capacity expansion if needed
- [ ] Security audit of configurations
- [ ] Update base VM templates

---

## Monitoring & Alerting

### Key Metrics to Monitor

```
# Cluster Health
- Node status (all Ready)
- Pod restart count (should be low)
- API latency (<200ms)
- etcd commit duration (<25ms)

# Network Health
- Proxy request count (trends)
- Proxy cache hit ratio (>50%)
- Inter-node latency (<10ms)
- Packet loss (0%)

# Storage Health
- Node disk usage (<80%)
- Etcd database size (stable)
- PVC usage (if used)

# Security
- Failed authentication attempts
- Unusual pod creation
- Network policy violations
- Certificate expiry warnings
```

### Setting Up Basic Monitoring (Optional)

```bash
# Deploy Prometheus
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator.yaml

# Deploy Grafana
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/values.yaml

# Or use existing cicd/prometheus and cicd/grafana Helm charts
kubectl apply -f cicd/prometheus/
kubectl apply -f cicd/grafana/
```

---

## Escalation Procedures

### Critical Issues (Cluster Down)

**Immediate Actions:**
1. Assess impact: Which services/users affected?
2. Preserve evidence: Collect logs and state information
3. Attempt quick recovery: Restart affected components
4. Activate DR: If recovery fails, begin restoration

**Communication:**
- Notify team immediately
- Post status updates every 15 minutes
- Prepare incident report

**Post-Incident:**
- Conduct blameless post-mortem
- Update runbooks based on findings
- Implement preventive measures

### Major Issues (Partial Outage)

**Response:**
1. Identify affected services
2. Attempt mitigation (restart pod, drain node, etc.)
3. Scale up if needed to maintain capacity
4. Monitor for propagation to other systems

**Documentation:**
- Log incident details
- Track resolution steps
- Update runbooks

### Minor Issues (Degradation)

**Response:**
1. Gather information about the issue
2. Attempt low-risk fixes
3. Monitor impact
4. Schedule follow-up if not resolved

---

## Disaster Recovery

### Recovery from VM Failure

```bash
# 1. Identify failed VM
ssh root@proxmox "qm status 101"  # Status: stopped

# 2. Try to restart
qm start 101
sleep 60

# 3. If still failing, restore from backup
qm restore <backup-id> 101

# 4. Verify recovery
ssh ubuntu@10.10.0.10 "systemctl status kubelet"

# 5. Check cluster
kubectl get nodes
```

### Recovery from Storage Failure

```bash
# 1. Backup any remaining data
ssh ubuntu@10.10.0.10 "kubectl get pvc -A -o yaml > pvc-backup.yaml"

# 2. Recreate storage (if using local storage)
# Or provision new storage backend

# 3. Restore from etcd backup
ETCDCTL_API=3 etcdctl \
  --endpoints=127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot restore /backup/etcd-2024xxxx.db \
  --data-dir=/var/lib/etcd-restored

# 4. Switch to restored etcd
sudo mv /var/lib/etcd /var/lib/etcd-old
sudo mv /var/lib/etcd-restored /var/lib/etcd
sudo systemctl restart etcd
```

### Full Cluster Recovery

```bash
# 1. Destroy and recreate all VMs
cd terraform
terraform destroy -auto-approve
terraform apply -auto-approve

# 2. Re-bootstrap infrastructure
cd ../ansible
sleep 120
ansible all -i inventory.ini -m ping
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml

# 3. Restore application state from Git
kubectl apply -f cicd/

# 4. Restore data (if separate backup exists)
# ... (depends on backup method used)
```

---

## Documentation Requirements

Ensure following documents are kept up to date:

- [ ] `docs/architecture.md` - System design
- [ ] `docs/deployment-guide.md` - Initial setup
- [ ] `docs/network-design.md` - Network topology
- [ ] `docs/troubleshooting.md` - Common issues
- [ ] `docs/operations-runbook.md` - This file!
- [ ] `terraform/terraform.tfvars` - Infrastructure config (keep secret)
- [ ] `ansible/inventory.ini` - Generated from Terraform
- [ ] `logs/` - Deployment and operation logs

---

## Getting Help

1. **Check documentation**: Start with the relevant doc in `docs/`
2. **Check logs**: Run the health check script, collect logs
3. **Check troubleshooting.md**: Look for similar issue
4. **Consult team**: Ask colleagues for context
5. **Escalate**: Contact infrastructure team lead
6. **External support**: Check tool documentation (Kubernetes, Proxmox, etc.)

---

## Quick Command Reference

```bash
# VMs
ssh root@proxmox "qm list"              # List all VMs
qm start 101                             # Start VM
qm shutdown 101                          # Graceful shutdown
qm stop 101                              # Force shutdown
qm enter 101                             # Console access

# Kubernetes
kubectl cluster-info                     # Cluster info
kubectl get nodes                        # Node status
kubectl get pods -A                      # All pods
kubectl logs <pod> -n <ns>              # Pod logs
kubectl exec -it <pod> -n <ns> -- bash # SSH to pod
kubectl describe node <node>             # Node details
kubectl top nodes                        # Resource usage

# Ansible
ansible all -i inventory.ini -m ping    # Test connectivity
ansible-playbook ... -v                 # Verbose output
ansible-playbook ... --limit <host>    # Run on specific host
ansible-playbook ... --start-at-task    # Resume from task

# Terraform
terraform plan                           # Preview changes
terraform apply tfplan                  # Apply changes
terraform destroy                        # Delete resources
terraform output                         # View outputs

# Network
ping <ip>                               # Test connectivity
traceroute <ip>                         # Trace route
curl -x http://proxy:3128 <url>       # Test proxy
telnet <host> <port>                   # Test port
```

