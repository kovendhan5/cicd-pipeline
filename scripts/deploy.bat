@echo off
REM Windows deployment script

echo 🚀 Starting CI/CD Pipeline Deployment

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Parse command line arguments
set ENVIRONMENT=%1
if "%ENVIRONMENT%"=="" set ENVIRONMENT=development

set BUILD_TAG=%2
if "%BUILD_TAG%"=="" set BUILD_TAG=latest

echo 📦 Building Docker image...
docker build -t cicd-pipeline:%BUILD_TAG% .

REM Run tests in Docker container
echo 🧪 Running tests...
docker run --rm cicd-pipeline:%BUILD_TAG% python -m pytest tests/ -v

REM Security scan
echo 🔒 Running security scan...
docker run --rm -v %cd%:/app cicd-pipeline:%BUILD_TAG% bandit -r /app/src

if "%ENVIRONMENT%"=="production" (
    echo 🌐 Deploying to production...
    
    REM Tag for production
    docker tag cicd-pipeline:%BUILD_TAG% cicd-pipeline:production
    
    REM Push to registry (uncomment and configure)
    REM docker push your-registry/cicd-pipeline:production
    
    echo ✅ Production deployment completed!
    
) else if "%ENVIRONMENT%"=="staging" (
    echo 🏗️ Deploying to staging...
    
    REM Start staging environment
    docker-compose -f docker-compose.yml up -d
    
    REM Wait for services to be ready
    echo ⏳ Waiting for services to be ready...
    timeout /t 30 /nobreak >nul
    
    REM Run smoke tests
    echo 💨 Running smoke tests...
    curl -f http://localhost:8000/health
    if errorlevel 1 exit /b 1
    
    echo ✅ Staging deployment completed!
    
) else (
    echo 🛠️ Starting development environment...
    
    REM Start development environment
    docker-compose up -d
    
    echo ✅ Development environment started!
    echo 🌐 Application available at http://localhost:8000
    echo 📊 Grafana dashboard at http://localhost:3000
    echo 📈 Prometheus at http://localhost:9090
)

echo 🎉 Deployment completed successfully!
