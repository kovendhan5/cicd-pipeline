# Security & Compliance Configuration

## 🔒 Container Security

### Dockerfile Security Best Practices

```dockerfile
# Use specific versions, not latest
FROM python:3.11-slim-bullseye

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install security updates
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set secure permissions
COPY --chown=appuser:appuser . /app
USER appuser

# Use read-only filesystem
VOLUME ["/tmp"]
```

### Trivy Security Scanning

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
  schedule:
    - cron: "0 2 * * *" # Daily at 2 AM

jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: "fastapi-app:latest"
          format: "sarif"
          output: "trivy-results.sarif"

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: "trivy-results.sarif"
```

## 🛡️ Kubernetes Security

### Network Policies

```yaml
# k8s/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: fastapi-network-policy
spec:
  podSelector:
    matchLabels:
      app: fastapi-app
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: nginx-ingress
      ports:
        - protocol: TCP
          port: 8000
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: postgres
      ports:
        - protocol: TCP
          port: 5432
    - to: [] # Allow DNS
      ports:
        - protocol: UDP
          port: 53
```

### Pod Security Standards

```yaml
# k8s/pod-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: fastapi-prod
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: fastapi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /app/.cache
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
```

### RBAC Configuration

```yaml
# k8s/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fastapi-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: fastapi-role
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: fastapi-binding
subjects:
  - kind: ServiceAccount
    name: fastapi-sa
roleRef:
  kind: Role
  name: fastapi-role
  apiGroup: rbac.authorization.k8s.io
```

## 🔐 Secrets Management

### External Secrets Operator

```yaml
# k8s/external-secrets.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "fastapi-role"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: fastapi-secrets
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: fastapi-secret
    creationPolicy: Owner
  data:
    - secretKey: database-url
      remoteRef:
        key: fastapi/config
        property: database_url
    - secretKey: secret-key
      remoteRef:
        key: fastapi/config
        property: secret_key
```

### Sealed Secrets

```bash
# Install sealed secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > mysealedsecret.yaml
```

## 🔍 Security Monitoring

### Falco Rules

```yaml
# falco-rules.yaml
- rule: Suspicious Network Activity
  desc: Detect suspicious network connections
  condition: >
    spawned_process and container and
    proc.name in (nc, ncat, netcat, socat, nmap)
  output: >
    Suspicious network tool launched (user=%user.name command=%proc.cmdline
    container=%container.info image=%container.image.repository)
  priority: WARNING

- rule: Unexpected File Access
  desc: Detect access to sensitive files
  condition: >
    open_read and container and
    fd.name in (/etc/passwd, /etc/shadow, /etc/hosts)
  output: >
    Sensitive file opened for reading (user=%user.name command=%proc.cmdline
    file=%fd.name container=%container.info)
  priority: ERROR
```

### Security Scanning Pipeline

```yaml
# .github/workflows/security-full.yml
name: Full Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run dependency check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: "fastapi-app"
          path: "."
          format: "JSON"

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: dependency-check-report
          path: reports/

  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog OSS
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: main
          head: HEAD

  code-security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: python

      - name: Autobuild
        uses: github/codeql-action/autobuild@v2

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2

  infrastructure-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: kubernetes,dockerfile,terraform
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload Checkov scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: checkov-results.sarif
```

## 🛡️ Application Security

### Authentication & Authorization

```python
# src/auth.py
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

SECRET_KEY = "your-secret-key"  # Use environment variable
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    # Get user from database
    user = get_user(username)
    if user is None:
        raise credentials_exception
    return user
```

### Input Validation & Sanitization

```python
# src/security.py
from pydantic import BaseModel, validator
import re
import html

class SecureInput(BaseModel):
    @validator('*', pre=True)
    def sanitize_input(cls, v):
        if isinstance(v, str):
            # Remove potential XSS
            v = html.escape(v)
            # Remove SQL injection patterns
            v = re.sub(r'[;\'"\\]', '', v)
        return v

class UserInput(SecureInput):
    name: str
    email: str

    @validator('email')
    def validate_email(cls, v):
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_regex, v):
            raise ValueError('Invalid email format')
        return v
```

### Rate Limiting

```python
# src/middleware.py
from fastapi import Request, HTTPException
from fastapi.middleware.base import BaseHTTPMiddleware
import time
from collections import defaultdict

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, calls: int = 100, period: int = 60):
        super().__init__(app)
        self.calls = calls
        self.period = period
        self.clients = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host
        now = time.time()

        # Clean old requests
        self.clients[client_ip] = [
            req_time for req_time in self.clients[client_ip]
            if now - req_time < self.period
        ]

        # Check rate limit
        if len(self.clients[client_ip]) >= self.calls:
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded"
            )

        # Record request
        self.clients[client_ip].append(now)

        response = await call_next(request)
        return response
```

## 📋 Compliance

### GDPR Compliance

```python
# src/gdpr.py
from datetime import datetime, timedelta
from sqlalchemy import Column, DateTime, Boolean

class GDPRMixin:
    """Mixin for GDPR compliance"""
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    consent_given = Column(Boolean, default=False)
    consent_date = Column(DateTime)
    data_retention_until = Column(DateTime)

    def set_consent(self, given: bool):
        self.consent_given = given
        self.consent_date = datetime.utcnow()
        if given:
            # Set retention period (e.g., 7 years)
            self.data_retention_until = datetime.utcnow() + timedelta(days=2555)

    def is_data_expired(self) -> bool:
        return (self.data_retention_until and
                datetime.utcnow() > self.data_retention_until)

    def anonymize_data(self):
        """Anonymize personal data"""
        # Implement data anonymization logic
        pass
```

### Audit Logging

```python
# src/audit.py
import logging
from functools import wraps
from fastapi import Request

audit_logger = logging.getLogger("audit")

def audit_log(action: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            request: Request = kwargs.get('request') or args[0]
            user = getattr(request.state, 'user', 'anonymous')

            audit_logger.info(
                f"Action: {action}, "
                f"User: {user}, "
                f"IP: {request.client.host}, "
                f"Timestamp: {datetime.utcnow()}"
            )

            result = await func(*args, **kwargs)
            return result
        return wrapper
    return decorator

# Usage
@audit_log("user_created")
async def create_user(user_data: dict, request: Request):
    # Create user logic
    pass
```

## 🔧 Security Tools Integration

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 22.3.0
    hooks:
      - id: black

  - repo: https://github.com/pycqa/bandit
    rev: 1.7.4
    hooks:
      - id: bandit
        args: ["-r", "src/"]

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.2.0
    hooks:
      - id: detect-secrets

  - repo: https://github.com/bridgecrewio/checkov
    rev: 2.0.1067
    hooks:
      - id: checkov
        files: \.tf$|\.yml$|\.yaml$|\.json$|Dockerfile
```

### Security Testing

```python
# tests/test_security.py
import pytest
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_sql_injection():
    """Test SQL injection protection"""
    malicious_input = "'; DROP TABLE users; --"
    response = client.post("/users/", json={"name": malicious_input})
    assert response.status_code != 500

def test_xss_protection():
    """Test XSS protection"""
    xss_payload = "<script>alert('xss')</script>"
    response = client.post("/users/", json={"name": xss_payload})
    assert "<script>" not in response.text

def test_rate_limiting():
    """Test rate limiting"""
    # Make many requests quickly
    for _ in range(105):  # Exceed rate limit
        response = client.get("/")
    assert response.status_code == 429

def test_authentication_required():
    """Test authentication is required"""
    response = client.get("/protected-endpoint")
    assert response.status_code == 401
```

This security configuration provides comprehensive protection for your CI/CD pipeline and application. Remember to:

1. Regularly update dependencies
2. Scan for vulnerabilities
3. Monitor security logs
4. Test security controls
5. Keep secrets secure
6. Follow the principle of least privilege
