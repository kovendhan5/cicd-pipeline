# Enterprise CI/CD Pipeline Helm Deployment Guide

## 🎯 Overview

This guide provides comprehensive instructions for deploying the CI/CD pipeline using our production-ready Helm chart with GitOps integration and advanced monitoring.

## 📋 Prerequisites

### Required Tools

```bash
# Kubernetes CLI
kubectl version --client

# Helm 3.x
helm version

# ArgoCD CLI (optional)
argocd version

# Docker
docker --version

# Minikube (for local testing)
minikube version
```

### Cluster Requirements

- Kubernetes 1.20+
- Minimum 4GB RAM per node
- Storage class configured
- Ingress controller installed
- Cert-manager (for TLS)

## 🚀 Quick Start

### 1. Deploy with Helm (Development)

```bash
# Add dependencies
helm dependency update ./helm/cicd-pipeline

# Install the chart
helm install cicd-pipeline ./helm/cicd-pipeline \
  --create-namespace \
  --namespace cicd-pipeline \
  --values ./helm/cicd-pipeline/values.yaml

# Check deployment status
kubectl get pods -n cicd-pipeline
```

### 2. Deploy with ArgoCD (Production)

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy our GitOps applications
kubectl apply -f ./gitops/argocd-apps.yaml

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🛠️ Configuration

### Environment Values Files

Create environment-specific values files:

#### `values-dev.yaml`

```yaml
replicaCount: 1
image:
  tag: "dev"
ingress:
  hosts:
    - host: cicd-pipeline-dev.local
resources:
  limits:
    cpu: 500m
    memory: 512Mi
autoscaling:
  enabled: false
postgresql:
  auth:
    database: cicd_dev
monitoring:
  enabled: false
```

#### `values-staging.yaml`

```yaml
replicaCount: 2
image:
  tag: "staging"
ingress:
  hosts:
    - host: cicd-pipeline-staging.example.com
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
```

#### `values-prod.yaml`

```yaml
replicaCount: 3
image:
  tag: "latest"
  pullPolicy: Always
ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: cicd-pipeline.example.com
  tls:
    - secretName: cicd-pipeline-prod-tls
      hosts:
        - cicd-pipeline.example.com

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

postgresql:
  primary:
    persistence:
      size: 100Gi
    resources:
      limits:
        cpu: 1000m
        memory: 2Gi

redis:
  master:
    persistence:
      size: 10Gi
    resources:
      limits:
        cpu: 500m
        memory: 1Gi

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s

networkPolicy:
  enabled: true

podDisruptionBudget:
  enabled: true
  minAvailable: 2

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - cicd-pipeline
        topologyKey: kubernetes.io/hostname
```

### Secret Management

Create required secrets:

```bash
# Application secrets
kubectl create secret generic cicd-pipeline-secrets \
  --from-literal=database-url="postgresql://user:password@postgres:5432/cicd_pipeline" \
  --from-literal=redis-url="redis://redis:6379/0" \
  --from-literal=secret-key="your-super-secret-key" \
  --namespace cicd-pipeline

# PostgreSQL secret
kubectl create secret generic postgresql-secret \
  --from-literal=postgres-password="secure-db-password" \
  --namespace cicd-pipeline

# Redis secret
kubectl create secret generic redis-secret \
  --from-literal=redis-password="secure-redis-password" \
  --namespace cicd-pipeline
```

## 🔄 Deployment Commands

### Multi-Environment Deployment

```bash
# Development
helm upgrade --install cicd-pipeline-dev ./helm/cicd-pipeline \
  --namespace cicd-dev \
  --create-namespace \
  --values ./helm/cicd-pipeline/values.yaml \
  --values ./environments/values-dev.yaml

# Staging
helm upgrade --install cicd-pipeline-staging ./helm/cicd-pipeline \
  --namespace cicd-staging \
  --create-namespace \
  --values ./helm/cicd-pipeline/values.yaml \
  --values ./environments/values-staging.yaml

# Production
helm upgrade --install cicd-pipeline-prod ./helm/cicd-pipeline \
  --namespace cicd-production \
  --create-namespace \
  --values ./helm/cicd-pipeline/values.yaml \
  --values ./environments/values-prod.yaml
```

### Rollback Commands

```bash
# Check revision history
helm history cicd-pipeline -n cicd-pipeline

# Rollback to previous version
helm rollback cicd-pipeline -n cicd-pipeline

# Rollback to specific revision
helm rollback cicd-pipeline 2 -n cicd-pipeline
```

## 📊 Monitoring Integration

### Grafana Dashboards

The deployment includes 3 pre-configured dashboards:

1. **Application Performance** (`/monitoring/dashboards/application-performance.json`)

   - Request rates and response times
   - Error rates and active connections
   - Database and memory usage

2. **Infrastructure Overview** (`/monitoring/dashboards/infrastructure-overview.json`)

   - Pod and node status
   - CPU, memory, and disk usage
   - Network and storage I/O

3. **Deployment Analytics** (`/monitoring/dashboards/deployment-analytics.json`)
   - DORA metrics (deployment frequency, lead time, failure rate, MTTR)
   - CI/CD pipeline analytics
   - GitOps sync status

### Accessing Monitoring

```bash
# Forward Grafana port
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Forward Prometheus port
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Forward ArgoCD port
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

## 🔒 Security Features

### Network Policies

- Ingress rules for controlled access
- Egress rules for database and external API access
- DNS resolution allowed

### Pod Security

- Non-root containers
- Read-only root filesystem
- Dropped capabilities
- Security contexts

### RBAC

- Service account with minimal permissions
- Role-based access control
- Namespace isolation

## 🧪 Testing

### Deployment Verification

```bash
# Check all resources
kubectl get all -n cicd-pipeline

# Check pod logs
kubectl logs -f deployment/cicd-pipeline-app -n cicd-pipeline

# Test connectivity
kubectl run test-pod --image=curlimages/curl -it --rm --restart=Never \
  -- curl http://cicd-pipeline-service.cicd-pipeline.svc.cluster.local/health

# Check ingress
curl -H "Host: cicd-pipeline.example.com" http://your-ingress-ip/health
```

### Load Testing

```bash
# Install hey for load testing
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 http://cicd-pipeline.example.com/health
```

## 🛠️ Troubleshooting

### Common Issues

1. **Pod Not Starting**

   ```bash
   kubectl describe pod <pod-name> -n cicd-pipeline
   kubectl logs <pod-name> -n cicd-pipeline
   ```

2. **Database Connection Issues**

   ```bash
   kubectl exec -it deployment/cicd-pipeline-app -n cicd-pipeline -- env | grep DATABASE
   ```

3. **Ingress Not Working**

   ```bash
   kubectl get ingress -n cicd-pipeline
   kubectl describe ingress cicd-pipeline-ingress -n cicd-pipeline
   ```

4. **ArgoCD Sync Issues**
   ```bash
   argocd app get cicd-pipeline-app
   argocd app sync cicd-pipeline-app
   ```

### Debug Commands

```bash
# Get events
kubectl get events -n cicd-pipeline --sort-by='.metadata.creationTimestamp'

# Check resource usage
kubectl top pods -n cicd-pipeline
kubectl top nodes

# Network debugging
kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never
```

## 🔄 Updates and Maintenance

### Updating Application

```bash
# Update image tag
helm upgrade cicd-pipeline ./helm/cicd-pipeline \
  --namespace cicd-pipeline \
  --set image.tag=v2.0.0 \
  --reuse-values

# Update with new values
helm upgrade cicd-pipeline ./helm/cicd-pipeline \
  --namespace cicd-pipeline \
  --values ./helm/cicd-pipeline/values-updated.yaml
```

### Helm Dependencies

```bash
# Update dependencies
helm dependency update ./helm/cicd-pipeline

# Check outdated dependencies
helm dependency list ./helm/cicd-pipeline
```

## 🎯 Production Checklist

- [ ] TLS certificates configured
- [ ] Database backups enabled
- [ ] Monitoring alerts configured
- [ ] Resource limits set appropriately
- [ ] Network policies enabled
- [ ] Pod disruption budgets configured
- [ ] Secrets properly managed
- [ ] Multi-replica deployment
- [ ] Health checks configured
- [ ] Autoscaling enabled
- [ ] Ingress rate limiting enabled
- [ ] Security scanning completed

## 📚 Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

For support and questions, please check the troubleshooting section or contact the DevOps team.
