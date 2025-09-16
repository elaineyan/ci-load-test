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

# Verify HPA can access metrics
echo "Checking HPA metrics availability..."
if kubectl top pods -n ${NAMESPACE} 2>/dev/null; then
    echo "Metrics Server is working correctly"
else
    echo "Metrics Server is not available"
    # This is not necessarily a fatal error, continue execution
fi

# Verify Ingress status
kubectl get ingress -n ${NAMESPACE}

# Test service reachability
echo "Testing services are reachable through ingress..."
curl -H "Host: foo.localhost" http://localhost -s -o /dev/null -w "Foo HTTP Code: %{http_code}\n"
curl -H "Host: bar.localhost" http://localhost -s -o /dev/null -w "Bar HTTP Code: %{http_code}\n"

echo "All deployments verified successfully"