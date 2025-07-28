#!/bin/bash

# Build and Deploy Script
set -e

echo "🚀 Starting CI/CD Pipeline Deployment"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Parse command line arguments
ENVIRONMENT=${1:-development}
BUILD_TAG=${2:-latest}

echo "📦 Building Docker image..."
docker build -t cicd-pipeline:$BUILD_TAG .

# Run tests in Docker container
echo "🧪 Running tests..."
docker run --rm cicd-pipeline:$BUILD_TAG python -m pytest tests/ -v

# Security scan
echo "🔒 Running security scan..."
docker run --rm -v $(pwd):/app cicd-pipeline:$BUILD_TAG bandit -r /app/src

if [ "$ENVIRONMENT" = "production" ]; then
    echo "🌐 Deploying to production..."
    
    # Tag for production
    docker tag cicd-pipeline:$BUILD_TAG cicd-pipeline:production
    
    # Push to registry (uncomment and configure)
    # docker push your-registry/cicd-pipeline:production
    
    echo "✅ Production deployment completed!"
    
elif [ "$ENVIRONMENT" = "staging" ]; then
    echo "🏗️ Deploying to staging..."
    
    # Start staging environment
    docker-compose -f docker-compose.yml up -d
    
    # Wait for services to be ready
    echo "⏳ Waiting for services to be ready..."
    sleep 30
    
    # Run smoke tests
    echo "💨 Running smoke tests..."
    curl -f http://localhost:8000/health || exit 1
    
    echo "✅ Staging deployment completed!"
    
else
    echo "🛠️ Starting development environment..."
    
    # Start development environment
    docker-compose up -d
    
    echo "✅ Development environment started!"
    echo "🌐 Application available at http://localhost:8000"
    echo "📊 Grafana dashboard at http://localhost:3000"
    echo "📈 Prometheus at http://localhost:9090"
fi

echo "🎉 Deployment completed successfully!"
