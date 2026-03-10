# Troubleshooting Guide

## Network & Connectivity Issues

### Symptom: VMs can't reach external network (no internet access)

**Diagnosis:**
```bash
# From any VM
ssh ubuntu@10.10.0.10
ping 8.8.8.8           # Should fail (expected)
ping 10.30.0.11        # Should succeed
curl -x http://10.30.0.11:3128 https://api.github.com  # Should work
```

**Solutions:**

1. **Proxy service not running**
   ```bash
   ssh ubuntu@10.30.0.11
   sudo systemctl status squid
   # If inactive, start it:
   sudo systemctl start squid
   ```

2. **Firewall blocking proxy traffic**
   ```bash
   # Check firewall rules on proxy VM
   ssh ubuntu@10.30.0.11 "sudo ufw status numbered"
   # Ensure port 3128 is open:
   ssh ubuntu@10.30.0.11 "sudo ufw allow 3128/tcp"
   ```

3. **Proxy not configured in VMs**
   ```bash
   # Check environment variables
   ssh ubuntu@10.10.0.10 "grep http_proxy /etc/environment"
   # Should show:
   # http_proxy=http://10.30.0.11:3128
   # https_proxy=http://10.30.0.11:3128
   ```

4. **Upstream DNS not resolving**
   ```bash
   # Check DNS on proxy
   ssh ubuntu@10.30.0.11 "cat /etc/resolv.conf"
   # Should have nameserver entries for upstream DNS
   # Test DNS resolution:
   ssh ubuntu@10.30.0.11 "nslookup api.github.com 8.8.8.8"
   ```

### Symptom: Zones can't communicate (dev ↔ prod isolation not working)

**Expected behavior:** Direct pings between zones should timeout (blocked by firewall)

**Diagnosis:**
```bash
# From dev zone, try to reach prod
ssh ubuntu@10.10.0.10 "ping -c 1 10.20.0.10"
# Expected: no response or timeout (good)

# If it succeeds, firewall is misconfigured
```

**Solutions:**

1. **Firewall rules not applied**
   ```bash
   ssh root@proxmox.host
   # Check if firewall VM is running
   qm status 100  # Should show "running"
   
   # SSH into firewall and verify rules
   ssh ubuntu@10.30.0.1
   sudo iptables -L FORWARD -v
   # Should show DROP rules for cross-zone traffic
   ```

2. **VLAN not tagged correctly**
   ```bash
   # On Proxmox host
   ip link show
   # Should show vlan100, vlan200, vlan300 bridges
   
   # Check VM network config
   ssh ubuntu@10.10.0.10 "ip addr show"
   # Should show eth0 with 10.10.0.x address
   ```

### Symptom: SSH connection timeout to VMs

**Diagnosis:**
```bash
# Test connectivity
ssh -v -i ~/.ssh/id_lithium ubuntu@10.10.0.10
# Look for timeout messages

# Check if VM is running
ssh root@proxmox "qm status 101"  # Should show "running"

# Check if VM has network access
ssh root@proxmox "qm guest exec 101 -- ip addr"
```

**Solutions:**

1. **VM not fully booted yet**
   ```bash
   # Cloud-init takes 1-2 minutes to complete
   sleep 180
   ansible all -i ansible/inventory.ini -m ping
   ```

2. **SSH not configured in image**
   ```bash
   # Check SSH service on VM
   ssh root@proxmox "qm guest exec 101 -- systemctl status ssh"
   # If not running, start it:
   ssh root@proxmox "qm guest exec 101 -- systemctl start ssh"
   ```

3. **SSH key not deployed**
   ```bash
   # Verify public key is in template
   ssh root@proxmox "qm config 9000" | grep -A5 serial0
   # Cloud-init should inject SSH key from metadata
   
   # Re-run base setup playbook
   ansible-playbook -i ansible/inventory.ini \
     ansible/playbooks/00-base-setup.yml --limit kube-dev-master-001
   ```

4. **Ansible SSH key path incorrect**
   ```bash
   # Check inventory
   cat ansible/inventory.ini | grep ansible_ssh_private_key
   # Should point to valid SSH private key
   
   # Test directly
   ssh -i ~/.ssh/id_lithium ubuntu@10.10.0.10
   ```

---

## Kubernetes Issues

### Symptom: Nodes showing as NotReady

**Diagnosis:**
```bash
ssh ubuntu@10.10.0.10
kubectl get nodes
# Expected output: all nodes with STATUS=Ready

# Check node status details
kubectl describe node kube-dev-worker-001
# Look for "Conditions" section
```

**Solutions:**

1. **Kubelet service not running**
   ```bash
   ssh ubuntu@10.10.0.11  # Worker node
   sudo systemctl status kubelet
   # If inactive:
   sudo systemctl start kubelet
   sudo journalctl -u kubelet -n 50  # Check logs
   ```

2. **Network plugin not installed or broken**
   ```bash
   ssh ubuntu@10.10.0.10  # Master node
   kubectl get pods -n kube-flannel
   # All pods should be Running
   
   # If not, reinstall:
   kubectl apply -f \
     https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
   ```

3. **VLAN/network misconfiguration**
   ```bash
   # Check network interfaces on nodes
   ssh ubuntu@10.10.0.11 "ip addr show"
   # Should show eth0 with IP in 10.10.0.0/24 range
   
   # Check routing
   ssh ubuntu@10.10.0.11 "ip route"
   # Should have route to pod network via gateway
   ```

### Symptom: Pods stuck in Pending state

**Diagnosis:**
```bash
kubectl get pods -A
# Look for pods with STATUS=Pending

kubectl describe pod <pod-name> -n <namespace>
# Look for "Events" section
```

**Solutions:**

1. **No available nodes**
   ```bash
   # Check node availability
   kubectl get nodes
   # If any NotReady, fix them first (see above)
   
   # Check node taints
   kubectl describe node kube-dev-master-001 | grep Taints
   # Master nodes have taint for scheduling control plane only
   # This is expected
   ```

2. **Insufficient resources**
   ```bash
   # Check node capacity
   kubectl describe node kube-dev-worker-001 | grep -A10 "Allocatable"
   
   # Check resource requests in pod
   kubectl describe pod <pod-name> -n <namespace>
   # Look for "Limits" and "Requests"
   
   # If pod requests exceed available resources, delete other pods or add nodes
   ```

3. **Pod network not ready**
   ```bash
   # Check CNI status
   kubectl get pods -n kube-flannel -o wide
   # All should be Running
   
   # Check cluster network
   kubectl get services
   # kubernetes.default.svc should be accessible
   ```

### Symptom: Master node initialization failed

**Diagnosis:**
```bash
ssh ubuntu@10.10.0.10
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
# Check error messages

# Check kubeadm logs
sudo journalctl -u kubelet -n 100 | grep "kubeadm"
```

**Solutions:**

1. **Port already in use**
   ```bash
   # Check if Kubernetes is already initialized
   ls -la /etc/kubernetes/admin.conf
   # If exists, cluster is already set up
   
   # Reset cluster (WARNING: data loss)
   sudo kubeadm reset -f
   sudo rm -rf /var/lib/kubernetes
   ```

2. **Cgroup driver mismatch**
   ```bash
   # Check cgroup driver
   docker info | grep "Cgroup Driver"
   containerd --version
   
   # Check kubelet config
   cat /var/lib/kubelet/kubeadm-flags.env
   
   # Fix in /etc/kubernetes/kubelet-config.yaml
   sudo vim /etc/kubernetes/kubelet-config.yaml
   # Set: cgroupDriver: systemd
   ```

3. **Swap enabled**
   ```bash
   # Kubernetes requires swap disabled
   free | grep Swap
   # If showing any swap, disable it:
   sudo swapoff -a
   ```

### Symptom: Worker node can't join cluster

**Diagnosis:**
```bash
ssh ubuntu@10.10.0.11  # Worker
sudo kubeadm join <master>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
# Check error messages
```

**Solutions:**

1. **Invalid token or discovery hash**
   ```bash
   # Get fresh token from master
   ssh ubuntu@10.10.0.10
   sudo kubeadm token create --print-join-command
   # Copy the full command and run on worker
   ```

2. **Port 6443 (API server) not accessible**
   ```bash
   # Test connectivity from worker to master
   ssh ubuntu@10.10.0.11 "curl -k https://10.10.0.10:6443/api"
   # Should not timeout
   
   # Check firewall on master
   ssh ubuntu@10.10.0.10 "sudo ufw status"
   # Should allow port 6443:
   sudo ufw allow 6443/tcp
   ```

3. **Kubelet configuration issue**
   ```bash
   # Reset kubelet on worker
   ssh ubuntu@10.10.0.11
   sudo systemctl stop kubelet
   sudo rm -rf /var/lib/kubelet/*
   sudo systemctl start kubelet
   
   # Then re-run join command
   ```

---

## ArgoCD Issues

### Symptom: ArgoCD application stuck in OutOfSync

**Diagnosis:**
```bash
kubectl -n argocd get applications
# STATUS should be "Synced"

kubectl -n argocd describe application infrastructure
# Look for "operationState" section
```

**Solutions:**

1. **Git repository disconnected**
   ```bash
   # Check repository secret
   kubectl -n argocd get secret repo-credentials -o yaml | grep url
   
   # Test Git access
   ssh ubuntu@10.30.0.10
   git clone https://github.com/your-org/lithium-infra.git
   # Should succeed
   ```

2. **Manifest syntax error**
   ```bash
   # Check application logs
   kubectl logs -n argocd deployment/argocd-application-controller | tail -50
   
   # Validate manifests locally
   kubectl apply -f cicd/ --dry-run=client
   # Fix any validation errors
   ```

3. **Resource already exists elsewhere**
   ```bash
   # ArgoCD can't apply resources if they exist outside Helm releases
   # Check if resource exists:
   kubectl get <resource> -A | grep <name>
   # Delete or relabel it
   ```

### Symptom: ArgoCD server not accessible

**Diagnosis:**
```bash
kubectl -n argocd get service argocd-server
# Should show EXTERNAL-IP (if LoadBalancer) or port-forward

kubectl -n argocd get pods | grep argocd-server
# Should be Running
```

**Solutions:**

1. **Pod not running**
   ```bash
   # Check pod logs
   kubectl logs -n argocd argocd-server-xxxxx
   # Fix issues based on error messages
   
   # Restart pod
   kubectl delete pod -n argocd argocd-server-xxxxx
   # Kubernetes will restart it
   ```

2. **Service not exposed**
   ```bash
   # Create port-forward if needed
   kubectl -n argocd port-forward svc/argocd-server 8443:443 &
   # Access at https://localhost:8443
   
   # Or create Ingress
   kubectl apply -f - << 'EOF'
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: argocd-server
     namespace: argocd
   spec:
     rules:
     - host: argocd.local
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: argocd-server
               port:
                 number: 443
   EOF
   ```

3. **Authentication failed**
   ```bash
   # Reset admin password
   kubectl -n argocd patch secret argocd-secret -p \
     '{"stringData": {"admin.password": "new-password"}}'
   
   # Get temporary password
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d
   ```

---

## Ansible Playbook Issues

### Symptom: Playbook fails with connection error

**Diagnosis:**
```bash
# Test connectivity first
ansible all -i ansible/inventory.ini -m ping -v

# Run playbook with verbose output
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/00-base-setup.yml -v -t "first_task"
```

**Solutions:**

1. **Inventory file incorrect**
   ```bash
   # Check inventory syntax
   ansible-inventory -i ansible/inventory.ini --list | head -20
   
   # Regenerate from Terraform
   cd terraform && terraform output -raw inventory > ../ansible/inventory.ini
   ```

2. **SSH key permissions**
   ```bash
   # Fix SSH key permissions
   chmod 600 ~/.ssh/id_lithium
   chmod 700 ~/.ssh
   
   # Test SSH directly
   ssh -i ~/.ssh/id_lithium ubuntu@10.10.0.10
   ```

3. **Ansible host key checking**
   ```bash
   # Disable StrictHostKeyChecking for initial run
   export ANSIBLE_HOST_KEY_CHECKING=False
   ansible-playbook -i ansible/inventory.ini \
     ansible/playbooks/bootstrap-all.yml
   
   # Or add to ansible.cfg:
   [defaults]
   host_key_checking = False
   ```

### Symptom: Specific task fails during playbook

**Diagnosis:**
```bash
# Run playbook with failure details
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/bootstrap-all.yml -v --tb=short

# Re-run just failed task
ansible-playbook -i ansible/inventory.ini \
  ansible/playbooks/bootstrap-all.yml -v --start-at-task="task name"
```

**Solutions:**

1. **Package installation fails**
   ```bash
   # Apt cache may be locked
   ssh ubuntu@10.10.0.10
   sudo lsof /var/lib/apt/lists/lock
   # Kill any running apt processes
   
   # Or wait and retry
   sleep 60 && ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml
   ```

2. **Command or script failure**
   ```bash
   # Check what command failed
   ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml -v | grep FAILED
   
   # Run command manually to debug
   ssh ubuntu@10.10.0.10
   <run the failing command>
   ```

3. **Idempotency issue (task runs every time)**
   ```bash
   # Task should be idempotent (safe to run multiple times)
   # If it fails on second run, there's a logic issue
   
   # Example of non-idempotent task (BAD):
   - shell: echo "text" >> /tmp/file.txt
   # This appends every time, should use:
   - lineinfile:
       path: /tmp/file.txt
       line: "text"
   ```

---

## Proxy/Firewall Issues

### Symptom: Traffic blocked between zones

**Diagnosis:**
```bash
# From dev, try to reach prod (should timeout)
ssh ubuntu@10.10.0.10 "traceroute 10.20.0.10"

# Check firewall rules
ssh root@proxmox "qm exec 100 -- iptables -L FORWARD -v"
# Should show rules blocking cross-zone traffic
```

**Solutions:**

1. **Firewall VM not running**
   ```bash
   ssh root@proxmox "qm status 100"
   # If stopped, start it:
   qm start 100
   ```

2. **Firewall rules not applied**
   ```bash
   # SSH to firewall VM
   ssh ubuntu@10.30.0.1
   
   # Check current rules
   sudo iptables -L -v
   
   # Reapply rules
   sudo bash /opt/firewall-setup.sh
   # (Or manually add iptables rules)
   ```

3. **Firewall bridge configuration wrong**
   ```bash
   # Check interfaces on firewall
   ip addr show
   # Should have eth0-3, each on different network
   
   # Verify routing
   ip route
   # Should have routes to all three zones
   ```

### Symptom: Proxy returns 403 Forbidden

**Diagnosis:**
```bash
# Test proxy directly
curl -x http://10.30.0.11:3128 -v https://api.github.com

# Check proxy ACLs
ssh ubuntu@10.30.0.11 "grep '^acl ' /etc/squid/squid.conf | head -20"
```

**Solutions:**

1. **ACL doesn't include source IP**
   ```bash
   # Check Squid config
   ssh ubuntu@10.30.0.11
   sudo grep "http_access" /etc/squid/squid.conf | grep -i allow
   # Should allow traffic from 10.0.0.0/8
   
   # Add rule if missing:
   echo 'acl internal_networks src 10.0.0.0/8' | sudo tee -a /etc/squid/squid.conf
   echo 'http_access allow internal_networks' | sudo tee -a /etc/squid/squid.conf
   sudo systemctl restart squid
   ```

2. **Destination URL blocked**
   ```bash
   # Check dstdomain ACLs
   ssh ubuntu@10.30.0.11 "grep dstdomain /etc/squid/squid.conf"
   
   # Check proxy logs
   sudo tail -100 /var/log/squid/access.log | grep "DENIED"
   
   # Add exceptions as needed
   ```

3. **Proxy cache configuration issue**
   ```bash
   # Clear proxy cache
   ssh ubuntu@10.30.0.11
   sudo systemctl stop squid
   sudo rm -rf /var/spool/squid/*
   sudo squid -z
   sudo systemctl start squid
   ```

---

## Recovery Procedures

### Emergency Restart of All VMs

```bash
# On Proxmox host
for vmid in 100 101 102 103 104 105 106 107 108 109 110 111 112; do
  qm start $vmid
done

# Wait for all to boot
sleep 180

# Verify connectivity
ansible all -i ansible/inventory.ini -m ping
```

### Rebuild Single Node Cluster

```bash
# Example: Rebuild dev master node (vmid 101)

# Stop node
ssh root@proxmox "qm stop 101"

# Delete VM
ssh root@proxmox "qm destroy 101"

# Recreate (re-run Terraform)
cd terraform
terraform apply -auto-approve

# Generate new inventory
terraform output -raw inventory > ../ansible/inventory.ini

# Bootstrap new node
cd ../ansible
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml --limit kube-dev-master-001
```

### Full Cluster Reset

```bash
# WARNING: This deletes all VMs and cluster data

# Destroy all infrastructure
cd terraform
terraform destroy -auto-approve

# Re-create
terraform apply -auto-approve

# Re-bootstrap
cd ../ansible
sleep 120
ansible all -i inventory.ini -m ping
ansible-playbook -i inventory.ini playbooks/bootstrap-all.yml
```

---

## Monitoring & Health Checks

### Regular Health Check Script

```bash
#!/bin/bash
# scripts/health-check.sh

echo "=== VMs Running ===" 
qm list | grep -E "running|stopped"

echo "=== Network Connectivity ===" 
ansible all -i ansible/inventory.ini -m ping -q

echo "=== Kubernetes Nodes ===" 
ssh ubuntu@10.10.0.10 "kubectl get nodes"

echo "=== ArgoCD Status ===" 
ssh ubuntu@10.10.0.10 "kubectl -n argocd get application"

echo "=== Pod Status ===" 
ssh ubuntu@10.10.0.10 "kubectl get pods -A --field-selector=status.phase!=Running"

echo "=== Proxy Service ===" 
ssh ubuntu@10.30.0.11 "sudo systemctl status squid -l"
```

Run regularly:
```bash
bash scripts/health-check.sh
```

---

## Reporting Issues

When reporting issues, include:
1. Exact error message
2. Steps to reproduce
3. Environment info: Proxmox version, Kubernetes version, Ansible version
4. Relevant logs:
   ```bash
   kubectl logs -n <namespace> <pod-name>
   ansible-playbook ... -v > playbook-output.log
   ssh vm 'sudo journalctl -n 100'
   ```

