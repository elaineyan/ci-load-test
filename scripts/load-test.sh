#!/bin/bash
# Author: Huilian Yan <elaine.yan0619@hotmail.com>
# Created: 2025-09-17
# Description: Load test


set -euo pipefail

# Read ENV and set default values
REQUESTS=${HEY_REQUESTS:-2000}
CONCURRENCY=${HEY_CONCURRENCY:-50}

echo "REQUESTS=$REQUESTS"
echo "CONCURRENCY=$CONCURRENCY"

echo "Running comprehensive load tests..."

# Install hey load testing tool
go install github.com/rakyll/hey@latest

# Function to parse hey output and extract metrics
parse_hey_output() {
    local host="$1"
    local service_name="$2"
    local output=$(cat "/tmp/${host}-hey-results.txt")
	
    # Extract key metrics using awk
    local total_time=$(echo "$output" | awk '/Total:/ {print $2}')
    local slowest=$(echo "$output" | awk '/Slowest:/ {print $2}')
    local fastest=$(echo "$output" | awk '/Fastest:/ {print $2}')
    local average=$(echo "$output" | awk '/Average:/ {print $2}')
    local rps=$(echo "$output" | awk '/Requests\/sec:/ {print $2}')
    
    # Extract latency percentiles
    local p90=$(echo "$output" | awk '/90%/ {print $3}')
    local p95=$(echo "$output" | awk '/95%/ {print $3}')
    local p99=$(echo "$output" | awk '/99%/ {print $3}')
    
    # Extract error rate
    local error_line=$(echo "$output" | grep -E "\[[0-9]+\] responses" | grep -v "200")
    local error_count=0
    local total_responses=0
    
    if [ -n "$error_line" ]; then
        error_count=$(echo "$error_line" | awk '{print $2}')
        # Get total responses from status code distribution
        total_responses=$(echo "$output" | grep -E "\[[0-9]+\] responses" | awk '{sum += $2} END {print sum}')
    fi
    
    local error_rate=0
    if [ $total_responses -gt 0 ]; then
        error_rate=$(echo "scale=2; $error_count * 100 / $total_responses" | bc)
    fi
    
    # Return JSON formatted results
    echo "{
        \"service\": \"$service_name\",
        \"total_time\": \"$total_time\",
        \"slowest\": \"$slowest\",
        \"fastest\": \"$fastest\",
        \"average\": \"$average\",
        \"requests_per_sec\": \"$rps\",
        \"p90\": \"$p90\",
        \"p95\": \"$p95\",
        \"p99\": \"$p99\",
        \"error_rate\": \"$error_rate%\",
        \"total_requests\": $total_responses,
        \"error_count\": $error_count
    }"
}

# Function to run hey test and return parsed results
run_hey_test() {
    local host="$1"
    local service="$2"
    local results_file="/tmp/${service}-hey-results.txt"
    
    #echo "Testing $service service..."
    hey -n "$REQUESTS" -c "$CONCURRENCY" -host "${host}.localhost" http://localhost > "$results_file" 2>&1
}

# Function to get HPA status
get_hpa_status() {
    local namespace=$1
    local hpa_name=$2
    kubectl get hpa -n $namespace $hpa_name -o json | jq '.status'
}

# Get Prometheus metrics function
get_metric() {
    local query="$1"
    curl -sG http://localhost:9090/api/v1/query \
	 --data-urlencode "query=${query}" |
    jq -r '.data.result[0].value[1] // "N/A"'
}

# Record pre-test metrics
echo "Recording pre-test metrics..."
CPU_BEFORE=$(get_metric 'sum(rate(container_cpu_usage_seconds_total{namespace="echo-apps"}[5m]))')
MEMORY_BEFORE=$(get_metric 'sum(container_memory_usage_bytes{namespace="echo-apps"})')
echo "CPU_BEFORE=$CPU_BEFORE"
echo "MEMORY_BEFORE=$MEMORY_BEFORE"

# Record pre-test HPA status and replica counts
echo "Recording pre-test HPA status..."
FOO_HPA_BEFORE=$(get_hpa_status ${NAMESPACE} foo-hpa)
BAR_HPA_BEFORE=$(get_hpa_status ${NAMESPACE} bar-hpa)
FOO_REPLICAS_BEFORE=$(kubectl get deployment foo-deployment -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
BAR_REPLICAS_BEFORE=$(kubectl get deployment bar-deployment -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
echo "FOO_REPLICAS_BEFORE=$FOO_REPLICAS_BEFORE"
echo "BAR_REPLICAS_BEFORE=$BAR_REPLICAS_BEFORE"

# Run load tests and capture parsed results
run_hey_test "foo" "foo" &
run_hey_test "bar" "bar" &
wait

# Parse results
FOO_JSON=$(parse_hey_output "foo" "foo")
BAR_JSON=$(parse_hey_output "bar" "bar")

# Record post-test metrics
echo "Recording post-test metrics..."
CPU_AFTER=$(get_metric 'sum(rate(container_cpu_usage_seconds_total{namespace="echo-apps"}[5m]))')
MEMORY_AFTER=$(get_metric 'sum(container_memory_usage_bytes{namespace="echo-apps"})')
echo "CPU_AFTER=$CPU_AFTER"
echo "MEMORY_AFTER=$MEMORY_AFTER"

# Record post-test HPA status and replica counts
echo "Recording post-test HPA status..."
sleep 10  # Wait for HPA to stabilize
FOO_HPA_AFTER=$(get_hpa_status ${NAMESPACE} foo-hpa)
BAR_HPA_AFTER=$(get_hpa_status ${NAMESPACE} bar-hpa)
FOO_REPLICAS_AFTER=$(kubectl get deployment foo-deployment -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
BAR_REPLICAS_AFTER=$(kubectl get deployment bar-deployment -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
echo "FOO_REPLICAS_AFTER=$FOO_REPLICAS_AFTER"
echo "BAR_REPLICAS_AFTER=$BAR_REPLICAS_AFTER"

# Extract values from JSON for table formatting
FOO_SERVICE=$(echo "$FOO_JSON" | jq -r '.service')
FOO_AVERAGE=$(echo "$FOO_JSON" | jq -r '.average')
FOO_P90=$(echo "$FOO_JSON" | jq -r '.p90')
FOO_P95=$(echo "$FOO_JSON" | jq -r '.p95')
FOO_P99=$(echo "$FOO_JSON" | jq -r '.p99')
FOO_ERROR_RATE=$(echo "$FOO_JSON" | jq -r '.error_rate')
FOO_RPS=$(echo "$FOO_JSON" | jq -r '.requests_per_sec')

BAR_SERVICE=$(echo "$BAR_JSON" | jq -r '.service')
BAR_AVERAGE=$(echo "$BAR_JSON" | jq -r '.average')
BAR_P90=$(echo "$BAR_JSON" | jq -r '.p90')
BAR_P95=$(echo "$BAR_JSON" | jq -r '.p95')
BAR_P99=$(echo "$BAR_JSON" | jq -r '.p99')
BAR_ERROR_RATE=$(echo "$BAR_JSON" | jq -r '.error_rate')
BAR_RPS=$(echo "$BAR_JSON" | jq -r '.requests_per_sec')

# Generate detailed report with formatted metrics
cat << EOF > load-test-results.md
## 📊 Comprehensive Load Test Report

### 🚀 Performance Metrics

| Service | Avg Latency | p90 | p95 | p99 | Error Rate | Requests/sec |
|---------|------------|-----|-----|-----|------------|-------------|
| $FOO_SERVICE | $FOO_AVERAGE | $FOO_P90 | $FOO_P95 | $FOO_P99 | $FOO_ERROR_RATE | $FOO_RPS |
| $BAR_SERVICE | $BAR_AVERAGE | $BAR_P90 | $BAR_P95 | $BAR_P99 | $BAR_ERROR_RATE | $BAR_RPS |

### 📈 Resource Utilization

| Metric | Before Test | After Test | Change |
|--------|-------------|------------|---------|
| CPU Usage | ${CPU_BEFORE} | ${CPU_AFTER} | +$(echo "scale=3; $CPU_AFTER - $CPU_BEFORE" | bc) |
| Memory Usage | $(echo "scale=2; $MEMORY_BEFORE / 1048576" | bc) MB | $(echo "scale=2; $MEMORY_AFTER / 1048576" | bc) MB | +$(echo "scale=2; ($MEMORY_AFTER - $MEMORY_BEFORE) / 1048576" | bc) MB |

### 🔄 Horizontal Pod Autoscaling Status

**Foo Service HPA:**
- Replicas before: ${FOO_REPLICAS_BEFORE}
- Replicas after: ${FOO_REPLICAS_AFTER}
- HPA status: 
\`\`\`json
${FOO_HPA_AFTER}
\`\`\`

**Bar Service HPA:**
- Replicas before: ${BAR_REPLICAS_BEFORE}
- Replicas after: ${BAR_REPLICAS_AFTER}
- HPA status: 
\`\`\`json
${BAR_HPA_AFTER}
\`\`\`

### 📋 Test Configuration
- **Total Requests**: 4,000 (2k per service)
- **Concurrent Users**: 50
- **Test Duration**: ~$(echo "$FOO_JSON" | jq -r '.total_time')

### 🔍 Detailed Metrics

**Foo Service:**
\`\`\`json
$FOO_JSON
\`\`\`

**Bar Service:**
\`\`\`json
$BAR_JSON
\`\`\`

### 📊 Autoscaling Analysis
- **Scaling triggered**: $(if [ "$FOO_REPLICAS_AFTER" -gt "$FOO_REPLICAS_BEFORE" ] || [ "$BAR_REPLICAS_AFTER" -gt "$BAR_REPLICAS_BEFORE" ]; then echo "Yes"; else echo "No"; fi)
- **Max replicas reached**: $(if [ "$FOO_REPLICAS_AFTER" -eq 10 ] || [ "$BAR_REPLICAS_AFTER" -eq 10 ]; then echo "Yes"; else echo "No"; fi)

### 🎯 Recommendations
1. **Performance**: Consider optimizing if p95 latency > 300ms
2. **Reliability**: Review errors if error rate > 1%
3. **Scaling**: Consider adjusting HPA thresholds if scaling behavior is not optimal

EOF

# Output results for GitHub Actions
echo "results<<EOF" >> $GITHUB_OUTPUT
cat load-test-results.md >> $GITHUB_OUTPUT
echo "EOF" >> $GITHUB_OUTPUT

echo "Load test completed successfully"
