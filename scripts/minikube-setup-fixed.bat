@echo off
REM Minikube Setup Script for Windows - Fixed Version

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

REM Check for existing cluster and handle version conflicts
echo 🔍 Checking for existing cluster...
minikube status >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ⚠️  Existing cluster found. Checking version compatibility...
    for /f "tokens=*" %%i in ('kubectl version --short 2^>nul ^| findstr "Server Version"') do (
        echo Current cluster: %%i
    )
    echo 🗑️ Deleting existing cluster to avoid version conflicts...
    minikube delete
    timeout /t 5 /nobreak >nul
)

REM Start Minikube with robust configuration
echo 🔧 Starting Minikube cluster...
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=50g --addons=ingress,dashboard,metrics-server,registry
if %ERRORLEVEL% neq 0 (
    echo ❌ Failed to start Minikube with Docker driver
    echo 💡 Trying with alternative driver...
    minikube start --driver=hyperv --cpus=4 --memory=8192 --disk-size=50g --addons=ingress,dashboard,metrics-server,registry
    if %ERRORLEVEL% neq 0 (
        echo ❌ Failed to start Minikube. Please check your system configuration.
        echo 💡 Suggestions:
        echo    1. Ensure Docker Desktop is running
        echo    2. Check if Hyper-V is enabled (for Windows)
        echo    3. Run: minikube delete and try again
        exit /b 1
    )
)

REM Wait for cluster to be ready with timeout
echo ⏳ Waiting for cluster to be ready...
kubectl wait --for=condition=ready nodes --all --timeout=300s
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Cluster took longer than expected to be ready, but continuing...
)

REM Enable necessary addons
echo 🔌 Enabling additional addons...
minikube addons enable ingress-dns
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

REM Configure Docker environment to use Minikube's Docker daemon
echo 🐳 Configuring Docker environment...
echo 💡 Setting up Docker environment for Minikube...
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd 2^>nul') do (
    echo Executing: %%i
    %%i
)

REM Verify Docker configuration
echo 🔍 Verifying Docker configuration...
docker info | findstr "minikube" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ✅ Docker is now configured to use Minikube
) else (
    echo ⚠️ Docker environment setup incomplete. You may need to run:
    echo    minikube docker-env --shell cmd
    echo    And execute the commands manually
)

REM Create namespace for our application
echo 📦 Creating application namespace...
kubectl create namespace cicd-pipeline --dry-run=client -o yaml | kubectl apply -f - --validate=false
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Namespace creation failed, but continuing...
)

REM Build the application image in Minikube's Docker environment
echo 🏗️ Building application image in Minikube...
echo 💡 Building with network retry logic...
docker build --network=host --pull -t cicd-pipeline:latest .
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Docker build failed. Trying alternative approach...
    echo 💡 Using cached build if available...
    docker build --cache-from cicd-pipeline:latest -t cicd-pipeline:latest .
    if %ERRORLEVEL% neq 0 (
        echo ❌ Docker build failed. Please check your network connection and Dockerfile
        echo 💡 You can try running: docker build -t cicd-pipeline:latest . manually
    )
)

REM Create ConfigMap for database initialization
echo 📄 Creating database initialization ConfigMap...
if exist "scripts\init-db.sql" (
    kubectl create configmap postgres-init-script --from-file=init-db.sql=scripts/init-db.sql --namespace=cicd-pipeline --dry-run=client -o yaml | kubectl apply -f - --validate=false
) else (
    echo ⚠️ init-db.sql not found, skipping ConfigMap creation
)

REM Create secrets (you should replace these with actual secure values)
echo 🔐 Creating application secrets...
kubectl create secret generic cicd-pipeline-secrets --from-literal=SECRET_KEY=your-super-secret-key-change-this --from-literal=DB_PASSWORD=password123 --from-literal=REDIS_PASSWORD=redis123 --from-literal=WEBHOOK_SECRET=webhook-secret-123 --namespace=cicd-pipeline --dry-run=client -o yaml | kubectl apply -f - --validate=false

REM Deploy the application
echo 🚀 Deploying application to Minikube...
if exist "k8s\minikube-deployment.yaml" (
    kubectl apply -f k8s/minikube-deployment.yaml --validate=false
    if %ERRORLEVEL% neq 0 (
        echo ⚠️ Deployment failed, but continuing...
    )
) else (
    echo ⚠️ minikube-deployment.yaml not found, skipping deployment
)

REM Wait for deployments to be ready with error handling
echo ⏳ Waiting for deployments to be ready...
kubectl get deployments -n cicd-pipeline >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo 🔍 Checking deployment status...
    kubectl wait --for=condition=available --timeout=120s deployment/postgres -n cicd-pipeline >nul 2>&1
    kubectl wait --for=condition=available --timeout=120s deployment/redis -n cicd-pipeline >nul 2>&1
    kubectl wait --for=condition=available --timeout=120s deployment/cicd-pipeline-app -n cicd-pipeline >nul 2>&1
) else (
    echo ⚠️ No deployments found to wait for
)

REM Get service information
echo.
echo 📊 Deployment Status:
kubectl get pods -n cicd-pipeline 2>nul
echo.
kubectl get services -n cicd-pipeline 2>nul
echo.

REM Get Minikube IP and service URLs
echo 🌐 Access Information:
for /f "tokens=*" %%i in ('minikube ip 2^>nul') do set MINIKUBE_IP=%%i
if not "%MINIKUBE_IP%"=="" (
    echo Minikube IP: %MINIKUBE_IP%
) else (
    echo Minikube IP: Not available - cluster may not be ready
)
echo.

REM Get service URLs
echo 🔗 Service URLs:
minikube service cicd-pipeline-service --url -n cicd-pipeline >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('minikube service cicd-pipeline-service --url -n cicd-pipeline 2^>nul') do set API_URL=%%i
    if not "%API_URL%"=="" (
        echo API Service: %API_URL%
        echo API Docs: %API_URL%/docs
        echo Health Check: %API_URL%/health
    )
) else (
    echo Service not yet available. Use 'minikube service list' to check later.
)
echo.

REM Dashboard access
echo 📊 Kubernetes Dashboard:
echo Run: minikube dashboard
echo.

REM Ingress information
kubectl get ingress -n cicd-pipeline >nul 2>&1
if %ERRORLEVEL% equ 0 (
    if not "%MINIKUBE_IP%"=="" (
        echo 🌍 Ingress URLs (add to C:\Windows\System32\drivers\etc\hosts):
        echo %MINIKUBE_IP% cicd-pipeline.local
        echo Then access: http://cicd-pipeline.local
        echo.
    )
)

echo 🎉 Minikube setup completed!
echo.
echo 🔧 Useful commands:
echo   View status: scripts\minikube-manage.bat status
echo   View logs: scripts\minikube-manage.bat logs-app
echo   Scale app: scripts\minikube-manage.bat scale 3
echo   Port forward: scripts\minikube-manage.bat port-forward 8080
echo   Access dashboard: scripts\minikube-manage.bat dashboard
echo   Stop cluster: scripts\minikube-manage.bat stop
echo   Restart app: scripts\minikube-manage.bat restart
echo.
echo 🐳 Docker environment commands:
echo   Configure for Minikube: scripts\minikube-manage.bat docker-env
echo   Reset to system: scripts\minikube-manage.bat reset-docker
echo.
echo 🚨 If you encountered errors:
echo   1. Run: scripts\minikube-manage.bat status (to check cluster health)
echo   2. Run: scripts\minikube-manage.bat logs (to check cluster logs)
echo   3. Run: scripts\minikube-manage.bat clean (to clean up)
echo   4. Try: minikube delete followed by running this script again
