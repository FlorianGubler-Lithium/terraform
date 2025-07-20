# Kubernetes setup with raspberry pi cluster
This doc describes the installation and setup of the kubernetes cluster with raspberry pis. 

## 1. Install kubernetes on master & node hosts
See: [Kubeadm Installation](https://v1-28.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#k8s-install-0)

## 2. Install cri-o (container runtime for kuberenetes) on master & node hosts 
Note: Skip steps already done in kubernetes installation<br>
See: [CRI-O Installation](https://cri-o.io/)

## 3. Setup crio
Execute the following commands on master & node hosts
```
systemctl enable crio
systemctl start crio
echo 'br_netfilter' >> /etc/modules-load.d/modules.conf
modprobe br_netfilter
echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
sysctl net.ipv4.ip_forward=1
rm /etc/cni/net.d/11-crio-ipv4-bridge.conflist
```

## 4. Setup kubernetes master
```
kubeadm init --cri-socket=unix:///var/run/crio/crio.sock --pod-network-cidr 10.85.0.0/16 --upload-certs
```
Then evaluate the command to join nodes from the command output. It should look something like the following:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.20:6443 --token <TOKEN> --discovery-token-ca-cert-hash <DISCOVERY-TOKEN-HASH>
```
The important line is the last. 

## 5. Setup kubernetes nodes
```
kubeadm join 192.168.1.20:6443 --token <TOKEN> --discovery-token-ca-cert-hash <DISCOVERY-TOKEN-HASH>
```

## 6. Use kubectl from working machine
First copy the file in /etc/kubernetes/admin.conf in the tmp directory:
```
cp /etc/kubernetes/admin.conf /tmp/config
```
Then change the permissions, so every user can download it: 
```
chmod 777 /tmp/config
```
Lastly download the file wie ftp / ssh to your working machine. On windows you can do this by following:
```
scp <USER>@<MASTER-HOST-IP>:/tmp/config <LOCAL-USER-HOME-PATH>\.kube
```

## 7. Install Calico Network Manager
See: [Calico Installation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/helm)

## 8. Install operators with helm using Github Actions
See Github Actions -> Deploy
