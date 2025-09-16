#!/bin/bash
set -e

echo "Deploying applications using Kustomize..."

# Deploy NGINX Ingress controller
URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
RAW_FILE="nginx-deploy.yaml"
OUT_FILE="nginx-deploy-nodeport.yaml"

echo "1. download deploy.yaml ..."
wget -O "$RAW_FILE" "$URL"

echo "2. find service which 'name: ingress-nginx-controller' change its type to NodePort ..."
sed -e '/^kind: Service$/,/^---$/{
        /name: ingress-nginx-controller/,/^---$/{
          s/type: LoadBalancer/type: NodePort/
        }
      }' "$RAW_FILE" > "$OUT_FILE"

kubectl apply -f "$OUT_FILE"

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
