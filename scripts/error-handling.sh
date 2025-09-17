#!/bin/bash
# Author: Huilian Yan <elaine.yan0619@hotmail.com>
# Created: 2025-09-17
# Description: Error handling


# Retry function
retry() {
    local max_attempts=${2:-5}
    local delay=${3:-5}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$1"; then
            return 0
        else
            echo "Attempt $attempt failed. Retrying in $delay seconds..."
            sleep $delay
            ((attempt++))
        fi
    done
    
    echo "All $max_attempts attempts failed!"
    return 1
}

# Health check function
check_health() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-120}
    
    echo "Checking health of ${resource_type}/${resource_name} in ${namespace}..."
    
    if kubectl wait --for=condition=available ${resource_type}/${resource_name} \
        --namespace ${namespace} \
        --timeout=${timeout}s 2>/dev/null; then
        echo "${resource_type}/${resource_name} is healthy"
        return 0
    else
        echo "${resource_type}/${resource_name} health check failed"
        kubectl describe ${resource_type}/${resource_name} -n ${namespace}
        kubectl logs ${resource_type}/${resource_name} -n ${namespace} --all-containers=true --tail=50
        return 1
    fi
}

# Cleanup function
cleanup_on_failure() {
    echo "Cleaning up on failure..."
    bash scripts/cleanup.sh
    exit 1
}

# Set error handling
trap 'cleanup_on_failure' ERR