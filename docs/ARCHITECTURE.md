# System Architecture

## Overview

This CI/CD pipeline automates the deployment and testing of simple HTTP services on Kubernetes, with a focus on performance testing, auto-scaling, and monitoring.

## Architecture Diagram
GitHub Repository → GitHub Actions → KinD Cluster → Applications → Load Testing → Results
│ │ │ │ │
│ │ │ │ └──▶ Performance Metrics
│ │ │ └──▶ Monitoring (Prometheus/Grafana)
│ │ └──▶ Ingress Controller (NGINX)
│ └──▶ Configuration (Kustomize)
└──▶ Pull Request Trigger

## Component Details

### 1. CI/CD Pipeline (GitHub Actions)
- **Trigger**: Pull requests to main branch
- **Stages**: 
  - Cluster provisioning (KinD)
  - Monitoring deployment (Prometheus Stack)
  - Application deployment (Kustomize)
  - Health verification
  - Load testing
  - Results reporting

### 2. Kubernetes Cluster (KinD)
- **Nodes**: 3-node cluster (1 control-plane, 2 workers)
- **Network**: Port mappings for HTTP (80), HTTPS (443), and Prometheus (9090)
- **Features**: Pre-loaded container images for faster execution

### 3. Applications
- **Services**: Two http-echo instances (foo and bar)
- **Configuration**: Managed through Kustomize overlays
- **Routing**: NGINX Ingress with host-based routing
- **Monitoring**: ServiceMonitor for Prometheus scraping
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA) for automatic scaling

### 4. Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **ServiceMonitor**: Automatic discovery of application metrics
- **Metrics Server**: Provides resource metrics for HPA

### 5. Load Testing
- **Tool**: Hey HTTP load generator
- **Metrics**: Response times, success rates, throughput, HPA status
- **Integration**: Results posted to GitHub PR as comment

## Auto-scaling Implementation

### Horizontal Pod Autoscaling (HPA)
The system implements HPA with the following configuration:

- **Scale target**: CPU utilization (50%) and memory utilization (70%)
- **Replica range**: 2-10 pods per service
- **Metrics source**: Kubernetes Metrics Server
- **Scaling policies**: 
  - Stabilization window: 5 minutes
  - Scaling step: minimum 10% change

### HPA Integration Points
1. **Deployment resource configuration**: Set CPU and memory requests for Pods
2. **Metrics Server**: Provides resource utilization metrics
3. **HPA controller**: Automatically adjusts replica count based on metrics
4. **Load testing**: Generates sufficient load to trigger auto-scaling

## Configuration Management

### Kustomize Structure
kustomize/
├── base/ # Common configuration
├── overlays/
│ ├── foo/ # Foo-specific configuration
│ ├── bar/ # Bar-specific configuration
│ └── production/ # Production environment configuration

### Environment Separation
- **Development**: Local KinD cluster with basic configuration
- **Production**: Higher replicas, increased resources, production settings

## Data Flow

1. Code changes trigger GitHub Actions workflow
2. KinD cluster is provisioned with necessary components
3. Applications are deployed using Kustomize
4. Health checks ensure all components are running
5. Load tests generate traffic and collect metrics
6. HPA automatically scales pods based on load
7. Results are parsed and posted to GitHub PR
8. Cluster is cleaned up after completion

## Security Considerations

- Minimal permissions required for CI runner
- No sensitive data in configuration files
- Isolated test environment (KinD)
- Automated cleanup after tests

## Scaling Considerations

The architecture supports:
- Horizontal pod autoscaling based on CPU and memory usage
- Multiple parallel test executions
- Easy extension to additional services
- Integration with advanced monitoring solutions

## Failure Handling

- Retry mechanisms for transient failures
- Comprehensive logging for debugging
- Graceful degradation of non-critical components
- Automated cleanup on failure