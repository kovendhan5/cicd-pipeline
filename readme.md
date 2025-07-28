# CI/CD Pipeline Project

A comprehensive CI/CD pipeline implementation with FastAPI, Docker, and multiple deployment strategies.

## 🚀 Features

- **Modern Python Stack**: FastAPI, Pydantic, SQLAlchemy
- **AI/ML Ready**: Pre-configured with TensorFlow, PyTorch, scikit-learn
- **Containerized**: Docker and Docker Compose setup
- **CI/CD Pipelines**: GitHub Actions and GitLab CI configurations
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **Code Quality**: Black, isort, flake8, mypy, bandit
- **Testing**: pytest with coverage reporting
- **Documentation**: API docs with OpenAPI/Swagger

## 📋 Prerequisites

- Docker and Docker Compose
- Python 3.9+ (for local development)
- Git

## 🛠️ Quick Start

### Using Docker (Recommended)

```bash
# Clone the repository
git clone <your-repo-url>
cd cicd-pipeline

# Start the development environment
docker-compose up -d

# Access the application
# API: http://localhost:8000
# API Docs: http://localhost:8000/docs
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

### Local Development

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Run the application
python -m src.main

# Run tests
pytest

# Run code quality checks
black .
isort .
flake8 .
mypy .
```

## 🏗️ Project Structure

```
cicd-pipeline/
├── .github/workflows/       # GitHub Actions CI/CD
├── .gitlab-ci.yml          # GitLab CI configuration
├── src/                    # Application source code
├── tests/                  # Test files
├── scripts/                # Deployment and utility scripts
├── k8s/                    # Kubernetes manifests
├── nginx/                  # Nginx configuration
├── monitoring/             # Prometheus and Grafana configs
├── docker-compose.yml      # Multi-service setup
├── Dockerfile             # Container definition
├── requirements*.txt      # Python dependencies
└── pyproject.toml         # Project configuration
```

## 🔄 CI/CD Pipeline

### GitHub Actions

The pipeline includes:

- **Code Quality**: Black, isort, flake8, mypy
- **Testing**: pytest with coverage across Python 3.8-3.10
- **Security**: Bandit and Safety scans
- **Build**: Docker image building and pushing
- **Deploy**: Staging and production deployments

### GitLab CI

Similar pipeline structure with:

- Parallel testing across Python versions
- Docker image building
- Environment-specific deployments
- Manual production deployment approval

## 🐳 Docker

### Single Service

```bash
# Build
docker build -t cicd-pipeline .

# Run
docker run -p 8000:8000 cicd-pipeline
```

### Multi-Service with Docker Compose

```bash
# Development
docker-compose up -d

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## ☸️ Kubernetes Deployment

```bash
# Apply manifests
kubectl apply -f k8s/

# Check deployment
kubectl get pods
kubectl get services
```

## 📊 Monitoring

### Prometheus Metrics

- Application metrics: `/metrics`
- Request counts and latencies
- Custom business metrics

### Grafana Dashboards

- Application performance
- Infrastructure monitoring
- Custom alerts

## 🧪 Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=html

# Run specific test file
pytest tests/test_main.py

# Run with specific markers
pytest -m "not slow"
```

## 🔒 Security

### Security Scanning

- **Bandit**: Python security linter
- **Safety**: Dependency vulnerability scanner
- **Docker**: Container security scanning

### Security Headers

- Nginx configuration includes security headers
- Rate limiting and access controls

## 🌍 Environment Configuration

### Development

```bash
# Using Docker Compose
docker-compose up -d

# Using deploy script (Linux/Mac)
./scripts/deploy.sh development

# Using deploy script (Windows)
scripts\deploy.bat development
```

### Staging

```bash
# Linux/Mac
./scripts/deploy.sh staging

# Windows
scripts\deploy.bat staging
```

### Production

```bash
# Linux/Mac
./scripts/deploy.sh production

# Windows
scripts\deploy.bat production
```

## 📝 API Documentation

Once running, visit:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

## 🔧 Configuration

### Environment Variables

- `ENV`: Environment name (development/staging/production)
- `DEBUG`: Debug mode (true/false)
- `DATABASE_URL`: Database connection string
- `REDIS_URL`: Redis connection string

### Secrets Management

For production deployments:

- Use Kubernetes secrets
- Azure Key Vault / AWS Secrets Manager
- HashiCorp Vault

## 📈 Performance

### Optimization Features

- Async/await throughout
- Connection pooling
- Caching with Redis
- Nginx reverse proxy
- Gzip compression

### Monitoring

- Prometheus metrics collection
- Grafana visualization
- Health check endpoints
- Structured logging

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Run tests and linting
5. Submit a pull request

### Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit
pre-commit install

# Run manually
pre-commit run --all-files
```

## 🆘 Troubleshooting

### Common Issues

1. **Docker not starting**: Check Docker Desktop is running
2. **Port conflicts**: Ensure ports 8000, 3000, 9090 are available
3. **Permission errors**: Check file permissions for scripts

### Getting Help

- Check the logs: `docker-compose logs`
- Health check: `curl http://localhost:8000/health`
- Container status: `docker ps`

## 🗺️ Roadmap

- [ ] Helm charts for Kubernetes
- [ ] Terraform infrastructure as code
- [ ] Advanced ML pipeline integration
- [ ] Multi-cloud deployment support
- [ ] Enhanced security scanning
- [ ] Performance testing integration
