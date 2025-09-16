#!/bin/bash
set -e

echo "Deploying monitoring stack..."

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Add Prometheus repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Deploy Prometheus Stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace ${MONITORING_NS} \
  --create-namespace \
  --values monitoring/prometheus-values.yaml \
  --wait \
  --timeout 5m

# Deploy ServiceMonitor
kubectl apply -f monitoring/servicemonitor.yaml

kubectl -n monitoring port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 --address 0.0.0.0 &
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80 --address 0.0.0.0 &

echo "Monitoring stack deployed"
kubectl get pods -n ${MONITORING_NS}
