#!/bin/bash
# Author: Huilian Yan <elaine.yan0619@hotmail.com>
# Created: 2025-09-17
# Description: Deploy apps

set -e

echo "Deploying applications using Kustomize..."

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Deploy applications using Kustomize
echo "Deploying foo application..."
kubectl apply -k kustomize/overlays/foo/

echo "Deploying bar application..."
kubectl apply -k kustomize/overlays/bar/

echo "Applications deployed successfully using Kustomize"
kubectl get deployments,services,ingress -n ${NAMESPACE}
