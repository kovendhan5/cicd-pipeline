# Complete Deployment Guide

## 🚀 Overview

This guide walks you through deploying your CI/CD pipeline from local development to production environments.

## 📋 Prerequisites

### Required Secrets (GitHub Repository Settings)

Configure these in GitHub Settings > Secrets and variables > Actions:

```
REGISTRY_USERNAME     # Docker registry username
REGISTRY_PASSWORD     # Docker registry password/token
KUBECONFIG_DEV       # Base64 encoded kubeconfig for dev cluster
KUBECONFIG_STAGING   # Base64 encoded kubeconfig for staging cluster
KUBECONFIG_PROD      # Base64 encoded kubeconfig for production cluster
SLACK_WEBHOOK        # Slack webhook URL for notifications
TRIVY_TOKEN          # Trivy security scanner token (optional)
```

### Cloud Provider Secrets (for Terraform)

```
# AWS
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

# Azure
ARM_CLIENT_ID
ARM_CLIENT_SECRET
ARM_SUBSCRIPTION_ID
ARM_TENANT_ID

# GCP
GCP_SERVICE_ACCOUNT_KEY
```

## 🐳 Container Registry Setup

### 1. Docker Hub

```bash
# Login to Docker Hub
docker login
# Or use token
echo $DOCKER_TOKEN | docker login --username $DOCKER_USERNAME --password-stdin
```

### 2. GitHub Container Registry

```bash
# Create personal access token with packages:write scope
echo $GITHUB_TOKEN | docker login ghcr.io --username $GITHUB_USERNAME --password-stdin
```

### 3. AWS ECR

```bash
# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

## ☸️ Kubernetes Cluster Setup

### Local Development (Minikube)

```bash
# Start Minikube
minikube start --driver=docker --cpus=4 --memory=8192

# Enable ingress
minikube addons enable ingress

# Get kubeconfig
kubectl config view --raw --minify > minikube-config.yaml
```

### Cloud Clusters

#### AWS EKS

```bash
# Create cluster
eksctl create cluster --name cicd-pipeline --region us-east-1 --nodes 3

# Get kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cicd-pipeline
```

#### Azure AKS

```bash
# Create cluster
az aks create --resource-group myResourceGroup --name cicd-pipeline --node-count 3 --enable-addons monitoring --generate-ssh-keys

# Get kubeconfig
az aks get-credentials --resource-group myResourceGroup --name cicd-pipeline
```

#### Google GKE

```bash
# Create cluster
gcloud container clusters create cicd-pipeline --num-nodes=3 --zone=us-central1-a

# Get kubeconfig
gcloud container clusters get-credentials cicd-pipeline --zone=us-central1-a
```

## 🔐 Security Configuration

### 1. Encode Kubeconfig for GitHub Secrets

```bash
# Encode kubeconfig
cat ~/.kube/config | base64 -w 0

# Or for specific context
kubectl config view --raw --minify --context=dev-context | base64 -w 0
```

### 2. Container Security Scanning

The pipeline includes Trivy security scanning. Configure:

```yaml
# In GitHub Secrets
TRIVY_TOKEN: your-trivy-token
```

### 3. Network Policies

Apply network policies for production:

```bash
kubectl apply -f k8s/network-policies.yaml
```

## 🔄 Deployment Workflows

### 1. Automated CI/CD Pipeline

Triggers automatically on:

- Push to `main`, `develop`, `feature/*`
- Pull requests
- Manual workflow dispatch

### 2. Manual Deployment

Use the multi-environment deployment workflow:

```yaml
# Trigger manually from GitHub Actions
# Select environment: dev, staging, prod
# Specify image tag: latest, v1.2.3, commit-sha
```

### 3. Environment-Specific Deployments

#### Development

- Automatic deployment on merge to `develop`
- Basic resource limits
- Debug logging enabled

#### Staging

- Manual approval required
- Production-like resources
- Performance testing enabled

#### Production

- Manual approval required
- Full resource allocation
- Security scanning required
- Rollback capability

## 📊 Monitoring Setup

### 1. Prometheus & Grafana

```bash
# Deploy monitoring stack
kubectl apply -f k8s/monitoring.yaml

# Access Grafana
kubectl port-forward svc/grafana 3000:3000
# Default: admin/admin
```

### 2. Application Metrics

The FastAPI app exposes metrics at `/metrics`:

```yaml
- Request count
- Request duration
- Error rates
- Database connections
```

### 3. Alerts Configuration

Configure alerts in `k8s/monitoring.yaml`:

- High error rate
- High response time
- Pod restarts
- Resource usage

## 🔧 Troubleshooting

### Common Issues

#### 1. Image Pull Errors

```bash
# Check registry credentials
kubectl get secret regcred -o yaml

# Recreate secret
kubectl delete secret regcred
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN
```

#### 2. Network Issues

```bash
# Check network connectivity
kubectl run debug --image=busybox --rm -it -- nslookup kubernetes.default

# Check ingress
kubectl get ingress
kubectl describe ingress fastapi-ingress
```

#### 3. Database Connection

```bash
# Check database pods
kubectl get pods -l app=postgres
kubectl logs -l app=postgres

# Test connection
kubectl exec -it deployment/fastapi-app -- python -c "from src.database import engine; print(engine.execute('SELECT 1').scalar())"
```

## 🚀 Deployment Commands

### Local Development

```bash
# Build and run locally
docker-compose up --build

# Run tests
docker-compose -f docker-compose.test.yml up --build

# Clean up
docker-compose down -v
```

### Kubernetes Deployment

```bash
# Deploy to development
kubectl apply -f k8s/minikube-deployment.yaml

# Deploy to staging/production
kubectl apply -f k8s/deployment.yaml

# Check deployment status
kubectl rollout status deployment/fastapi-app
kubectl get pods -l app=fastapi-app
```

### Using the CLI

```bash
# Check environment
python cli.py check-env

# Deploy to environment
python cli.py deploy --env dev
python cli.py deploy --env staging --approve
python cli.py deploy --env prod --approve

# Check deployment status
python cli.py status --env prod

# Scale deployment
python cli.py scale --env prod --replicas 5

# Rollback deployment
python cli.py rollback --env prod
```

## 📈 Performance Optimization

### 1. Resource Tuning

```yaml
# Adjust in k8s/deployment.yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 2. Horizontal Pod Autoscaling

```bash
# Enable HPA
kubectl autoscale deployment fastapi-app --cpu-percent=70 --min=2 --max=10

# Check HPA status
kubectl get hpa
```

### 3. Database Optimization

```yaml
# PostgreSQL tuning in docker-compose.yml
environment:
  - POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements
  - POSTGRES_MAX_CONNECTIONS=100
  - POSTGRES_SHARED_BUFFERS=256MB
```

## 🔄 Backup & Recovery

### 1. Database Backup

```bash
# Create backup
kubectl exec deployment/postgres -- pg_dump -U postgres fastapi_db > backup.sql

# Restore backup
kubectl exec -i deployment/postgres -- psql -U postgres fastapi_db < backup.sql
```

### 2. Configuration Backup

```bash
# Backup all configs
kubectl get all,cm,secret -o yaml > cluster-backup.yaml

# Restore configs
kubectl apply -f cluster-backup.yaml
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Prometheus Monitoring](https://prometheus.io/docs/)

## 🎯 Next Steps

1. Configure GitHub secrets
2. Set up cloud clusters
3. Test deployment workflows
4. Configure monitoring
5. Set up alerting
6. Implement backup strategy
7. Train team on deployment process
