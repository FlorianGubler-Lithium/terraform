#!/bin/bash
# Join Kubernetes worker node to cluster
# Usage: ./k8s-worker-join.sh <token> <cert_hash> <api_server>

set -euo pipefail

KUBEADM_TOKEN="${1:-}"
KUBEADM_CERT_HASH="${2:-}"
KUBE_APISERVER="${3:-}"

if [ -z "$KUBEADM_TOKEN" ] || [ -z "$KUBEADM_CERT_HASH" ] || [ -z "$KUBE_APISERVER" ]; then
    echo "[k8s-worker-join] ERROR: Missing required parameters"
    echo "[k8s-worker-join] Usage: $0 <token> <cert_hash> <api_server>"
    exit 1
fi

echo "[k8s-worker-join] Joining Kubernetes cluster..."
echo "[k8s-worker-join] API Server: $KUBE_APISERVER"
echo "[k8s-worker-join] Token: ${KUBEADM_TOKEN:0:10}..."

# Join the cluster
kubeadm join \
    "$KUBE_APISERVER" \
    --token "$KUBEADM_TOKEN" \
    --discovery-token-ca-cert-hash "sha256:$KUBEADM_CERT_HASH" \
    --cri-socket unix:///var/run/crio/crio.sock \
    --ignore-preflight-errors=NumCPU,MemSize

echo "[k8s-worker-join] Worker node joined successfully!"

