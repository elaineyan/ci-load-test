#!/bin/bash
# Author: Huilian Yan <elaine.yan0619@hotmail.com>
# Created: 2025-09-17
# Description: Clean up


echo "Cleaning up resources..."

# Delete KinD cluster
kind delete cluster --name ${CLUSTER_NAME:-ci-cluster} 2>/dev/null || true

# Clean up temporary files
rm -f kind-config.yaml load-test-results.md 2>/dev/null || true

echo "Cleanup completed"