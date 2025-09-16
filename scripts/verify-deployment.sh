#!/bin/bash
set -e

echo "Verifying deployments..."

# Import error handling functions
source scripts/error-handling.sh

# Verify deployment status
check_health deployment foo-deployment ${NAMESPACE} 120
check_health deployment bar-deployment ${NAMESPACE} 120

# Verify HPA status
echo "Verifying HPA configurations..."
kubectl get hpa -n ${NAMESPACE}

# Verify Ingress status
kubectl get ingress -n ${NAMESPACE}
kubectl get svc -n ingress-nginx

# Check port 
echo "Checking if port 80 is listening..."
if netstat -tuln | grep -q :80; then
    echo "✅ Port 80 is listening"
    docker ps -a
#    docker exec -it ci-cluster-control-plane bash -c 'ss -ltnp | grep -E ":80|:443"'
else
    echo "❌ Port 80 is not listening"
    # Find out the listening ports
    echo "Looking for NGINX listening ports..."
    kubectl get svc -n ingress-nginx
    kubectl describe svc ingress-nginx-controller -n ingress-nginx
fi

# Testing direct service access
echo "Testing direct service access..."

HTTP_CODE=$(curl -H "Host: foo.localhost" http://localhost -s -o /dev/null -w "%{http_code}" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Foo service is accessible (HTTP Code: $HTTP_CODE)"
    break
else
    # Diagnose network
    echo "Running network diagnostics..."
    echo "⚠️ Attempt $((RETRY_COUNT+1)) failed. HTTP Code: $HTTP_CODE"
    # Testing from within cluster
    echo "Testing from within cluster..."
    kubectl run test-connectivity --rm -it --image=curlimages/curl --restart=Never -- \
            sh -c 'curl -H "Host: foo.localhost" http://ingress-nginx-controller.ingress-nginx.svc.cluster.local && echo'
    
    # Setting up port forward as fallback
    echo "Setting up port forward as fallback..."
    kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80 &
    PORT_FORWARD_PID=$!
    sleep 5
    curl -H "Host: foo.localhost" http://localhost:8080 || echo "Port forward test failed"
    kill $PORT_FORWARD_PID
fi

# Final connectivity test
echo "Final connectivity test..."
MAX_RETRIES=10
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -H "Host: foo.localhost" http://localhost -s -o /dev/null -w "%{http_code}" || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Foo service is accessible (HTTP Code: $HTTP_CODE)"
        break
    else
        echo "⚠️ Attempt $((RETRY_COUNT+1)) failed. HTTP Code: $HTTP_CODE"
        RETRY_COUNT=$((RETRY_COUNT+1))
        sleep 10
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ All connectivity tests failed"
    # Collect more information
    kubectl describe ingress -n ${NAMESPACE}
    kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
    exit 1
fi

# Test service reachability
echo "Testing services are reachable through ingress..."
curl -H "Host: foo.localhost" http://localhost -s -o /dev/null -w "Foo HTTP Code: %{http_code}\n"
curl -H "Host: bar.localhost" http://localhost -s -o /dev/null -w "Bar HTTP Code: %{http_code}\n"

echo "All deployments verified successfully"
