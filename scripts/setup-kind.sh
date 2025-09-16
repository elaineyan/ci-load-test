#!/bin/bash
set -e

echo "Setting up KinD cluster with 3 nodes..."

# Install KinD
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install jq for JSON parsing and bc for calculations
sudo apt-get update
sudo apt-get install -y jq bc net-tools

# Create multi-node cluster configuration
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
    listenAddress: "0.0.0.0"
  - containerPort: 443
    hostPort: 443
    protocol: TCP
    listenAddress: "0.0.0.0"
#  - containerPort: 9090
#    hostPort: 9090
#    protocol: TCP
#    listenAddress: "0.0.0.0"
#  - containerPort: 3000
#    hostPort: 3000  # Grafana
#    protocol: TCP
#    listenAddress: "0.0.0.0"
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml --wait 10m

# Deploy Metrics Server for HPA
echo "Deploying Metrics Server for HPA..."
wget -O components.yaml https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Add '--kubelet-insecure-tls'
sed -i '/--kubelet-preferred-address-types/a\        - --kubelet-insecure-tls' components.yaml
kubectl apply -f components.yaml

# Wait for Metrics Server to be ready
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=k8s-app=metrics-server \
  --timeout=10m

# Verify Metrics Server installation
echo "Verifying Metrics Server installation..."
kubectl get apiservices v1beta1.metrics.k8s.io -o json | jq '.status.conditions'

# Verify cluster
echo "Cluster created successfully"
kubectl cluster-info
kubectl get nodes -o wide

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
#kubectl patch deploy -n ingress-nginx ingress-nginx-controller \
#  --type='json' \
#  -p='[{"op": "add","path":"/spec/template/spec/hostNetwork","value":true}]'
kubectl patch deploy -n ingress-nginx ingress-nginx-controller --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/hostNetwork","value":true}]'
  
kubectl patch deploy -n ingress-nginx ingress-nginx-controller --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"kubernetes.io/hostname":"ci-cluster-control-plane"}}]'
  
kubectl rollout restart deploy/ingress-nginx-controller -n ingress-nginx
kubectl rollout status  deploy/ingress-nginx-controller -n ingress-nginx

# Wait for Ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=30m

# Create namespaces
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ${MONITORING_NS} --dry-run=client -o yaml | kubectl apply -f -

# Pre-load http-echo image to KinD
docker pull hashicorp/http-echo
kind load docker-image hashicorp/http-echo --name ${CLUSTER_NAME}
