# 🚀 CI/CD Pipeline - Production Deployment Kit

## 🎯 Overview

This deployment kit provides everything needed to deploy the enterprise CI/CD pipeline to production environments with enterprise-grade monitoring, security, and high availability.

## 🏗️ Cloud Infrastructure Setup

### AWS EKS Deployment

#### 1. Terraform Infrastructure

```bash
# Navigate to terraform directory
cd terraform/

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan -var-file="environments/production.tfvars"

# Apply infrastructure
terraform apply -var-file="environments/production.tfvars"

# Get kubeconfig
aws eks update-kubeconfig --region us-west-2 --name cicd-pipeline-eks
```

#### 2. Install Required Components

```bash
# Install nginx-ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Install cert-manager for TLS
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

# Install ArgoCD for GitOps
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace
```

## 🚀 Production Deployment

### Method 1: Direct Helm Deployment

```bash
# Deploy to production
helm upgrade --install cicd-pipeline ./helm/cicd-pipeline \
  --namespace cicd-production \
  --create-namespace \
  --values ./environments/values-prod.yaml \
  --set image.tag=v1.0.0 \
  --set ingress.hosts[0].host=api.yourcompany.com \
  --set ingress.tls[0].hosts[0]=api.yourcompany.com \
  --timeout 600s \
  --wait

# Verify deployment
kubectl get pods -n cicd-production
kubectl get services -n cicd-production
kubectl get ingress -n cicd-production
```

### Method 2: GitOps with ArgoCD

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Deploy GitOps applications
kubectl apply -f ./gitops/argocd-apps.yaml

# Sync applications
argocd app sync cicd-pipeline-app
argocd app sync monitoring-stack
```

## 🔒 Production Security Configuration

### 1. Create Production Secrets

```bash
# Database secrets
kubectl create secret generic postgresql-prod-secret \
  --from-literal=postgres-password="$(openssl rand -base64 32)" \
  --namespace cicd-production

# Redis secrets
kubectl create secret generic redis-prod-secret \
  --from-literal=redis-password="$(openssl rand -base64 32)" \
  --namespace cicd-production

# Application secrets
kubectl create secret generic cicd-pipeline-secrets \
  --from-literal=secret-key="$(openssl rand -base64 32)" \
  --from-literal=jwt-secret="$(openssl rand -base64 32)" \
  --from-literal=database-url="postgresql://prod_user:$(kubectl get secret postgresql-prod-secret -o jsonpath='{.data.postgres-password}' | base64 -d)@cicd-pipeline-postgresql:5432/cicd_production" \
  --from-literal=redis-url="redis://:$(kubectl get secret redis-prod-secret -o jsonpath='{.data.redis-password}' | base64 -d)@cicd-pipeline-redis:6379/0" \
  --namespace cicd-production
```

### 2. Configure TLS Certificates

```yaml
# cert-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourcompany.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
```

```bash
# Apply certificate issuer
kubectl apply -f cert-issuer.yaml
```

### 3. Configure Monitoring

```bash
# Apply ServiceMonitor for Prometheus
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cicd-pipeline-monitor
  namespace: cicd-production
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
kubectl create configmap grafana-dashboards \
  --from-file=./monitoring/dashboards/ \
  --namespace monitoring
```

## 📊 Production Monitoring Setup

### 1. Access Monitoring Stack

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

### 2. Configure Alerts

```yaml
# production-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cicd-pipeline-alerts
  namespace: cicd-production
spec:
  groups:
    - name: cicd-pipeline.rules
      rules:
        - alert: PipelineHighErrorRate
          expr: rate(fastapi_requests_total{status=~"5.."}[5m]) > 0.05
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "High error rate in CI/CD Pipeline"
            description: "Error rate is {{ $value | humanizePercentage }}"

        - alert: PipelineHighResponseTime
          expr: histogram_quantile(0.95, rate(fastapi_request_duration_seconds_bucket[5m])) > 2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High response time"
            description: "95th percentile response time is {{ $value }}s"

        - alert: PipelineDown
          expr: up{job="cicd-pipeline"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "CI/CD Pipeline is down"
            description: "Pipeline has been down for more than 1 minute"
```

### 3. Configure Slack Notifications

```yaml
# alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-prometheus-kube-prometheus-alertmanager
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yml: |
    global:
      slack_api_url: 'YOUR_SLACK_WEBHOOK_URL'

    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'

    receivers:
    - name: 'web.hook'
      slack_configs:
      - channel: '#alerts'
        title: 'CI/CD Pipeline Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

## 🔄 Production Operations

### 1. Deployment Pipeline

```bash
# Production deployment script
#!/bin/bash
set -e

VERSION=${1:-latest}
NAMESPACE=cicd-production

echo "Deploying CI/CD Pipeline v$VERSION to production..."

# Backup current deployment
kubectl get deployment cicd-pipeline -n $NAMESPACE -o yaml > backup-$(date +%Y%m%d-%H%M%S).yaml

# Update image tag
helm upgrade cicd-pipeline ./helm/cicd-pipeline \
  --namespace $NAMESPACE \
  --set image.tag=$VERSION \
  --reuse-values \
  --wait \
  --timeout 600s

# Verify deployment
kubectl rollout status deployment/cicd-pipeline -n $NAMESPACE

# Run health checks
kubectl run health-check --image=curlimages/curl -it --rm --restart=Never \
  -- curl -f http://cicd-pipeline.cicd-production.svc.cluster.local/health

echo "Deployment completed successfully!"
```

### 2. Rollback Strategy

```bash
# Rollback script
#!/bin/bash
NAMESPACE=cicd-production

echo "Rolling back CI/CD Pipeline..."

# Check deployment history
helm history cicd-pipeline -n $NAMESPACE

# Rollback to previous version
helm rollback cicd-pipeline -n $NAMESPACE

# Verify rollback
kubectl rollout status deployment/cicd-pipeline -n $NAMESPACE

echo "Rollback completed!"
```

### 3. Backup & Recovery

```bash
# Database backup
kubectl exec -it deployment/cicd-pipeline-postgresql -n $NAMESPACE -- \
  pg_dump -U prod_user cicd_production > backup-$(date +%Y%m%d).sql

# Redis backup
kubectl exec -it deployment/cicd-pipeline-redis -n $NAMESPACE -- \
  redis-cli BGSAVE

# Persistent volume backup
kubectl get pv -o yaml > pv-backup-$(date +%Y%m%d).yaml
```

## 🔧 Troubleshooting

### 1. Common Issues

```bash
# Check pod logs
kubectl logs -f deployment/cicd-pipeline -n cicd-production

# Check events
kubectl get events -n cicd-production --sort-by='.metadata.creationTimestamp'

# Check resource usage
kubectl top pods -n cicd-production
kubectl top nodes

# Debug networking
kubectl run netshoot --image=nicolaka/netshoot -it --rm --restart=Never
```

### 2. Performance Optimization

```bash
# Check HPA status
kubectl get hpa -n cicd-production

# Check resource requests vs usage
kubectl describe pod -l app.kubernetes.io/name=cicd-pipeline -n cicd-production

# Check database performance
kubectl exec -it deployment/cicd-pipeline-postgresql -n cicd-production -- \
  psql -U prod_user -d cicd_production -c "SELECT * FROM pg_stat_activity;"
```

## 📈 Scaling Operations

### 1. Horizontal Scaling

```bash
# Manual scaling
kubectl scale deployment cicd-pipeline --replicas=5 -n cicd-production

# Update HPA
kubectl patch hpa cicd-pipeline -n cicd-production -p '{"spec":{"maxReplicas":20}}'
```

### 2. Vertical Scaling

```bash
# Update resource limits
helm upgrade cicd-pipeline ./helm/cicd-pipeline \
  --namespace cicd-production \
  --set resources.requests.cpu=2000m \
  --set resources.requests.memory=2Gi \
  --set resources.limits.cpu=4000m \
  --set resources.limits.memory=4Gi \
  --reuse-values
```

## 🛡️ Security Maintenance

### 1. Regular Security Updates

```bash
# Update base images
docker pull python:3.11-slim
docker build -t ghcr.io/kovendhan5/cicd-pipeline:v1.1.0 .
docker push ghcr.io/kovendhan5/cicd-pipeline:v1.1.0

# Update deployment
helm upgrade cicd-pipeline ./helm/cicd-pipeline \
  --namespace cicd-production \
  --set image.tag=v1.1.0 \
  --reuse-values
```

### 2. Certificate Rotation

```bash
# Check certificate expiry
kubectl get certificate -n cicd-production

# Force certificate renewal
kubectl delete secret cicd-pipeline-prod-tls -n cicd-production
```

## 📋 Production Checklist

### Pre-Deployment

- [ ] Infrastructure provisioned (EKS, RDS, Redis)
- [ ] DNS configured
- [ ] TLS certificates configured
- [ ] Secrets created and secured
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Alerts configured

### Post-Deployment

- [ ] Health checks passing
- [ ] Monitoring dashboards accessible
- [ ] Alerts functioning
- [ ] Performance baseline established
- [ ] Backup tested
- [ ] Rollback tested
- [ ] Documentation updated

### Ongoing Operations

- [ ] Regular security updates
- [ ] Performance monitoring
- [ ] Capacity planning
- [ ] Disaster recovery testing
- [ ] Compliance auditing

---

## 🎯 Support & Maintenance

For ongoing support:

1. Monitor Grafana dashboards
2. Check AlertManager for alerts
3. Review application logs regularly
4. Perform regular backups
5. Update dependencies monthly
6. Test disaster recovery quarterly

This production deployment kit ensures your CI/CD pipeline runs reliably at enterprise scale with comprehensive monitoring, security, and operational procedures.
