#!/bin/bash
set -e

echo "Deploying applications using Kustomize..."

# Deploy NGINX Ingress controller
wget -O nginx-deploy.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl apply -f nginx-deploy.yaml

# Wait for Ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=30m

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Deploy applications using Kustomize
echo "Deploying foo application..."
kubectl apply -k kustomize/overlays/foo/

echo "Deploying bar application..."
kubectl apply -k kustomize/overlays/bar/

echo "Applications deployed successfully using Kustomize"
kubectl get deployments,services,ingress -n ${NAMESPACE}
