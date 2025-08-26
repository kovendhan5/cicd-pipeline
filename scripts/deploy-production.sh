#!/bin/bash

# 🚀 CI/CD Pipeline - Production Deployment Script
# Automated production deployment with comprehensive validation and rollback capabilities

set -e

# Configuration
NAMESPACE=${NAMESPACE:-"cicd-production"}
CHART_PATH="./helm/cicd-pipeline"
VALUES_FILE="./environments/values-prod.yaml"
IMAGE_TAG=${IMAGE_TAG:-"latest"}
DOMAIN=${DOMAIN:-"api.yourcompany.com"}
TIMEOUT=${TIMEOUT:-"600s"}
DRY_RUN=${DRY_RUN:-"false"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    exit 1
}

# Help function
show_help() {
    cat << EOF
🚀 CI/CD Pipeline Production Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    --namespace NAMESPACE    Target namespace (default: cicd-production)
    --tag TAG               Docker image tag (default: latest)
    --domain DOMAIN         Application domain (default: api.yourcompany.com)
    --dry-run              Perform a dry run without making changes
    --rollback             Rollback to previous version
    --backup               Create backup before deployment
    --help                 Show this help message

EXAMPLES:
    $0                                          # Deploy with defaults
    $0 --tag v1.2.0 --domain api.myapp.com    # Deploy specific version
    $0 --dry-run                               # Test deployment
    $0 --rollback                              # Rollback deployment
    $0 --backup --tag v1.2.0                  # Backup and deploy

ENVIRONMENT VARIABLES:
    NAMESPACE        Target Kubernetes namespace
    IMAGE_TAG        Docker image tag to deploy
    DOMAIN          Application domain name
    TIMEOUT         Helm timeout (default: 600s)
    DRY_RUN         Set to 'true' for dry run

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --rollback)
            ROLLBACK="true"
            shift
            ;;
        --backup)
            BACKUP="true"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Pre-flight checks
preflight_checks() {
    log "Running pre-flight checks..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
    fi
    
    # Check chart exists
    if [[ ! -f "$CHART_PATH/Chart.yaml" ]]; then
        error "Helm chart not found at $CHART_PATH"
    fi
    
    # Check values file exists
    if [[ ! -f "$VALUES_FILE" ]]; then
        error "Values file not found at $VALUES_FILE"
    fi
    
    success "Pre-flight checks passed"
}

# Create namespace if it doesn't exist
create_namespace() {
    log "Checking namespace $NAMESPACE..."
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log "Creating namespace $NAMESPACE..."
        if [[ "$DRY_RUN" != "true" ]]; then
            kubectl create namespace $NAMESPACE
        fi
        success "Namespace $NAMESPACE created"
    else
        success "Namespace $NAMESPACE already exists"
    fi
}

# Generate production secrets
generate_secrets() {
    log "Checking production secrets..."
    
    # Check if secrets already exist
    if kubectl get secret cicd-pipeline-secrets -n $NAMESPACE &> /dev/null; then
        warning "Secrets already exist in namespace $NAMESPACE"
        return 0
    fi
    
    log "Generating production secrets..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Generate secure passwords
        DB_PASSWORD=$(openssl rand -base64 32)
        REDIS_PASSWORD=$(openssl rand -base64 32)
        SECRET_KEY=$(openssl rand -base64 32)
        JWT_SECRET=$(openssl rand -base64 32)
        
        # Create PostgreSQL secret
        kubectl create secret generic postgresql-prod-secret \
            --from-literal=postgres-password="$DB_PASSWORD" \
            --namespace $NAMESPACE
        
        # Create Redis secret
        kubectl create secret generic redis-prod-secret \
            --from-literal=redis-password="$REDIS_PASSWORD" \
            --namespace $NAMESPACE
        
        # Create application secrets
        kubectl create secret generic cicd-pipeline-secrets \
            --from-literal=secret-key="$SECRET_KEY" \
            --from-literal=jwt-secret="$JWT_SECRET" \
            --from-literal=database-url="postgresql://prod_user:$DB_PASSWORD@cicd-pipeline-postgresql:5432/cicd_production" \
            --from-literal=redis-url="redis://:$REDIS_PASSWORD@cicd-pipeline-redis:6379/0" \
            --namespace $NAMESPACE
    fi
    
    success "Production secrets generated"
}

# Backup current deployment
backup_deployment() {
    if [[ "$BACKUP" != "true" ]]; then
        return 0
    fi
    
    log "Creating deployment backup..."
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Helm release
    if helm list -n $NAMESPACE | grep -q cicd-pipeline; then
        helm get values cicd-pipeline -n $NAMESPACE > "$backup_dir/helm-values.yaml"
        helm get manifest cicd-pipeline -n $NAMESPACE > "$backup_dir/manifests.yaml"
        success "Helm release backed up to $backup_dir"
    fi
    
    # Backup database
    if kubectl get deployment cicd-pipeline-postgresql -n $NAMESPACE &> /dev/null; then
        log "Creating database backup..."
        kubectl exec -n $NAMESPACE deployment/cicd-pipeline-postgresql -- \
            pg_dump -U prod_user cicd_production > "$backup_dir/database-backup.sql" 2>/dev/null || \
            warning "Database backup failed (database may not be ready)"
    fi
    
    # Backup persistent volumes
    kubectl get pv,pvc -n $NAMESPACE -o yaml > "$backup_dir/volumes.yaml" 2>/dev/null || true
    
    success "Backup created in $backup_dir"
}

# Rollback deployment
rollback_deployment() {
    if [[ "$ROLLBACK" != "true" ]]; then
        return 0
    fi
    
    log "Rolling back deployment..."
    
    # Check if release exists
    if ! helm list -n $NAMESPACE | grep -q cicd-pipeline; then
        error "No Helm release found to rollback"
    fi
    
    # Show rollback history
    log "Deployment history:"
    helm history cicd-pipeline -n $NAMESPACE
    
    # Perform rollback
    if [[ "$DRY_RUN" != "true" ]]; then
        helm rollback cicd-pipeline -n $NAMESPACE
        
        # Wait for rollback to complete
        kubectl rollout status deployment/cicd-pipeline -n $NAMESPACE --timeout=$TIMEOUT
    fi
    
    success "Rollback completed"
    exit 0
}

# Deploy application
deploy_application() {
    log "Deploying CI/CD Pipeline to production..."
    
    # Update Helm dependencies
    log "Updating Helm dependencies..."
    helm dependency update $CHART_PATH
    
    # Prepare Helm command
    local helm_cmd="helm upgrade --install cicd-pipeline $CHART_PATH"
    helm_cmd="$helm_cmd --namespace $NAMESPACE"
    helm_cmd="$helm_cmd --values $VALUES_FILE"
    helm_cmd="$helm_cmd --set image.tag=$IMAGE_TAG"
    helm_cmd="$helm_cmd --set ingress.hosts[0].host=$DOMAIN"
    helm_cmd="$helm_cmd --set ingress.tls[0].hosts[0]=$DOMAIN"
    helm_cmd="$helm_cmd --timeout $TIMEOUT"
    helm_cmd="$helm_cmd --wait"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run"
        log "DRY RUN: $helm_cmd"
    fi
    
    # Execute deployment
    eval $helm_cmd
    
    if [[ "$DRY_RUN" == "true" ]]; then
        success "Dry run completed successfully"
    else
        success "Application deployed successfully"
    fi
}

# Validate deployment
validate_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "Validating deployment..."
    
    # Check pod status
    log "Checking pod status..."
    kubectl get pods -n $NAMESPACE -l "app.kubernetes.io/name=cicd-pipeline"
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=cicd-pipeline" -n $NAMESPACE --timeout=300s
    
    # Check service endpoints
    log "Checking service endpoints..."
    kubectl get svc -n $NAMESPACE
    
    # Check ingress
    log "Checking ingress..."
    kubectl get ingress -n $NAMESPACE
    
    # Test health endpoint
    log "Testing health endpoint..."
    local service_name="cicd-pipeline"
    
    # Port forward for health check
    kubectl port-forward -n $NAMESPACE svc/$service_name 8080:80 &
    local port_forward_pid=$!
    sleep 5
    
    # Test health check
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
        error "Health check failed (HTTP $health_status)"
    fi
    
    success "Deployment validation completed"
}

# Setup monitoring
setup_monitoring() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "Setting up production monitoring..."
    
    # Apply ServiceMonitor for Prometheus
    kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cicd-pipeline-monitor
  namespace: $NAMESPACE
  labels:
    app: cicd-pipeline
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cicd-pipeline
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF
    
    # Import Grafana dashboards
    if [[ -d "./monitoring/dashboards" ]]; then
        kubectl create configmap grafana-dashboards \
            --from-file=./monitoring/dashboards/ \
            --namespace monitoring \
            --dry-run=client -o yaml | kubectl apply -f -
    fi
    
    success "Monitoring setup completed"
}

# Generate deployment report
generate_report() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "Generating deployment report..."
    
    local report_file="PRODUCTION_DEPLOYMENT_REPORT_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# 🚀 Production Deployment Report

**Date:** $(date)
**Namespace:** $NAMESPACE
**Image Tag:** $IMAGE_TAG
**Domain:** $DOMAIN

## Deployment Summary

- ✅ Application deployed successfully
- ✅ Health checks passing
- ✅ Monitoring configured
- ✅ Secrets generated

## Resource Status

### Pods
\`\`\`
$(kubectl get pods -n $NAMESPACE)
\`\`\`

### Services
\`\`\`
$(kubectl get svc -n $NAMESPACE)
\`\`\`

### Ingress
\`\`\`
$(kubectl get ingress -n $NAMESPACE)
\`\`\`

## Access Information

- **Application URL:** https://$DOMAIN
- **Health Check:** https://$DOMAIN/health
- **Metrics:** https://$DOMAIN/metrics
- **API Docs:** https://$DOMAIN/docs

## Monitoring

- **Grafana:** kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
- **Prometheus:** kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
- **AlertManager:** kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

## Next Steps

1. Configure DNS to point $DOMAIN to the load balancer
2. Verify TLS certificates are issued
3. Set up monitoring alerts
4. Configure backup schedules
5. Test disaster recovery procedures

---
Generated by CI/CD Pipeline Production Deployment Script
EOF

    success "Deployment report generated: $report_file"
}

# Main execution
main() {
    log "🚀 Starting CI/CD Pipeline Production Deployment"
    
    preflight_checks
    
    if [[ "$ROLLBACK" == "true" ]]; then
        rollback_deployment
        return 0
    fi
    
    create_namespace
    generate_secrets
    backup_deployment
    deploy_application
    validate_deployment
    setup_monitoring
    generate_report
    
    success "🎉 Production deployment completed successfully!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log "Application URL: https://$DOMAIN"
        log "Health Check: curl https://$DOMAIN/health"
        log "API Documentation: https://$DOMAIN/docs"
    fi
}

# Execute main function
main "$@"
