#!/bin/bash
# Initialize Kubernetes master node with CRI-O and install Calico CNI
# Usage: ./k8s-master-init.sh <pod_cidr> [k8s_version]

set -euo pipefail

POD_CIDR="${1:-172.16.0.0/16}"
K8S_VERSION="${2:-1.30.0}"

echo "[k8s-master-init] Initializing Kubernetes master..."
echo "[k8s-master-init] Pod CIDR: $POD_CIDR"
echo "[k8s-master-init] K8s version: $K8S_VERSION"

# Initialize kubeadm with CRI-O socket
echo "[k8s-master-init] Running kubeadm init..."
kubeadm init \
    --cri-socket unix:///var/run/crio/crio.sock \
    --pod-network-cidr="$POD_CIDR" \
    --kubernetes-version="v$K8S_VERSION" \
    --ignore-preflight-errors=NumCPU,MemSize \
    --skip-token-print

echo "[k8s-master-init] kubeadm init completed!"

# Configure kubectl for root user
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Wait for API server to be ready
echo "[k8s-master-init] Waiting for API server to be ready..."
for i in {1..30}; do
    if kubectl get nodes &>/dev/null; then
        echo "[k8s-master-init] API server is ready!"
        break
    fi
    echo "[k8s-master-init] Waiting for API server... ($i/30)"
    sleep 2
done

# Install Calico CNI
echo "[k8s-master-init] Installing Calico CNI..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Wait for Tigera operator to be ready
sleep 10

# Apply Calico custom resource with configured pod CIDR
cat > /tmp/calico-cr.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: $POD_CIDR
      encapsulation: VXLan
      natOutgoing: Enabled
      nodeSelector: all()
EOF

kubectl apply -f /tmp/calico-cr.yaml

echo "[k8s-master-init] Calico CNI installation in progress..."

# Wait for all nodes to be ready
echo "[k8s-master-init] Waiting for control plane to be ready..."
for i in {1..60}; do
    if kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
        echo "[k8s-master-init] Control plane is ready!"
        break
    fi
    echo "[k8s-master-init] Waiting for control plane... ($i/60)"
    sleep 2
done

# Create join token and write to file
echo "[k8s-master-init] Creating join token..."
KUBEADM_TOKEN=$(kubeadm token create --ttl 24h)
KUBEADM_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
KUBE_APISERVER=$(grep server /root/.kube/config | head -1 | awk '{print $2}')

# Write join token to shared location
mkdir -p /var/lib
cat > /var/lib/k8s-join-token <<EOF
#!/bin/bash
# Kubernetes join token for worker nodes
export KUBEADM_TOKEN="$KUBEADM_TOKEN"
export KUBEADM_CERT_HASH="$KUBEADM_CERT_HASH"
export KUBE_APISERVER="$KUBE_APISERVER"
export CRI_SOCKET="unix:///var/run/crio/crio.sock"
EOF

chmod 644 /var/lib/k8s-join-token

echo "[k8s-master-init] Join token written to /var/lib/k8s-join-token"
echo "[k8s-master-init] Kubernetes master initialization completed!"

