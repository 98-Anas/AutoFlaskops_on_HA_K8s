#!/bin/bash
set -euo pipefail

export CLUSTER_NAME="kubernetes"
export NFS_SERVER="$(getent hosts nfs | awk '{ print $1 }')"
export NFS_PATH="/export/k8s"
export ARGOCD_ADMIN_PASSWORD="$(openssl rand -base64 12)" # Auto-generated
# No DOMAIN needed; using path-based ingress

# Create namespaces if not exists
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace storage --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace gitops --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -

# Helm Repositories
helm repo add eks https://aws.github.io/eks-charts
helm repo add nfs-subdir https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 1. Ingress-Nginx Controller (Production-grade)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=kubernetes #update cluster name if needed


# 2. NFS Subdir Provisioner (Dynamic Storage)
helm upgrade --install nfs-provisioner nfs-subdir/nfs-subdir-external-provisioner \
  -n storage \
  --version 4.0.18 \
  --set nfs.server=$NFS_SERVER \
  --set nfs.path=$NFS_PATH \
  --set storageClass.defaultClass=true \

helm upgrade --install argocd argo/argo-cd \
  -n gitops \
  --version 8.1.3 \
  --set server.service.type=NodePort \
  --set configs.secret.argocdServerAdminPassword="$ARGOCD_ADMIN_PASSWORD"


# Post-Installation Configuration
echo "=== Installation Complete ==="
echo "- Argo CD Admin Password: $ARGOCD_ADMIN_PASSWORD"
echo "---------------------------------------"
echo "Access URLs:"
echo "Argo CD:  http://NodeIP:NodePort"
echo "---------------------------------------"
echo "To uninstall all: ./uninstall-controllers.sh"