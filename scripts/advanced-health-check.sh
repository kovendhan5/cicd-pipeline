#!/bin/bash
# 🔧 CI/CD Pipeline - Advanced Health Check Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_NAMESPACE="cicd-production"
DEFAULT_TIMEOUT="300s"
DEFAULT_RETRIES=3

# Parse command line arguments
NAMESPACE=${1:-$DEFAULT_NAMESPACE}
TIMEOUT=${2:-$DEFAULT_TIMEOUT}
RETRIES=${3:-$DEFAULT_RETRIES}

echo -e "${BLUE}🔍 CI/CD Pipeline Advanced Health Check${NC}"
echo -e "${BLUE}=====================================${NC}"
echo
echo "Namespace: $NAMESPACE"
echo "Timeout: $TIMEOUT"
echo "Retries: $RETRIES"
echo

# Function to check command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed or not in PATH${NC}"
        return 1
    fi
    return 0
}

# Function to retry command
retry_command() {
    local cmd="$1"
    local description="$2"
    local count=0
    
    while [ $count -lt $RETRIES ]; do
        if eval "$cmd" &> /dev/null; then
            return 0
        fi
        count=$((count + 1))
        if [ $count -lt $RETRIES ]; then
            echo -e "${YELLOW}⚠️  $description failed, retrying ($count/$RETRIES)...${NC}"
            sleep 2
        fi
    done
    return 1
}

# Function to check pod health
check_pod_health() {
    local app_label="$1"
    local description="$2"
    
    echo -e "${CYAN}🔍 Checking $description...${NC}"
    
    # Check if pods exist
    if ! kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --no-headers 2>/dev/null | grep -q .; then
        echo -e "${RED}❌ No pods found for $description${NC}"
        return 1
    fi
    
    # Check pod status
    local not_ready=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
    if [ "$not_ready" -gt 0 ]; then
        echo -e "${RED}❌ $not_ready pods are not ready for $description${NC}"
        kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label"
        return 1
    fi
    
    echo -e "${GREEN}✅ $description pods are healthy${NC}"
    return 0
}

# Function to check service endpoints
check_service_endpoints() {
    local service_name="$1"
    local description="$2"
    
    echo -e "${CYAN}🔍 Checking $description service...${NC}"
    
    # Check if service exists
    if ! kubectl get svc "$service_name" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${RED}❌ Service $service_name not found${NC}"
        return 1
    fi
    
    # Check if service has endpoints
    local endpoints=$(kubectl get endpoints "$service_name" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [ -z "$endpoints" ]; then
        echo -e "${RED}❌ Service $service_name has no endpoints${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ $description service is healthy${NC}"
    return 0
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local description="$2"
    local expected_code="${3:-200}"
    
    echo -e "${CYAN}🔍 Testing $description endpoint...${NC}"
    
    if retry_command "curl -sf -w '%{http_code}' -o /dev/null '$url' | grep -q '$expected_code'" "$description HTTP test"; then
        echo -e "${GREEN}✅ $description endpoint is responding${NC}"
        return 0
    else
        echo -e "${RED}❌ $description endpoint is not responding${NC}"
        return 1
    fi
}

# Function to check resource usage
check_resource_usage() {
    local app_label="$1"
    local description="$2"
    
    echo -e "${CYAN}🔍 Checking $description resource usage...${NC}"
    
    # Get resource usage
    local cpu_usage=$(kubectl top pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' | sed 's/m//')
    local memory_usage=$(kubectl top pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum}' | sed 's/Mi//')
    
    if [ -n "$cpu_usage" ] && [ "$cpu_usage" -gt 0 ]; then
        echo -e "${GREEN}✅ $description CPU usage: ${cpu_usage}m${NC}"
    else
        echo -e "${YELLOW}⚠️  Unable to get $description CPU usage${NC}"
    fi
    
    if [ -n "$memory_usage" ] && [ "$memory_usage" -gt 0 ]; then
        echo -e "${GREEN}✅ $description Memory usage: ${memory_usage}Mi${NC}"
    else
        echo -e "${YELLOW}⚠️  Unable to get $description memory usage${NC}"
    fi
    
    return 0
}

# Function to check logs for errors
check_logs_for_errors() {
    local app_label="$1"
    local description="$2"
    
    echo -e "${CYAN}🔍 Checking $description logs for errors...${NC}"
    
    local error_count=$(kubectl logs -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --tail=100 --since=5m 2>/dev/null | grep -i "error\|exception\|failed\|fatal" | wc -l)
    
    if [ "$error_count" -eq 0 ]; then
        echo -e "${GREEN}✅ No recent errors in $description logs${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Found $error_count error(s) in $description logs${NC}"
        kubectl logs -n "$NAMESPACE" -l "app.kubernetes.io/name=$app_label" --tail=10 --since=5m 2>/dev/null | grep -i "error\|exception\|failed\|fatal" | head -3
        return 1
    fi
}

# Main health check function
main_health_check() {
    local overall_status=0
    
    echo -e "${PURPLE}🏥 Starting Comprehensive Health Check${NC}"
    echo
    
    # Prerequisites check
    echo -e "${BLUE}📋 Prerequisites Check${NC}"
    echo "====================="
    
    if ! check_command kubectl; then
        echo -e "${RED}❌ kubectl is required for health checks${NC}"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo -e "${RED}❌ Namespace $NAMESPACE does not exist${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Namespace $NAMESPACE exists${NC}"
    echo
    
    # Application Health Checks
    echo -e "${BLUE}🚀 Application Health Checks${NC}"
    echo "============================"
    
    # Check main application
    if ! check_pod_health "cicd-pipeline" "Main Application"; then
        overall_status=1
    fi
    
    if ! check_service_endpoints "cicd-pipeline" "Main Application"; then
        overall_status=1
    fi
    
    check_resource_usage "cicd-pipeline" "Main Application"
    
    if ! check_logs_for_errors "cicd-pipeline" "Main Application"; then
        overall_status=1
    fi
    echo
    
    # Database Health Checks
    echo -e "${BLUE}🗃️  Database Health Checks${NC}"
    echo "========================="
    
    if ! check_pod_health "postgresql" "PostgreSQL Database"; then
        overall_status=1
    fi
    
    if ! check_service_endpoints "cicd-pipeline-postgresql" "PostgreSQL Database"; then
        overall_status=1
    fi
    
    check_resource_usage "postgresql" "PostgreSQL Database"
    
    if ! check_logs_for_errors "postgresql" "PostgreSQL Database"; then
        overall_status=1
    fi
    echo
    
    # Cache Health Checks
    echo -e "${BLUE}🗂️  Cache Health Checks${NC}"
    echo "====================="
    
    if ! check_pod_health "redis" "Redis Cache"; then
        overall_status=1
    fi
    
    if ! check_service_endpoints "cicd-pipeline-redis" "Redis Cache"; then
        overall_status=1
    fi
    
    check_resource_usage "redis" "Redis Cache"
    
    if ! check_logs_for_errors "redis" "Redis Cache"; then
        overall_status=1
    fi
    echo
    
    # Ingress and Networking
    echo -e "${BLUE}🌐 Network Health Checks${NC}"
    echo "======================="
    
    # Check ingress
    if kubectl get ingress -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ Ingress is configured${NC}"
        kubectl get ingress -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️  No ingress found${NC}"
    fi
    
    # Check network policies
    local netpol_count=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$netpol_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Network policies are configured ($netpol_count)${NC}"
    else
        echo -e "${YELLOW}⚠️  No network policies found${NC}"
    fi
    echo
    
    # Security Health Checks
    echo -e "${BLUE}🔒 Security Health Checks${NC}"
    echo "========================"
    
    # Check RBAC
    local rbac_count=$(kubectl get rolebindings,clusterrolebindings -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$rbac_count" -gt 0 ]; then
        echo -e "${GREEN}✅ RBAC is configured ($rbac_count bindings)${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited RBAC configuration${NC}"
    fi
    
    # Check secrets
    local secret_count=$(kubectl get secrets -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "default-token\|sh.helm.release" | wc -l)
    if [ "$secret_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Secrets are configured ($secret_count)${NC}"
    else
        echo -e "${RED}❌ No application secrets found${NC}"
        overall_status=1
    fi
    
    # Check security contexts
    local pods_with_security_context=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.securityContext.runAsNonRoot}{"\n"}{end}' 2>/dev/null | grep -c "true" || echo "0")
    if [ "$pods_with_security_context" -gt 0 ]; then
        echo -e "${GREEN}✅ Security contexts are configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Security contexts may need review${NC}"
    fi
    echo
    
    # Performance Health Checks
    echo -e "${BLUE}⚡ Performance Health Checks${NC}"
    echo "============================"
    
    # Check HPA
    if kubectl get hpa -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ Horizontal Pod Autoscaler is configured${NC}"
        kubectl get hpa -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️  No Horizontal Pod Autoscaler found${NC}"
    fi
    
    # Check resource quotas
    if kubectl get resourcequota -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ Resource quotas are configured${NC}"
    else
        echo -e "${YELLOW}⚠️  No resource quotas found${NC}"
    fi
    
    # Check pod disruption budgets
    local pdb_count=$(kubectl get pdb -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$pdb_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Pod Disruption Budgets are configured ($pdb_count)${NC}"
    else
        echo -e "${YELLOW}⚠️  No Pod Disruption Budgets found${NC}"
    fi
    echo
    
    # Monitoring Health Checks
    echo -e "${BLUE}📊 Monitoring Health Checks${NC}"
    echo "=========================="
    
    # Check ServiceMonitor
    if kubectl get servicemonitor -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}✅ ServiceMonitor is configured${NC}"
    else
        echo -e "${YELLOW}⚠️  No ServiceMonitor found for Prometheus${NC}"
    fi
    
    # Check if Prometheus is scraping
    if command -v curl &> /dev/null; then
        # Try to port-forward and check metrics
        kubectl port-forward -n "$NAMESPACE" svc/cicd-pipeline 8080:80 &
        local pf_pid=$!
        sleep 3
        
        if test_http_endpoint "http://localhost:8080/metrics" "Metrics"; then
            echo -e "${GREEN}✅ Metrics endpoint is accessible${NC}"
        else
            echo -e "${YELLOW}⚠️  Metrics endpoint may not be working${NC}"
        fi
        
        kill $pf_pid 2>/dev/null || true
    fi
    echo
    
    # Backup and Recovery Checks
    echo -e "${BLUE}💾 Backup and Recovery Health${NC}"
    echo "============================="
    
    # Check for backup CronJobs
    local cronjob_count=$(kubectl get cronjobs -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$cronjob_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Backup jobs are configured ($cronjob_count)${NC}"
        kubectl get cronjobs -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️  No backup jobs found${NC}"
    fi
    
    # Check persistent volumes
    local pv_count=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [ "$pv_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Persistent volumes are configured ($pv_count)${NC}"
    else
        echo -e "${YELLOW}⚠️  No persistent volumes found${NC}"
    fi
    echo
    
    # Overall Health Summary
    echo -e "${PURPLE}📋 Health Check Summary${NC}"
    echo "======================"
    
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}🎉 Overall Status: HEALTHY${NC}"
        echo -e "${GREEN}✅ All critical components are functioning properly${NC}"
    else
        echo -e "${RED}⚠️  Overall Status: ISSUES DETECTED${NC}"
        echo -e "${RED}❌ Some components require attention${NC}"
    fi
    
    echo
    echo -e "${BLUE}🔧 Recommended Actions:${NC}"
    if [ $overall_status -ne 0 ]; then
        echo "- Review failed health checks above"
        echo "- Check pod logs for detailed error information"
        echo "- Verify resource allocation and limits"
        echo "- Ensure all dependencies are properly configured"
    else
        echo "- Monitor resource usage trends"
        echo "- Review and update scaling policies if needed"
        echo "- Verify backup procedures are working"
        echo "- Schedule regular health checks"
    fi
    
    echo
    echo -e "${CYAN}📈 Next Steps:${NC}"
    echo "- Set up automated health monitoring"
    echo "- Configure alerting for critical issues"
    echo "- Implement health check automation in CI/CD"
    echo "- Document troubleshooting procedures"
    
    return $overall_status
}

# Execute main health check
main_health_check
exit_code=$?

echo
echo -e "${BLUE}Health check completed with exit code: $exit_code${NC}"
exit $exit_code
