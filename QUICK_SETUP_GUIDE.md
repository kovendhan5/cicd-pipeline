# 🔧 CI/CD Pipeline - Quick Setup Guide

This guide helps you quickly deploy the complete CI/CD pipeline to your environment.

## 🚀 Quick Start (5 minutes)

### 1. Prerequisites Checklist

```bash
# Check required tools
kubectl version --client
helm version
docker --version
git --version

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

### 2. Clone and Setup

```bash
git clone <your-repo-url>
cd cicd-pipeline

# Make scripts executable (Linux/macOS)
chmod +x scripts/*.sh

# Install dependencies (if needed)
helm dependency update helm/cicd-pipeline
```

### 3. Choose Your Deployment

#### Option A: Minikube (Local Development)

```bash
# Start minikube
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Deploy to minikube
helm upgrade --install cicd-pipeline helm/cicd-pipeline \
  --namespace cicd-dev --create-namespace \
  --values environments/values-minikube.yaml \
  --wait

# Access locally
minikube service cicd-pipeline -n cicd-dev
```

#### Option B: Development Environment

```bash
./scripts/deploy-production.sh \
  --namespace cicd-dev \
  --tag latest \
  --domain dev.yourcompany.com \
  --dry-run

# If dry-run looks good, run without --dry-run
```

#### Option C: Production Environment

```bash
./scripts/deploy-production.sh \
  --namespace cicd-production \
  --tag v1.0.0 \
  --domain api.yourcompany.com \
  --backup
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n <namespace>

# Check services
kubectl get svc -n <namespace>

# Test health endpoint
kubectl port-forward -n <namespace> svc/cicd-pipeline 8080:80
curl http://localhost:8080/health
```

## 🎯 Environment-Specific Configurations

### Development

- **File**: `environments/values-dev.yaml`
- **Features**: Debug mode, resource limits relaxed, local storage
- **Domain**: `dev.yourcompany.com`

### Staging

- **File**: `environments/values-staging.yaml`
- **Features**: Production-like, performance testing enabled
- **Domain**: `staging.yourcompany.com`

### Production

- **File**: `environments/values-prod.yaml`
- **Features**: High availability, security hardened, monitoring
- **Domain**: `api.yourcompany.com`

### Minikube

- **File**: `environments/values-minikube.yaml`
- **Features**: Single replica, minimal resources, NodePort services
- **Access**: Through minikube service

## 🛠️ Common Tasks

### Update Application Version

```bash
# Using Helm
helm upgrade cicd-pipeline helm/cicd-pipeline \
  --namespace <namespace> \
  --set image.tag=v1.2.0 \
  --reuse-values

# Using deployment script
./scripts/deploy-production.sh \
  --namespace <namespace> \
  --tag v1.2.0
```

### Scale Application

```bash
# Scale replicas
kubectl scale deployment cicd-pipeline \
  --replicas=5 \
  --namespace <namespace>

# Or update Helm values
helm upgrade cicd-pipeline helm/cicd-pipeline \
  --namespace <namespace> \
  --set replicaCount=5 \
  --reuse-values
```

### View Logs

```bash
# Application logs
kubectl logs -f deployment/cicd-pipeline -n <namespace>

# Database logs
kubectl logs -f deployment/cicd-pipeline-postgresql -n <namespace>

# All pods logs
kubectl logs -f -l app.kubernetes.io/name=cicd-pipeline -n <namespace>
```

### Access Services

```bash
# Port forward to application
kubectl port-forward -n <namespace> svc/cicd-pipeline 8080:80

# Port forward to database
kubectl port-forward -n <namespace> svc/cicd-pipeline-postgresql 5432:5432

# Port forward to Redis
kubectl port-forward -n <namespace> svc/cicd-pipeline-redis 6379:6379
```

## 🔍 Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace> -o wide

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace> --previous
```

#### ImagePullBackOff Error

```bash
# Check if image exists
docker pull your-registry/cicd-pipeline:latest

# Verify image pull secrets
kubectl get secrets -n <namespace>
kubectl describe secret <image-pull-secret> -n <namespace>
```

#### Service Connection Issues

```bash
# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh

# Inside test pod
nslookup cicd-pipeline.<namespace>.svc.cluster.local
wget -qO- http://cicd-pipeline.<namespace>.svc.cluster.local/health
```

#### Database Connection Issues

```bash
# Check database pod
kubectl get pods -l app.kubernetes.io/name=postgresql -n <namespace>

# Test database connection
kubectl run postgres-client --image=postgres:15 --rm -it --restart=Never \
  --env="PGPASSWORD=<password>" \
  -- psql -h cicd-pipeline-postgresql.<namespace>.svc.cluster.local \
           -U postgres -d cicd_production
```

### Performance Tuning

#### Resource Optimization

```bash
# Check resource usage
kubectl top pods -n <namespace>
kubectl top nodes

# Update resource requests/limits
helm upgrade cicd-pipeline helm/cicd-pipeline \
  --namespace <namespace> \
  --set resources.requests.memory=256Mi \
  --set resources.limits.memory=512Mi \
  --reuse-values
```

#### Database Performance

```bash
# Monitor database queries
kubectl exec -it deployment/cicd-pipeline-postgresql -n <namespace> \
  -- psql -U postgres -d cicd_production \
  -c "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

## 📊 Monitoring & Observability

### Access Monitoring Dashboards

```bash
# Port forward to Grafana (if installed)
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access Prometheus (if installed)
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

### Health Checks

```bash
# Application health
curl https://<domain>/health

# Detailed health with metrics
curl https://<domain>/health?detailed=true

# Prometheus metrics
curl https://<domain>/metrics
```

### Log Aggregation

```bash
# Stream all application logs
kubectl logs -f -l app.kubernetes.io/name=cicd-pipeline -n <namespace> --tail=100

# Filter logs by level
kubectl logs -l app.kubernetes.io/name=cicd-pipeline -n <namespace> | grep ERROR

# Export logs to file
kubectl logs -l app.kubernetes.io/name=cicd-pipeline -n <namespace> --since=1h > app-logs.txt
```

## 🔄 GitOps with ArgoCD

### Setup ArgoCD Application

```bash
# Apply ArgoCD application manifest
kubectl apply -f gitops/argocd-apps.yaml

# Check application status
kubectl get applications -n argocd

# Access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### Sync Application

```bash
# Manual sync via CLI
argocd app sync cicd-pipeline-dev
argocd app sync cicd-pipeline-staging
argocd app sync cicd-pipeline-prod

# Check sync status
argocd app get cicd-pipeline-dev
```

## 🔧 Development Workflow

### Local Development

```bash
# Build and test locally
docker build -t cicd-pipeline:dev .
docker run -p 8000:8000 cicd-pipeline:dev

# Run tests
python -m pytest tests/

# Push to development
docker tag cicd-pipeline:dev your-registry/cicd-pipeline:dev
docker push your-registry/cicd-pipeline:dev
```

### CI/CD Pipeline

```bash
# Trigger GitHub Actions
git tag v1.2.0
git push origin v1.2.0

# Check workflow status
gh run list
gh run view <run-id>
```

## 🆘 Emergency Procedures

### Rollback Deployment

```bash
# Using Helm
helm rollback cicd-pipeline -n <namespace>

# Using deployment script
./scripts/deploy-production.sh --namespace <namespace> --rollback

# Check rollback status
kubectl rollout status deployment/cicd-pipeline -n <namespace>
```

### Scale Down (Emergency)

```bash
# Scale to zero replicas
kubectl scale deployment cicd-pipeline --replicas=0 -n <namespace>

# Scale back up
kubectl scale deployment cicd-pipeline --replicas=3 -n <namespace>
```

### Backup Data

```bash
# Database backup
kubectl exec deployment/cicd-pipeline-postgresql -n <namespace> \
  -- pg_dump -U postgres cicd_production > backup.sql

# Persistent volume backup (if using cloud provider)
kubectl get pvc -n <namespace>
# Follow cloud provider's snapshot procedures
```

## 📚 Additional Resources

- **Helm Chart Documentation**: See `helm/cicd-pipeline/README.md`
- **Environment Configuration**: Check `environments/` directory
- **Monitoring Setup**: Review `monitoring/` directory
- **GitOps Configuration**: Examine `gitops/` directory
- **Production Deployment**: Read `PRODUCTION_DEPLOYMENT_KIT.md`

## 🤝 Support

1. **Check Documentation**: Review relevant MD files in the repository
2. **Validate Environment**: Run `scripts/validate-complete-pipeline.sh`
3. **Check Logs**: Use kubectl logs commands shown above
4. **Community Support**: Create GitHub issue with logs and configuration

---

**Quick Reference Commands:**

```bash
# Essential commands for daily operations
kubectl get pods -n <namespace>                    # Check pod status
kubectl logs -f deployment/cicd-pipeline -n <namespace>  # View logs
kubectl port-forward svc/cicd-pipeline 8080:80 -n <namespace>  # Local access
helm list -n <namespace>                           # List releases
kubectl get events --sort-by=.metadata.creationTimestamp -n <namespace>  # Recent events
```

This quick setup guide should get you up and running with the CI/CD pipeline in minutes! 🚀
