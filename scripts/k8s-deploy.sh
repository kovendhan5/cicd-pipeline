#!/bin/bash
# Enhanced Kubernetes Deployment Script for CI/CD Pipeline
set -e

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    case $1 in
        "ERROR")   echo -e "${RED}❌ $2${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $2${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $2${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  $2${NC}" ;;
        *)         echo "$2" ;;
    esac
}

NAMESPACE=${1:-cicd-pipeline}
ENVIRONMENT=${2:-production}
IMAGE_TAG=${3:-latest}

echo "🚀 Enhanced CI/CD Pipeline Kubernetes Deployment"
echo "================================================"
print_status "INFO" "Namespace: $NAMESPACE"
print_status "INFO" "Environment: $ENVIRONMENT"
print_status "INFO" "Image Tag: $IMAGE_TAG"
echo
# Pre-deployment checks
print_status "INFO" "Running pre-deployment checks..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status "ERROR" "kubectl is not installed or not in PATH"
    exit 1
fi
print_status "SUCCESS" "kubectl is available"

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    print_status "ERROR" "Cannot connect to Kubernetes cluster"
    print_status "INFO" "Please ensure your cluster is running and kubeconfig is configured"
    exit 1
fi
print_status "SUCCESS" "Connected to Kubernetes cluster"

# Show current context
CURRENT_CONTEXT=$(kubectl config current-context)
print_status "INFO" "Current context: $CURRENT_CONTEXT"

# Create namespace if it doesn't exist
echo "📦 Creating namespace if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap for database init script
echo "🗄️ Creating database initialization ConfigMap..."
kubectl create configmap postgres-init-script \
    --from-file=init-db.sql=scripts/init-db.sql \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

# Apply the complete deployment
echo "🛠️ Applying Kubernetes manifests..."
kubectl apply -f k8s/complete-deployment.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/redis -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n $NAMESPACE

# Get the status
echo "📊 Deployment status:"
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE
kubectl get ingress -n $NAMESPACE

# Get the external IP or URL
echo ""
echo "🌐 Access Information:"
if kubectl get ingress cicd-pipeline-ingress -n $NAMESPACE &> /dev/null; then
    INGRESS_HOST=$(kubectl get ingress cicd-pipeline-ingress -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}')
    echo "External URL: https://$INGRESS_HOST"
else
    echo "Service URL: kubectl port-forward -n $NAMESPACE service/cicd-pipeline-service 8080:80"
    echo "Then access: http://localhost:8080"
fi

# Show logs if there are any issues
echo ""
echo "📜 Recent logs:"
kubectl logs -n $NAMESPACE deployment/cicd-pipeline-app --tail=10 || true

echo ""
echo "✅ Deployment completed!"
echo "🔧 Useful commands:"
echo "  View logs: kubectl logs -n $NAMESPACE deployment/cicd-pipeline-app -f"
echo "  Scale app: kubectl scale deployment cicd-pipeline-app --replicas=5 -n $NAMESPACE"
echo "  Port forward: kubectl port-forward -n $NAMESPACE service/cicd-pipeline-service 8080:80"
echo "  Delete: kubectl delete namespace $NAMESPACE"
