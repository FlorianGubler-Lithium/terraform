#!/bin/bash
# Install Kubernetes prerequisites: CRI-O, kubeadm, kubelet, kubectl
# Usage: ./k8s-prerequisites.sh [k8s_version]

set -euo pipefail

K8S_VERSION="${1:-1.30.0}"

echo "[k8s-prerequisites] Installing Kubernetes prerequisites..."
echo "[k8s-prerequisites] K8s version: $K8S_VERSION"

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Install CRI-O
echo "[k8s-prerequisites] Installing CRI-O..."
OS=xUbuntu_22.04
VERSION=1.30

# Add CRI-O repository
curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04 /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/VERSION/xUbuntu_22.04/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/VERSION/xUbuntu_22.04 /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:VERSION.list

sed -i "s|VERSION|${VERSION}|g" /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:VERSION.list

apt-get update
apt-get install -y cri-o

# Enable and start CRI-O
systemctl daemon-reload
systemctl enable crio
systemctl start crio

# Install Kubernetes tools
echo "[k8s-prerequisites] Installing Kubernetes tools..."

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/deb /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl

# Hold versions to prevent auto-upgrades
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl daemon-reload
systemctl enable kubelet

# Configure kernel modules and sysctl for Kubernetes
echo "[k8s-prerequisites] Configuring kernel modules and sysctl..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "[k8s-prerequisites] Kubernetes prerequisites installation completed!"

