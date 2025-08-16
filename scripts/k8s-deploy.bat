@echo off
REM Kubernetes deployment script for Windows

set NAMESPACE=%1
if "%NAMESPACE%"=="" set NAMESPACE=cicd-pipeline

set ENVIRONMENT=%2
if "%ENVIRONMENT%"=="" set ENVIRONMENT=production

set IMAGE_TAG=%3
if "%IMAGE_TAG%"=="" set IMAGE_TAG=latest



echo 🚀 Deploying CI/CD Pipeline to Kubernetes
echo Namespace: %NAMESPACE%
echo Environment: %ENVIRONMENT%
echo Image Tag: %IMAGE_TAG%

REM Check if kubectl is available
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo ❌ kubectl is not installed or not in PATH
    exit /b 1
)

REM Check if we can connect to the cluster
kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo ❌ Cannot connect to Kubernetes cluster
    exit /b 1
)

REM Create namespace if it doesn't exist
echo 📦 Creating namespace if it doesn't exist...
kubectl create namespace %NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -

REM Create ConfigMap for database init script
echo 🗄️ Creating database initialization ConfigMap...
kubectl create configmap postgres-init-script --from-file=init-db.sql=scripts/init-db.sql --namespace=%NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -

REM Apply the complete deployment
echo 🛠️ Applying Kubernetes manifests...
kubectl apply -f k8s/complete-deployment.yaml

REM Wait for deployments to be ready
echo ⏳ Waiting for deployments to be ready...
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n %NAMESPACE%
kubectl wait --for=condition=available --timeout=300s deployment/redis -n %NAMESPACE%
kubectl wait --for=condition=available --timeout=300s deployment/cicd-pipeline-app -n %NAMESPACE%

REM Get the status
echo 📊 Deployment status:
kubectl get pods -n %NAMESPACE%
kubectl get services -n %NAMESPACE%
kubectl get ingress -n %NAMESPACE%

REM Get the external IP or URL
echo.
echo 🌐 Access Information:
kubectl get ingress cicd-pipeline-ingress -n %NAMESPACE% >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%i in ('kubectl get ingress cicd-pipeline-ingress -n %NAMESPACE% -o jsonpath="{.spec.rules[0].host}"') do set INGRESS_HOST=%%i
    echo External URL: https://%INGRESS_HOST%
) else (
    echo Service URL: kubectl port-forward -n %NAMESPACE% service/cicd-pipeline-service 8080:80
    echo Then access: http://localhost:8080
)

REM Show logs if there are any issues
echo.
echo 📜 Recent logs:
kubectl logs -n %NAMESPACE% deployment/cicd-pipeline-app --tail=10 2>nul

echo.
echo ✅ Deployment completed!
echo 🔧 Useful commands:
echo   View logs: kubectl logs -n %NAMESPACE% deployment/cicd-pipeline-app -f
echo   Scale app: kubectl scale deployment cicd-pipeline-app --replicas=5 -n %NAMESPACE%
echo   Port forward: kubectl port-forward -n %NAMESPACE% service/cicd-pipeline-service 8080:80
echo   Delete: kubectl delete namespace %NAMESPACE%
