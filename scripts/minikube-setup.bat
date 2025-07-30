@echo off
REM Minikube Setup Script for Windows

echo 🚀 Setting up Minikube for CI/CD Pipeline

REM Check if minikube is installed
minikube version >nul 2>&1
if errorlevel 1 (
    echo ❌ Minikube is not installed. Please install it first:
    echo    https://minikube.sigs.k8s.io/docs/start/
    exit /b 1
)

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Check if kubectl is installed
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo ❌ kubectl is not installed. Please install it first:
    echo    https://kubernetes.io/docs/tasks/tools/
    exit /b 1
)

echo ✅ All prerequisites are available

REM Start Minikube with specific configuration
echo 🔧 Starting Minikube cluster...
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=50g --kubernetes-version=v1.27.3 --addons=ingress,dashboard,metrics-server,registry

REM Wait for cluster to be ready
echo ⏳ Waiting for cluster to be ready...
kubectl wait --for=condition=ready nodes --all --timeout=300s

REM Enable necessary addons
echo 🔌 Enabling additional addons...
minikube addons enable ingress-dns
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

REM Configure Docker environment to use Minikube's Docker daemon
echo 🐳 Configuring Docker environment...
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd') do %%i

REM Create namespace for our application
echo 📦 Creating application namespace...
kubectl create namespace cicd-pipeline --dry-run=client -o yaml | kubectl apply -f -

REM Build the application image in Minikube's Docker environment
echo 🏗️ Building application image in Minikube...
docker build -t cicd-pipeline:latest .

REM Create ConfigMap for database initialization
echo 📄 Creating database initialization ConfigMap...
kubectl create configmap postgres-init-script --from-file=init-db.sql=scripts/init-db.sql --namespace=cicd-pipeline --dry-run=client -o yaml | kubectl apply -f -

REM Create secrets (you should replace these with actual secure values)
echo 🔐 Creating application secrets...
kubectl create secret generic cicd-pipeline-secrets --from-literal=SECRET_KEY=your-super-secret-key-change-this --from-literal=DB_PASSWORD=password123 --from-literal=REDIS_PASSWORD=redis123 --from-literal=WEBHOOK_SECRET=webhook-secret-123 --namespace=cicd-pipeline --dry-run=client -o yaml | kubectl apply -f -

REM Deploy the application
echo 🚀 Deploying application to Minikube...
kubectl apply -f k8s/minikube-deployment.yaml

REM Wait for deployments to be ready
echo ⏳ Waiting for deployments to be ready...
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n cicd-pipeline
kubectl wait --for=condition=available --timeout=300s deployment/redis -n cicd-pipeline
kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n cicd-pipeline

REM Get service information
echo.
echo 📊 Deployment Status:
kubectl get pods -n cicd-pipeline
echo.
kubectl get services -n cicd-pipeline
echo.

REM Get Minikube IP and service URLs
for /f "tokens=*" %%i in ('minikube ip') do set MINIKUBE_IP=%%i
echo 🌐 Access Information:
echo Minikube IP: %MINIKUBE_IP%
echo.

REM Get service URLs
for /f "tokens=*" %%i in ('minikube service cicd-pipeline-service --url -n cicd-pipeline') do set API_URL=%%i
echo API Service: %API_URL%
echo API Docs: %API_URL%/docs
echo Health Check: %API_URL%/health
echo.

REM Dashboard access
echo 📊 Kubernetes Dashboard:
echo Run: minikube dashboard
echo.

REM Ingress information
kubectl get ingress -n cicd-pipeline >nul 2>&1
if not errorlevel 1 (
    echo 🌍 Ingress URLs (add to C:\Windows\System32\drivers\etc\hosts):
    echo %MINIKUBE_IP% cicd-pipeline.local
    echo Then access: http://cicd-pipeline.local
    echo.
)

echo 🎉 Minikube setup completed successfully!
echo.
echo 🔧 Useful commands:
echo   View logs: kubectl logs -n cicd-pipeline deployment/cicd-pipeline-app -f
echo   Scale app: kubectl scale deployment cicd-pipeline-app --replicas=3 -n cicd-pipeline
echo   Port forward: kubectl port-forward -n cicd-pipeline service/cicd-pipeline-service 8080:80
echo   Access dashboard: minikube dashboard
echo   Stop cluster: minikube stop
echo   Delete cluster: minikube delete
echo   SSH into minikube: minikube ssh
echo.
echo 🐳 Docker environment:
echo   Use Minikube Docker: minikube docker-env --shell cmd
echo   Use system Docker: minikube docker-env -u --shell cmd
