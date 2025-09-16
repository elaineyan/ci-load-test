#!/bin/bash

echo "Cleaning up resources..."

# Delete KinD cluster
kind delete cluster --name ${CLUSTER_NAME:-ci-cluster} 2>/dev/null || true

# Clean up temporary files
rm -f kind-config.yaml load-test-results.md 2>/dev/null || true

echo "Cleanup completed"