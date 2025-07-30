@echo off
REM Minikube management script for Windows

set COMMAND=%1
if "%COMMAND%"=="" set COMMAND=help

if "%COMMAND%"=="start" goto start
if "%COMMAND%"=="stop" goto stop
if "%COMMAND%"=="delete" goto delete
if "%COMMAND%"=="status" goto status
if "%COMMAND%"=="dashboard" goto dashboard
if "%COMMAND%"=="tunnel" goto tunnel
if "%COMMAND%"=="ip" goto ip
if "%COMMAND%"=="services" goto services
if "%COMMAND%"=="logs" goto logs
if "%COMMAND%"=="ssh" goto ssh
if "%COMMAND%"=="docker-env" goto docker-env
if "%COMMAND%"=="reset-docker" goto reset-docker
if "%COMMAND%"=="build" goto build
if "%COMMAND%"=="deploy" goto deploy
if "%COMMAND%"=="url" goto url
if "%COMMAND%"=="port-forward" goto port-forward
if "%COMMAND%"=="logs-app" goto logs-app
if "%COMMAND%"=="scale" goto scale
if "%COMMAND%"=="restart" goto restart
if "%COMMAND%"=="clean" goto clean
if "%COMMAND%"=="addons" goto addons
if "%COMMAND%"=="troubleshoot" goto troubleshoot
if "%COMMAND%"=="fix" goto fix
goto help

:start
echo 🚀 Starting Minikube cluster...
echo 💡 Using optimized settings for your system...
minikube start --driver=docker --cpus=2 --memory=6144
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Failed with 6GB, trying 4GB...
    minikube start --driver=docker --cpus=2 --memory=4096
    if %ERRORLEVEL% neq 0 (
        echo ⚠️ Failed with 4GB, trying minimal (3GB)...
        minikube start --driver=docker --cpus=2 --memory=3072
    )
)
goto end

:stop
echo 🛑 Stopping Minikube cluster...
minikube stop
goto end

:delete
echo 🗑️ Deleting Minikube cluster...
minikube delete
goto end

:status
echo 📊 Minikube status:
minikube status
echo.
echo 📦 Cluster info:
kubectl cluster-info
echo.
echo 📋 Nodes:
kubectl get nodes
goto end

:dashboard
echo 📊 Opening Kubernetes dashboard...
minikube dashboard
goto end

:tunnel
echo 🌐 Starting Minikube tunnel...
echo This will expose LoadBalancer services
minikube tunnel
goto end

:ip
echo 🌍 Minikube IP address:
minikube ip
goto end

:services
echo 🔗 Available services:
minikube service list
goto end

:logs
echo 📜 Minikube logs:
minikube logs
goto end

:ssh
echo 🔧 SSH into Minikube node...
minikube ssh
goto end

:docker-env
echo 🐳 Configure Docker to use Minikube's Docker daemon:
echo Run the following command:
minikube docker-env --shell cmd
goto end

:reset-docker
echo 🔄 Reset Docker environment to use system Docker:
echo Run the following command:
minikube docker-env -u --shell cmd
goto end

:build
echo 🏗️ Building application in Minikube Docker environment...
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd') do %%i
docker build -t cicd-pipeline:latest .
echo ✅ Image built successfully in Minikube
goto end

:deploy
echo 🚀 Deploying application to Minikube...
kubectl apply -f k8s/minikube-deployment.yaml
echo ⏳ Waiting for deployment...
kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n cicd-pipeline
echo ✅ Deployment completed
goto end

:url
echo 🌐 Getting service URL...
for /f "tokens=*" %%i in ('minikube service cicd-pipeline-service --url -n cicd-pipeline') do set SERVICE_URL=%%i
echo API URL: %SERVICE_URL%
echo API Docs: %SERVICE_URL%/docs
echo Health Check: %SERVICE_URL%/health
goto end

:port-forward
set PORT=%2
if "%PORT%"=="" set PORT=8080
echo 🔗 Port forwarding on port %PORT%...
kubectl port-forward -n cicd-pipeline service/cicd-pipeline-service %PORT%:80
goto end

:logs-app
echo 📜 Application logs:
kubectl logs -n cicd-pipeline deployment/cicd-pipeline-app -f
goto end

:scale
set REPLICAS=%2
if "%REPLICAS%"=="" set REPLICAS=3
echo 📈 Scaling application to %REPLICAS% replicas...
kubectl scale deployment cicd-pipeline-app --replicas=%REPLICAS% -n cicd-pipeline
goto end

:restart
echo 🔄 Restarting application...
kubectl rollout restart deployment/cicd-pipeline-app -n cicd-pipeline
kubectl rollout status deployment/cicd-pipeline-app -n cicd-pipeline
goto end

:clean
echo 🧹 Cleaning up deployments...
kubectl delete -f k8s/minikube-deployment.yaml --ignore-not-found=true
kubectl delete namespace cicd-pipeline --ignore-not-found=true
goto end

:addons
set ADDON_CMD=%2
if "%ADDON_CMD%"=="" set ADDON_CMD=list

if "%ADDON_CMD%"=="list" (
    minikube addons list
) else if "%ADDON_CMD%"=="enable" (
    set ADDON_NAME=%3
    if "%ADDON_NAME%"=="" set ADDON_NAME=ingress
    minikube addons enable %ADDON_NAME%
) else if "%ADDON_CMD%"=="disable" (
    set ADDON_NAME=%3
    if "%ADDON_NAME%"=="" set ADDON_NAME=ingress
    minikube addons disable %ADDON_NAME%
) else (
    echo Usage: %0 addons [list^|enable^|disable] [addon-name]
)
goto end

:troubleshoot
echo 🔍 Minikube Troubleshooting...
echo.
echo 📊 Cluster Status:
minikube status
echo.
echo 🐳 Docker Status:
docker info | findstr "minikube"
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Docker is not configured for Minikube
    echo Run: %0 docker-env
)
echo.
echo 📦 Pods Status:
kubectl get pods -n cicd-pipeline
echo.
echo 🔗 Services Status:
kubectl get services -n cicd-pipeline
echo.
echo 📋 Events (last 10):
kubectl get events -n cicd-pipeline --sort-by='.lastTimestamp' | tail -10
echo.
echo 💾 Storage:
kubectl get pvc -n cicd-pipeline
goto end

:fix
echo 🛠️ Running automatic fixes...
echo.
echo 1. Checking cluster connection...
kubectl get nodes >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Cannot connect to cluster, restarting...
    minikube stop
    echo 💡 Starting with optimized memory settings...
    minikube start --driver=docker --cpus=2 --memory=6144
    if %ERRORLEVEL% neq 0 (
        minikube start --driver=docker --cpus=2 --memory=4096
        if %ERRORLEVEL% neq 0 (
            minikube start --driver=docker --cpus=2 --memory=3072
        )
    )
)
echo.
echo 2. Configuring Docker environment...
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd') do %%i
echo.
echo 3. Checking namespace...
kubectl get namespace cicd-pipeline >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Creating namespace...
    kubectl create namespace cicd-pipeline
)
echo.
echo 4. Rebuilding image if needed...
docker images | findstr "cicd-pipeline" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Building application image...
    docker build -t cicd-pipeline:latest .
)
echo.
echo ✅ Automatic fixes completed
goto end

:help
echo 🔧 Minikube Management Script
echo.
echo Usage: %0 [command] [options]
echo.
echo Cluster Management:
echo   start         Start Minikube cluster
echo   stop          Stop Minikube cluster
echo   delete        Delete Minikube cluster
echo   status        Show cluster status
echo   restart       Restart the application
echo.
echo Application Management:
echo   build         Build application image
echo   deploy        Deploy application
echo   clean         Clean up deployments
echo   scale [n]     Scale to n replicas (default: 3)
echo.
echo Access ^& Networking:
echo   url           Get service URLs
echo   port-forward [port]  Port forward to local port (default: 8080)
echo   ip            Show Minikube IP
echo   services      List all services
echo   tunnel        Start LoadBalancer tunnel
echo.
echo Monitoring ^& Debugging:
echo   dashboard     Open Kubernetes dashboard
echo   logs          Show Minikube logs
echo   logs-app      Show application logs
echo   ssh           SSH into Minikube node
echo.
echo Docker Environment:
echo   docker-env    Configure Docker for Minikube
echo   reset-docker  Reset Docker to system
echo.
echo Add-ons:
echo   addons list           List available addons
echo   addons enable [name]  Enable addon
echo   addons disable [name] Disable addon
echo.
echo Troubleshooting:
echo   troubleshoot  Run diagnostics
echo   fix          Run automatic fixes
echo.
echo Examples:
echo   %0 start
echo   %0 build ^&^& %0 deploy
echo   %0 port-forward 8080
echo   %0 scale 5
echo   %0 troubleshoot

:end
