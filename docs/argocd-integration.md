# ArgoCD Integration & GitOps Workflow

## Overview

ArgoCD is deployed on both dev and prod Kubernetes clusters to manage all infrastructure and application deployments declaratively via Git. This document outlines the architecture, configuration, and operational workflows.

## Architecture

### Deployment Model

```
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Repository                         │
│  (lithium-infra: Terraform + Helm Charts + K8s Resources)  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Git Webhook
                     │ (Push events)
                     ▼
     ┌───────────────────────────────────┐
     │  ArgoCD (Dev Cluster)              │
     │  ┌─────────────────────────────┐   │
     │  │ ApplicationController       │   │
     │  │ (Syncs every 3 minutes)     │   │
     │  └──┬──────────────────────────┘   │
     │     │                              │
     │     ├─ Helm Charts ─────────┐      │
     │     │ (cicd/*/Chart.yaml)    │      │
     │     │                        │      │
     │     └─ K8s Resources ────────┼──────┼──> DevCluster
     │       (cicd/*/templates/)    │      │
     │                              │      │
     └──────────────────────────────┘      │
                                           │
     ┌───────────────────────────────────┐ │
     │  ArgoCD (Prod Cluster)             │ │
     │  ┌─────────────────────────────┐   │ │
     │  │ ApplicationController       │   │ │
     │  │ (Syncs every 5 minutes)     │   │ │
     │  └──┬──────────────────────────┘   │ │
     │     │                              │ │
     │     ├─ Helm Charts ─────────┐      │ │
     │     │ (cicd/*/Chart.yaml)    │      │ │
     │     │                        │      │ │
     │     └─ K8s Resources ────────┼──────┼─┼──> ProdCluster
     │       (cicd/*/templates/)    │      │ │
     │                              │      │ │
     └──────────────────────────────┘      │ │
                                           │ │
     ┌───────────────────────────────────┐ │ │
     │  GitHub Actions                    │ │ │
     │  - Validate Helm charts            │ │ │
     │  - Lint K8s manifests              │ │ │
     │  - Deploy to test cluster          │ │ │
     └────────────────────────────────────┘ │ │
                                            │ │
                 (External monitoring)      │ │
                 Prometheus/Grafana  ◄──────┘ │
                 AlertManager       ◄─────────┘
```

## Repository Structure

### Current Structure

```
lithium-infra/
├── cicd/
│   ├── argocd/             # ArgoCD core deployment
│   ├── calico/             # Network policies
│   ├── cert-manager/       # SSL certificates
│   ├── ci-access/          # GitHub Actions RBAC
│   ├── cloudflare/         # Tunnel & DNS
│   ├── grafana/            # Monitoring dashboards
│   ├── metallb/            # Load balancing
│   ├── persistent-volumes/ # Storage configuration
│   ├── prometheus/         # Metrics collection
│   ├── sealed-secrets/     # Secret management
│   ├── traefik/            # Ingress controller
│   └── production/         # Prod-specific config
│
├── terraform/              # Infrastructure provisioning
├── ansible/                # Configuration management
└── docs/                   # Documentation
```

### Enhanced Structure for ArgoCD

```
lithium-infra/
├── cicd/
│   ├── _base/                      # Shared base configs
│   │   ├── ingress-class.yaml
│   │   ├── namespace-argocd.yaml
│   │   └── namespace-system.yaml
│   │
│   ├── argocd/
│   │   ├── Chart.yaml
│   │   ├── values-common.yaml      # Shared config
│   │   ├── values-dev.yaml         # Dev overrides
│   │   ├── values-prod.yaml        # Prod overrides
│   │   ├── templates/
│   │   │   ├── config.yml
│   │   │   ├── namespace.yml
│   │   │   ├── ingress-route.yml
│   │   │   └── app-repository.yml  # Repo config
│   │   └── kustomization.yaml      # Kustomize support
│   │
│   ├── applications/
│   │   ├── dev/
│   │   │   ├── argocd-app.yaml     # ArgoCD self-reference
│   │   │   ├── infrastructure.yaml # All infra apps
│   │   │   └── kustomization.yaml
│   │   │
│   │   ├── prod/
│   │   │   ├── argocd-app.yaml
│   │   │   ├── infrastructure.yaml
│   │   │   └── kustomization.yaml
│   │   │
│   │   └── templates/
│   │       └── Application.yaml    # Template for new apps
│   │
│   ├── {other services}/
│   │   └── ... (existing structure)
│   │
│   └── kustomization.yaml          # Root overlay
│
├── terraform/
├── ansible/
│   └── playbooks/
│       └── 05-argocd-setup.yml
│
└── docs/
```

## ArgoCD Application Definitions

### Application Structure

Each infrastructure component becomes an ArgoCD Application:

```yaml
# argocd/applications/dev/traefik-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: traefik
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/your-org/lithium-infra.git
    targetRevision: main
    path: cicd/traefik
    helm:
      releaseName: traefik
      values: |
        # Inline overrides
        replicaCount: 1
  
  destination:
    server: https://kubernetes.default.svc
    namespace: traefik
  
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Correct drift from Git
    syncOptions:
    - CreateNamespace=true
    
  # Health assessment
  ignoreDifferences:
  - group: apiextensions.k8s.io
    kind: CustomResourceDefinition
    jsonPointers:
    - /spec/conversion/webhook/clientConfig/caBundle

notifications:
  triggers:
  - status-unknown
  - sync-failed
  - health-degraded
```

### Application Groups

```yaml
# argocd/applications/dev/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/lithium-infra.git
    targetRevision: main
    path: cicd/applications/dev
    plugin:
      name: kustomize
  
  destination:
    server: https://kubernetes.default.svc
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    # Order dependencies
    - RespectIgnoreDifferences=true
    
  # Multi-step sync with ordering
  dependsOn:
  - name: system-namespaces
  - name: sealed-secrets
```

### Kustomize Overlay Example

```yaml
# cicd/applications/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Base configuration (dev-specific)
bases:
- ../../_base

# Apply patches for dev
patchesStrategicMerge:
- deployment-patch.yaml

# Resource-specific customizations
resources:
- argocd-app.yaml
- traefik-app.yaml
- prometheus-app.yaml
- grafana-app.yaml
- sealed-secrets-app.yaml
- cert-manager-app.yaml
- calico-app.yaml
- metallb-app.yaml

# Common labels
commonLabels:
  environment: dev
  managed-by: argocd

# ConfigMap from files
configMapGenerator:
- name: env-config
  files:
  - config/prometheus-values.yaml

# Var substitution
vars:
- name: CLUSTER_NAME
  objref:
    kind: ConfigMap
    name: cluster-info
    apiVersion: v1
  fieldref:
    fieldpath: data.name
```

## Setup Playbook

### Ansible Playbook: 05-argocd-setup.yml

```yaml
---
- name: Setup ArgoCD on Kubernetes clusters
  hosts: k8s_masters
  vars:
    argocd_namespace: argocd
    argocd_chart_repo: https://argoproj.github.io/argo-helm
    argocd_version: 6.0.0  # Latest stable
    github_repo: https://github.com/your-org/lithium-infra.git
    github_branch: main

  tasks:
    - name: Add ArgoCD Helm repository
      kubernetes.core.helm_repository:
        name: argocd
        repo_url: "{{ argocd_chart_repo }}"
        state: present
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Create ArgoCD namespace
      kubernetes.core.k8s:
        name: "{{ argocd_namespace }}"
        api_version: v1
        kind: Namespace
        state: present
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Install ArgoCD via Helm
      kubernetes.core.helm:
        name: argocd
        release_namespace: "{{ argocd_namespace }}"
        chart_ref: argocd/argo-cd
        chart_version: "{{ argocd_version }}"
        values:
          configs:
            secret:
              argocdServerAdminPassword: "{{ argocd_admin_password | password_hash('sha256') }}"
              argocdServerAdminPasswordMtime: "{{ ansible_date_time.iso8601 }}"
          
          server:
            ingress:
              enabled: true
              annotations:
                cert-manager.io/cluster-issuer: "letsencrypt-prod"
              hosts:
              - "argocd.{{ cluster_domain }}"
              tls:
              - secretName: argocd-tls
                hosts:
                - "argocd.{{ cluster_domain }}"
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Wait for ArgoCD server to be ready
      kubernetes.core.k8s_info:
        kind: Deployment
        namespace: "{{ argocd_namespace }}"
        name: argocd-server
        wait: yes
        wait_condition:
          type: Available
          status: "True"
        wait_sleep: 10
        wait_timeout: 300
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Create GitHub credentials secret
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Secret
          metadata:
            name: github-credentials
            namespace: "{{ argocd_namespace }}"
          type: Opaque
          stringData:
            username: "{{ github_user }}"
            password: "{{ github_token }}"
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Add GitHub repository to ArgoCD
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: v1
          kind: Secret
          metadata:
            name: lithium-repo
            namespace: "{{ argocd_namespace }}"
            labels:
              argocd.argoproj.io/secret-type: repository
          stringData:
            type: git
            url: "{{ github_repo }}"
            password: "{{ github_token }}"
            username: "{{ github_user }}"
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Create infrastructure Application
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: argoproj.io/v1alpha1
          kind: Application
          metadata:
            name: infrastructure
            namespace: "{{ argocd_namespace }}"
          spec:
            project: default
            source:
              repoURL: "{{ github_repo }}"
              targetRevision: "{{ github_branch }}"
              path: "cicd/applications/{{ cluster_name }}"
              plugin:
                name: kustomize
            destination:
              server: https://kubernetes.default.svc
            syncPolicy:
              automated:
                prune: true
                selfHeal: true
              syncOptions:
              - CreateNamespace=true
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Wait for infrastructure sync to complete
      kubernetes.core.k8s_info:
        kind: Application
        namespace: "{{ argocd_namespace }}"
        name: infrastructure
        wait: yes
        wait_condition:
          type: Synced
          status: "True"
        wait_sleep: 5
        wait_timeout: 600
      environment:
        KUBECONFIG: /etc/kubernetes/admin.conf

    - name: Display ArgoCD access information
      debug:
        msg: |
          ArgoCD is now ready!
          URL: https://argocd.{{ cluster_domain }}
          Username: admin
          Password: (check argocd-initial-admin-secret)
          
          Get password:
          kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## GitOps Workflow

### Local Development

```bash
# 1. Clone repository
git clone https://github.com/your-org/lithium-infra.git
cd lithium-infra

# 2. Create feature branch
git checkout -b feature/new-monitoring

# 3. Update Helm charts or K8s manifests
vim cicd/prometheus/values-dev.yaml
vim cicd/prometheus/templates/servicemonitor.yml

# 4. Validate changes locally
helm template prometheus cicd/prometheus -f cicd/prometheus/values-dev.yaml | kubectl apply --dry-run=client -f -

# 5. Commit and push
git add cicd/
git commit -m "Add new Prometheus scrape target"
git push origin feature/new-monitoring

# 6. Create Pull Request
# - Automated tests run (linting, dry-run)
# - Manual review
# - Merge to main
```

### Automatic Synchronization

```
On Git Push to main:
├─ GitHub Webhook → ArgoCD
├─ ArgoCD detects diff
├─ User reviews in ArgoCD UI
└─ Automatic sync (if enabled) or manual trigger
   ├─ Helm diff preview
   ├─ Resource dry-run
   ├─ Apply to cluster
   └─ Monitor health
```

### Manual Sync Example

```bash
# Via Kubernetes API
argocd app sync infrastructure \
  --revision main \
  --prune

# Via kubectl
kubectl patch application infrastructure \
  -n argocd \
  -p '{"status":{"operationState":{"finishedAt":""}}}' \
  --type merge

# Monitor sync
argocd app wait infrastructure --timeout 300s
```

## Secret Management

### Sealed Secrets Integration

Sensitive data (credentials, API keys) is encrypted with sealed-secrets:

```yaml
# Original secret
apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: argocd
type: Opaque
stringData:
  token: "ghp_xxxxxxxxxxxxxxxxxxxx"

# Sealed secret (safe for Git)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: github-token
  namespace: argocd
spec:
  encryptedData:
    token: AgBZA4k7QqZ3dXjK/AaT7XqN0z4vB2cL9m...

---
# Usage in ArgoCD config
apiVersion: v1
kind: Secret
metadata:
  name: repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/your-org/lithium-infra.git
  password: "{{ sealed-secret.github-token.token }}"
  username: "{{ sealed-secret.github-user.username }}"
```

### Create Sealed Secret

```bash
# 1. Get sealing key from cluster
kubectl get secret -n kube-system sealed-secrets-key -o jsonpath='{.data}' | base64 -d > sealing-key.pem

# 2. Encrypt secret
echo -n "my-secret-value" | kubeseal -f - \
  --cert sealing-key.pub \
  -o yaml \
  --namespace argocd

# 3. Add sealed secret to Git repository
git add cicd/secrets/sealed-*.yaml
git commit -m "Add sealed secrets"
git push
```

## Multi-Environment Support

### Dev vs. Prod Configurations

```yaml
# cicd/prometheus/values-dev.yaml (Dev overrides)
global:
  scrapeInterval: 60s      # Less frequent in dev
  retentionDays: 7         # Shorter retention
  
persistence:
  size: 5Gi               # Smaller volume

replicas: 1               # Single replica in dev

# cicd/prometheus/values-prod.yaml (Prod settings)
global:
  scrapeInterval: 30s      # More frequent
  retentionDays: 30        # Longer retention
  
persistence:
  size: 50Gi              # Larger volume

replicas: 3               # HA setup in prod
```

### Cluster-Specific Overlays

```
cicd/applications/
├── _base/                    # Shared base
│   ├── kustomization.yaml
│   └── *.yaml
│
├── dev/                      # Dev overrides
│   ├── kustomization.yaml
│   ├── replicas-patch.yaml
│   └── resources-patch.yaml
│
└── prod/                     # Prod overrides
    ├── kustomization.yaml
    ├── replicas-patch.yaml
    ├── resources-patch.yaml
    └── hpa-patch.yaml
```

## Monitoring & Troubleshooting

### ArgoCD Health Checks

```bash
# Check application sync status
kubectl get applications -n argocd
kubectl describe application infrastructure -n argocd

# View application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# View server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Audit changes
kubectl logs -n argocd deployment/argocd-application-controller | grep "application infrastructure"
```

### Sync Issues

```bash
# Debug failed sync
argocd app get infrastructure --refresh

# View resource status
kubectl get all -n argocd

# Check resource hooks
kubectl get argocdprogress -n argocd

# Manual reconciliation
kubectl patch application infrastructure -n argocd \
  --type json \
  -p '[{"op":"replace","path":"/status/operationState/phase","value":"Succeeded"}]'
```

### Resource Drift Detection

ArgoCD automatically detects when cluster resources differ from Git:

```yaml
# View drift
kubectl get application infrastructure -o jsonpath='{.status.operationState.message}'

# Manual sync to fix drift
argocd app sync infrastructure --force-refresh
```

## GitHub Actions Integration

### Pre-merge Validation

```yaml
# .github/workflows/validate-infrastructure.yml
name: Validate Infrastructure

on:
  pull_request:
    paths:
    - 'cicd/**'

jobs:
  helm-lint:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Lint Helm charts
      run: |
        for chart in cicd/*/Chart.yaml; do
          helm lint $(dirname $chart)
        done
  
  kubernetes-lint:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Validate K8s manifests
      run: |
        kubectl apply -f cicd/ --dry-run=client
```

## Disaster Recovery

### Backup & Restore

```bash
# Backup ArgoCD configuration
kubectl get application -n argocd -o yaml > argocd-apps-backup.yaml
kubectl get secret -n argocd -o yaml > argocd-secrets-backup.yaml

# Restore
kubectl apply -f argocd-apps-backup.yaml
kubectl apply -f argocd-secrets-backup.yaml
```

### Cluster State Recovery

```bash
# ArgoCD replays entire infrastructure from Git
git clone https://github.com/your-org/lithium-infra.git
kubectl apply -f cicd/
argocd app sync infrastructure --force
```

## Future Enhancements

1. **Application Sets**: Deploy to multiple clusters with templating
2. **Notifications**: Slack/email on sync success/failure
3. **Role-based Access**: Different users manage different apps
4. **Policy as Code**: ArgoCD Policy Engine for compliance checks
5. **Cross-cluster GitOps**: Central console for dev + prod sync

