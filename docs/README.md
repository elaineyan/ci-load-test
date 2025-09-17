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
```

### Way to test
1. Pull the main branch to local

2. Create "one-time local script" as below:
```bash
# 1. Make sure you are on main and up to date
git checkout main
git pull origin main

# 2. Create a temporary branch and make any change (even an empty line)
git checkout -b test-pr-action
echo $RANDOM > test/test
git add .
git commit -m "Make change to test PR action."

# 3. Push the branch to remote
git push -u origin test-pr-action

# 4. Create the PR immediately (no browser needed)
# You may need to install gh first according your OS
# Go to Settings → Actions → General → Workflow permissions
# Check ✅ Read and write permissions
gh auth login # Only need to run at the first time
gh pr create --title "Test PR - trigger Actions"

# 5. Watch the Actions run
gh run watch  # Press Ctrl+C to exit
```