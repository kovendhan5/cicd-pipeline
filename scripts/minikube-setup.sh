#!/bin/bash

# Minikube Setup Script for CI/CD Pipeline
set -e

echo "🚀 Setting up Minikube for CI/CD Pipeline"

if ! command -v minikube &> /dev/null; then
    echo "❌ Minikube is not installed. Please install it first:"
    echo "   https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first:"
    echo "   https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo "✅ All prerequisites are available"

# Start Minikube with specific configuration
echo "🔧 Starting Minikube cluster..."
minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=8192 \
    --disk-size=50g \
    --kubernetes-version=v1.27.3 \
    --addons=ingress,dashboard,metrics-server,registry

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

# Enable necessary addons
echo "🔌 Enabling additional addons..."
minikube addons enable ingress-dns
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Configure Docker environment to use Minikube's Docker daemon
echo "🐳 Configuring Docker environment..."
eval $(minikube docker-env)

# Create namespace for our application
echo "📦 Creating application namespace..."
kubectl create namespace cicd-pipeline --dry-run=client -o yaml | kubectl apply -f -

# Build the application image in Minikube's Docker environment
echo "🏗️ Building application image in Minikube..."
docker build -t cicd-pipeline:latest .

# Create ConfigMap for database initialization
echo "📄 Creating database initialization ConfigMap..."
kubectl create configmap postgres-init-script \
    --from-file=init-db.sql=scripts/init-db.sql \
    --namespace=cicd-pipeline \
    --dry-run=client -o yaml | kubectl apply -f -

# Create secrets (you should replace these with actual secure values)
echo "🔐 Creating application secrets..."
kubectl create secret generic cicd-pipeline-secrets \
    --from-literal=SECRET_KEY='your-super-secret-key-change-this' \
    --from-literal=DB_PASSWORD='password123' \
    --from-literal=REDIS_PASSWORD='redis123' \
    --from-literal=WEBHOOK_SECRET='webhook-secret-123' \
    --namespace=cicd-pipeline \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy the application
echo "🚀 Deploying application to Minikube..."
kubectl apply -f k8s/minikube-deployment.yaml

# Wait for deployments to be ready
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n cicd-pipeline
kubectl wait --for=condition=available --timeout=300s deployment/redis -n cicd-pipeline
kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n cicd-pipeline

# Get service information
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n cicd-pipeline
echo ""
kubectl get services -n cicd-pipeline
echo ""

# Get Minikube IP and service URLs
MINIKUBE_IP=$(minikube ip)
echo "🌐 Access Information:"
echo "Minikube IP: $MINIKUBE_IP"
echo ""

# Get service URLs
API_URL=$(minikube service cicd-pipeline-service --url -n cicd-pipeline)
echo "API Service: $API_URL"
echo "API Docs: $API_URL/docs"
echo "Health Check: $API_URL/health"
echo ""

# Dashboard access
echo "📊 Kubernetes Dashboard:"
echo "Run: minikube dashboard"
echo ""

# Ingress information
if kubectl get ingress -n cicd-pipeline &> /dev/null; then
    echo "🌍 Ingress URLs (add to /etc/hosts):"
    echo "$MINIKUBE_IP cicd-pipeline.local"
    echo "Then access: http://cicd-pipeline.local"
    echo ""
fi

echo "🎉 Minikube setup completed successfully!"
echo ""
echo "🔧 Useful commands:"
echo "  View logs: kubectl logs -n cicd-pipeline deployment/cicd-pipeline-app -f"
echo "  Scale app: kubectl scale deployment cicd-pipeline-app --replicas=3 -n cicd-pipeline"
echo "  Port forward: kubectl port-forward -n cicd-pipeline service/cicd-pipeline-service 8080:80"
echo "  Access dashboard: minikube dashboard"
echo "  Stop cluster: minikube stop"
echo "  Delete cluster: minikube delete"
echo "  SSH into minikube: minikube ssh"
echo ""
echo "🐳 Docker environment:"
echo "  Use Minikube Docker: eval \$(minikube docker-env)"
echo "  Use system Docker: eval \$(minikube docker-env -u)"
