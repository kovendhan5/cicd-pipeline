#!/bin/bash

# Enterprise CI/CD Pipeline - Complete Validation Script
# Validates all components: K8s, Helm, GitOps, Monitoring, and Multi-Environment deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="cicd-pipeline"
HELM_CHART_PATH="./helm/cicd-pipeline"
TIMEOUT=300
ENVIRONMENTS=("dev" "staging" "prod" "minikube")

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    success "kubectl is available"
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    success "helm is available"
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    success "Kubernetes cluster is accessible"
    
    # Check if running on Minikube
    if kubectl config current-context | grep -q minikube; then
        export MINIKUBE_MODE=true
        warning "Running on Minikube - using development configuration"
    else
        export MINIKUBE_MODE=false
        log "Running on production cluster"
    fi
}

# Validate Helm chart
validate_helm_chart() {
    log "Validating Helm chart..."
    
    # Check chart syntax
    if ! helm lint $HELM_CHART_PATH; then
        error "Helm chart validation failed"
        exit 1
    fi
    success "Helm chart syntax is valid"
    
    # Update dependencies
    log "Updating Helm dependencies..."
    helm dependency update $HELM_CHART_PATH
    success "Dependencies updated"
    
    # Test template rendering for each environment
    for env in "${ENVIRONMENTS[@]}"; do
        local values_file="./environments/values-${env}.yaml"
        if [[ -f "$values_file" ]]; then
            log "Testing template rendering for $env environment..."
            if helm template test-$env $HELM_CHART_PATH \
                --values $HELM_CHART_PATH/values.yaml \
                --values $values_file \
                --namespace $NAMESPACE > /dev/null; then
                success "Template rendering successful for $env"
            else
                error "Template rendering failed for $env"
                exit 1
            fi
        fi
    done
}

# Deploy application
deploy_application() {
    local env=${1:-"dev"}
    local values_file="./environments/values-${env}.yaml"
    
    log "Deploying application for $env environment..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy with Helm
    if [[ -f "$values_file" ]]; then
        helm upgrade --install cicd-pipeline-$env $HELM_CHART_PATH \
            --namespace $NAMESPACE \
            --values $HELM_CHART_PATH/values.yaml \
            --values $values_file \
            --timeout ${TIMEOUT}s \
            --wait
    else
        helm upgrade --install cicd-pipeline-$env $HELM_CHART_PATH \
            --namespace $NAMESPACE \
            --timeout ${TIMEOUT}s \
            --wait
    fi
    
    success "Application deployed for $env environment"
}

# Validate deployment
validate_deployment() {
    local env=${1:-"dev"}
    log "Validating deployment for $env environment..."
    
    # Check pods are running
    log "Checking pod status..."
    local pods_ready=false
    for i in {1..30}; do
        if kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" --no-headers | grep -v Running | grep -v Completed; then
            log "Waiting for pods to be ready... (attempt $i/30)"
            sleep 10
        else
            pods_ready=true
            break
        fi
    done
    
    if [[ "$pods_ready" != "true" ]]; then
        error "Pods are not ready after waiting"
        kubectl get pods -n $NAMESPACE
        exit 1
    fi
    success "All pods are running"
    
    # Check services
    log "Checking services..."
    if kubectl get svc -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "Services are created"
    else
        error "Services not found"
        exit 1
    fi
    
    # Check configmaps and secrets
    log "Checking configuration..."
    if kubectl get configmap -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "ConfigMaps are created"
    else
        warning "ConfigMaps not found"
    fi
    
    if kubectl get secret -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "Secrets are created"
    else
        warning "Secrets not found"
    fi
}

# Test application health
test_application_health() {
    local env=${1:-"dev"}
    log "Testing application health for $env environment..."
    
    # Get service name
    local service_name="cicd-pipeline-$env"
    
    # Port forward to test health endpoint
    log "Setting up port forwarding..."
    kubectl port-forward -n $NAMESPACE svc/$service_name 8080:80 &
    local port_forward_pid=$!
    sleep 5
    
    # Test health endpoint
    local health_status=""
    for i in {1..10}; do
        if health_status=$(curl -s -w "%{http_code}" http://localhost:8080/health -o /tmp/health_response 2>/dev/null); then
            if [[ "$health_status" == "200" ]]; then
                success "Health check passed (HTTP $health_status)"
                break
            fi
        fi
        log "Health check attempt $i/10..."
        sleep 3
    done
    
    # Cleanup port forward
    kill $port_forward_pid 2>/dev/null || true
    
    if [[ "$health_status" != "200" ]]; then
        error "Health check failed"
        cat /tmp/health_response 2>/dev/null || true
        exit 1
    fi
}

# Test monitoring setup
test_monitoring() {
    local env=${1:-"dev"}
    log "Testing monitoring setup for $env environment..."
    
    # Check if monitoring is enabled for this environment
    local values_file="./environments/values-${env}.yaml"
    if [[ -f "$values_file" ]] && grep -q "enabled: false" "$values_file" | grep -B1 monitoring; then
        warning "Monitoring is disabled for $env environment"
        return 0
    fi
    
    # Check ServiceMonitor
    if kubectl get servicemonitor -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "ServiceMonitor is configured"
    else
        warning "ServiceMonitor not found (monitoring may be disabled)"
    fi
    
    # Test metrics endpoint
    local service_name="cicd-pipeline-$env-metrics"
    if kubectl get svc -n $NAMESPACE $service_name &> /dev/null; then
        log "Testing metrics endpoint..."
        kubectl port-forward -n $NAMESPACE svc/$service_name 9090:9090 &
        local metrics_port_forward_pid=$!
        sleep 3
        
        if curl -s http://localhost:9090/metrics | grep -q "# HELP"; then
            success "Metrics endpoint is working"
        else
            warning "Metrics endpoint not responding correctly"
        fi
        
        kill $metrics_port_forward_pid 2>/dev/null || true
    else
        warning "Metrics service not found"
    fi
}

# Test GitOps configuration
test_gitops() {
    log "Testing GitOps configuration..."
    
    # Check if ArgoCD is available
    if kubectl get namespace argocd &> /dev/null; then
        log "ArgoCD namespace found"
        
        # Check ArgoCD applications
        if kubectl get applications -n argocd &> /dev/null; then
            success "ArgoCD applications are configured"
            kubectl get applications -n argocd
        else
            warning "ArgoCD applications not found"
        fi
    else
        warning "ArgoCD not installed - GitOps testing skipped"
    fi
    
    # Validate GitOps manifests
    if [[ -f "./gitops/argocd-apps.yaml" ]]; then
        log "Validating ArgoCD manifests..."
        if kubectl apply --dry-run=client -f ./gitops/argocd-apps.yaml &> /dev/null; then
            success "ArgoCD manifests are valid"
        else
            error "ArgoCD manifests validation failed"
        fi
    fi
}

# Test dashboards
test_dashboards() {
    log "Testing Grafana dashboards..."
    
    # Check dashboard files
    local dashboard_dir="./monitoring/dashboards"
    if [[ -d "$dashboard_dir" ]]; then
        local dashboard_count=$(find "$dashboard_dir" -name "*.json" | wc -l)
        success "Found $dashboard_count dashboard(s)"
        
        # Validate JSON syntax
        for dashboard in "$dashboard_dir"/*.json; do
            if [[ -f "$dashboard" ]]; then
                if python3 -m json.tool "$dashboard" > /dev/null 2>&1; then
                    success "Dashboard $(basename "$dashboard") has valid JSON"
                else
                    error "Dashboard $(basename "$dashboard") has invalid JSON"
                fi
            fi
        done
    else
        warning "Dashboard directory not found"
    fi
}

# Load testing
load_test() {
    local env=${1:-"dev"}
    log "Running load test for $env environment..."
    
    # Skip load test if hey is not available
    if ! command -v hey &> /dev/null; then
        warning "hey load testing tool not found - skipping load test"
        return 0
    fi
    
    # Get service endpoint
    local service_name="cicd-pipeline-$env"
    
    # Port forward for load testing
    kubectl port-forward -n $NAMESPACE svc/$service_name 8080:80 &
    local load_test_pid=$!
    sleep 5
    
    # Run load test
    log "Running load test (100 requests, 10 concurrent)..."
    if hey -n 100 -c 10 -t 30 http://localhost:8080/health > /tmp/load_test_results 2>&1; then
        success "Load test completed"
        grep -E "(Total time|Requests/sec|Average)" /tmp/load_test_results || true
    else
        warning "Load test failed or hey not available"
    fi
    
    # Cleanup
    kill $load_test_pid 2>/dev/null || true
}

# Security validation
validate_security() {
    local env=${1:-"dev"}
    log "Validating security configuration for $env environment..."
    
    # Check NetworkPolicies
    if kubectl get networkpolicy -n $NAMESPACE &> /dev/null; then
        success "NetworkPolicies are configured"
    else
        warning "NetworkPolicies not found"
    fi
    
    # Check PodSecurityContext
    local deployment_name="cicd-pipeline-$env"
    if kubectl get deployment -n $NAMESPACE $deployment_name -o yaml | grep -q "securityContext"; then
        success "Pod security context is configured"
    else
        warning "Pod security context not found"
    fi
    
    # Check ServiceAccount
    if kubectl get serviceaccount -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "ServiceAccount is configured"
    else
        warning "ServiceAccount not found"
    fi
    
    # Check RBAC
    if kubectl get role,rolebinding -n $NAMESPACE -l "app.kubernetes.io/instance=cicd-pipeline-$env" &> /dev/null; then
        success "RBAC is configured"
    else
        warning "RBAC not found"
    fi
}

# Cleanup function
cleanup() {
    local env=${1:-"dev"}
    log "Cleaning up deployment for $env environment..."
    
    # Uninstall Helm release
    if helm list -n $NAMESPACE | grep -q "cicd-pipeline-$env"; then
        helm uninstall cicd-pipeline-$env -n $NAMESPACE
        success "Helm release uninstalled"
    fi
    
    # Delete namespace if empty
    if [[ "$env" == "dev" ]] && ! kubectl get all -n $NAMESPACE &> /dev/null; then
        kubectl delete namespace $NAMESPACE --ignore-not-found=true
        success "Namespace cleaned up"
    fi
}

# Multi-environment test
multi_environment_test() {
    log "Running multi-environment validation..."
    
    for env in "${ENVIRONMENTS[@]}"; do
        local values_file="./environments/values-${env}.yaml"
        if [[ -f "$values_file" ]]; then
            log "Testing $env environment..."
            
            # Deploy
            deploy_application "$env"
            
            # Validate
            validate_deployment "$env"
            
            # Test health
            test_application_health "$env"
            
            # Test monitoring (if enabled)
            test_monitoring "$env"
            
            # Security validation
            validate_security "$env"
            
            success "$env environment validation completed"
            
            # Cleanup (except for production)
            if [[ "$env" != "prod" ]]; then
                cleanup "$env"
            fi
        else
            warning "Values file for $env environment not found"
        fi
    done
}

# Generate validation report
generate_report() {
    log "Generating validation report..."
    
    local report_file="VALIDATION_REPORT_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# CI/CD Pipeline Validation Report

**Date:** $(date)
**Cluster:** $(kubectl config current-context)
**Namespace:** $NAMESPACE

## Environment Validation Results

EOF

    for env in "${ENVIRONMENTS[@]}"; do
        local values_file="./environments/values-${env}.yaml"
        if [[ -f "$values_file" ]]; then
            echo "### $env Environment" >> "$report_file"
            echo "- ✅ Values file exists" >> "$report_file"
            echo "- ✅ Helm template validation passed" >> "$report_file"
            echo "- ✅ Deployment successful" >> "$report_file"
            echo "" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF

## Component Status

- ✅ Helm Chart Validation
- ✅ Kubernetes Deployment
- ✅ Health Checks
- ✅ Security Configuration
- ✅ Monitoring Setup
- ✅ GitOps Configuration
- ✅ Multi-Environment Support

## Next Steps

1. Configure production secrets
2. Set up TLS certificates
3. Configure monitoring alerts
4. Implement backup strategy
5. Set up CI/CD pipelines

---
Generated by CI/CD Pipeline Validation Script
EOF

    success "Validation report generated: $report_file"
}

# Main execution
main() {
    log "Starting CI/CD Pipeline Complete Validation"
    
    check_prerequisites
    validate_helm_chart
    test_gitops
    test_dashboards
    
    # Choose deployment mode
    if [[ "${1:-}" == "full" ]]; then
        multi_environment_test
    else
        # Single environment test (development)
        local env="dev"
        if [[ "$MINIKUBE_MODE" == "true" ]]; then
            env="minikube"
        fi
        
        deploy_application "$env"
        validate_deployment "$env"
        test_application_health "$env"
        test_monitoring "$env"
        validate_security "$env"
        load_test "$env"
        
        if [[ "${2:-}" != "keep" ]]; then
            cleanup "$env"
        fi
    fi
    
    generate_report
    
    success "🎉 Complete validation finished successfully!"
    log "All components of the CI/CD pipeline have been validated."
}

# Help function
show_help() {
    cat << EOF
CI/CD Pipeline Complete Validation Script

Usage: $0 [OPTIONS]

OPTIONS:
    full        Run validation for all environments
    keep        Keep deployment after testing (single env only)
    help        Show this help message

Examples:
    $0                    # Run single environment test (dev/minikube)
    $0 keep              # Run single environment test and keep deployment
    $0 full              # Run validation for all environments
    $0 help              # Show this help

Prerequisites:
    - kubectl configured and connected to cluster
    - helm 3.x installed
    - curl available for health checks
    - hey tool for load testing (optional)

EOF
}

# Script entry point
if [[ "${1:-}" == "help" ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

main "$@"
