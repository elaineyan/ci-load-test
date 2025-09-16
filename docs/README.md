# CI/CD Pipeline with Kubernetes Load Testing

## Overview
Automated CI/CD pipeline featuring Kubernetes deployment, monitoring, auto-scaling, and load testing.

## Quick Start

### Prerequisites
- Docker
- kubectl
- kind
- helm
- jq (for JSON parsing)
- bc (for calculations)

### Local Development
```bash
# 1. Setup KinD cluster with Metrics Server
bash scripts/setup-kind.sh

# 2. Deploy monitoring stack
bash scripts/deploy-monitoring.sh

# 3. Deploy applications with HPA
bash scripts/deploy-apps.sh

# 4. Verify deployment and HPA
bash scripts/verify-deployment.sh

# 5. Test echo services
bash scripts/test-echo-services.sh

# 6. Run comprehensive load test
bash scripts/load-test.sh