@echo off
REM 🚀 CI/CD Pipeline - Windows Production Deployment Script
REM Automated production deployment with validation and rollback capabilities

setlocal enabledelayedexpansion

REM Configuration with defaults
if "%NAMESPACE%"=="" set NAMESPACE=cicd-production
if "%IMAGE_TAG%"=="" set IMAGE_TAG=latest
if "%DOMAIN%"=="" set DOMAIN=api.yourcompany.com
if "%TIMEOUT%"=="" set TIMEOUT=600s
if "%DRY_RUN%"=="" set DRY_RUN=false

set CHART_PATH=.\helm\cicd-pipeline
set VALUES_FILE=.\environments\values-prod.yaml

REM Parse command line arguments
:parse_args
if "%1"=="--namespace" (
    set NAMESPACE=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--tag" (
    set IMAGE_TAG=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--domain" (
    set DOMAIN=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--dry-run" (
    set DRY_RUN=true
    shift
    goto parse_args
)
if "%1"=="--rollback" (
    set ROLLBACK=true
    shift
    goto parse_args
)
if "%1"=="--backup" (
    set BACKUP=true
    shift
    goto parse_args
)
if "%1"=="--help" goto show_help
if "%1"=="-h" goto show_help
if not "%1"=="" (
    echo [ERROR] Unknown option: %1
    echo Use --help for usage information
    exit /b 1
)

echo [INFO] 🚀 Starting CI/CD Pipeline Production Deployment
echo [INFO] Namespace: %NAMESPACE%
echo [INFO] Image Tag: %IMAGE_TAG%
echo [INFO] Domain: %DOMAIN%
echo [INFO] Dry Run: %DRY_RUN%

REM Pre-flight checks
echo [INFO] Running pre-flight checks...

REM Check kubectl
kubectl version --client >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] kubectl is not installed or not in PATH
    exit /b 1
)
echo [SUCCESS] kubectl is available

REM Check helm
helm version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] helm is not installed or not in PATH
    exit /b 1
)
echo [SUCCESS] helm is available

REM Check cluster connectivity
kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Cannot connect to Kubernetes cluster
    exit /b 1
)
echo [SUCCESS] Kubernetes cluster is accessible

REM Check chart exists
if not exist "%CHART_PATH%\Chart.yaml" (
    echo [ERROR] Helm chart not found at %CHART_PATH%
    exit /b 1
)
echo [SUCCESS] Helm chart found

REM Check values file exists
if not exist "%VALUES_FILE%" (
    echo [ERROR] Values file not found at %VALUES_FILE%
    exit /b 1
)
echo [SUCCESS] Values file found

echo [SUCCESS] Pre-flight checks passed

REM Handle rollback
if "%ROLLBACK%"=="true" (
    echo [INFO] Rolling back deployment...
    
    helm list -n %NAMESPACE% | findstr cicd-pipeline >nul
    if %errorlevel% neq 0 (
        echo [ERROR] No Helm release found to rollback
        exit /b 1
    )
    
    echo [INFO] Deployment history:
    helm history cicd-pipeline -n %NAMESPACE%
    
    if "%DRY_RUN%"=="false" (
        helm rollback cicd-pipeline -n %NAMESPACE%
        kubectl rollout status deployment/cicd-pipeline -n %NAMESPACE% --timeout=%TIMEOUT%
    )
    
    echo [SUCCESS] Rollback completed
    exit /b 0
)

REM Create namespace
echo [INFO] Checking namespace %NAMESPACE%...
kubectl get namespace %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Creating namespace %NAMESPACE%...
    if "%DRY_RUN%"=="false" (
        kubectl create namespace %NAMESPACE%
    )
    echo [SUCCESS] Namespace %NAMESPACE% created
) else (
    echo [SUCCESS] Namespace %NAMESPACE% already exists
)

REM Generate secrets
echo [INFO] Checking production secrets...
kubectl get secret cicd-pipeline-secrets -n %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Generating production secrets...
    
    if "%DRY_RUN%"=="false" (
        REM Generate random passwords (simplified for Windows)
        set DB_PASSWORD=%RANDOM%%RANDOM%%RANDOM%
        set REDIS_PASSWORD=%RANDOM%%RANDOM%%RANDOM%
        set SECRET_KEY=%RANDOM%%RANDOM%%RANDOM%%RANDOM%
        
        REM Create secrets
        kubectl create secret generic postgresql-prod-secret --from-literal=postgres-password=!DB_PASSWORD! --namespace %NAMESPACE%
        kubectl create secret generic redis-prod-secret --from-literal=redis-password=!REDIS_PASSWORD! --namespace %NAMESPACE%
        kubectl create secret generic cicd-pipeline-secrets --from-literal=secret-key=!SECRET_KEY! --from-literal=database-url="postgresql://prod_user:!DB_PASSWORD!@cicd-pipeline-postgresql:5432/cicd_production" --from-literal=redis-url="redis://:!REDIS_PASSWORD!@cicd-pipeline-redis:6379/0" --namespace %NAMESPACE%
    )
    echo [SUCCESS] Production secrets generated
) else (
    echo [WARNING] Secrets already exist in namespace %NAMESPACE%
)

REM Create backup
if "%BACKUP%"=="true" (
    echo [INFO] Creating deployment backup...
    
    set backup_dir=backups\%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%
    set backup_dir=%backup_dir: =0%
    mkdir "%backup_dir%" 2>nul
    
    helm list -n %NAMESPACE% | findstr cicd-pipeline >nul
    if %errorlevel% equ 0 (
        helm get values cicd-pipeline -n %NAMESPACE% > "%backup_dir%\helm-values.yaml"
        helm get manifest cicd-pipeline -n %NAMESPACE% > "%backup_dir%\manifests.yaml"
        echo [SUCCESS] Helm release backed up to %backup_dir%
    )
    
    kubectl get pv,pvc -n %NAMESPACE% -o yaml > "%backup_dir%\volumes.yaml" 2>nul
    echo [SUCCESS] Backup created in %backup_dir%
)

REM Deploy application
echo [INFO] Deploying CI/CD Pipeline to production...

REM Update Helm dependencies
echo [INFO] Updating Helm dependencies...
helm dependency update %CHART_PATH%

REM Prepare and execute deployment
echo [INFO] Executing deployment...
set helm_cmd=helm upgrade --install cicd-pipeline %CHART_PATH% --namespace %NAMESPACE% --values %VALUES_FILE% --set image.tag=%IMAGE_TAG% --set ingress.hosts[0].host=%DOMAIN% --set ingress.tls[0].hosts[0]=%DOMAIN% --timeout %TIMEOUT% --wait

if "%DRY_RUN%"=="true" (
    set helm_cmd=%helm_cmd% --dry-run
    echo [INFO] DRY RUN: %helm_cmd%
)

%helm_cmd%
if %errorlevel% neq 0 (
    echo [ERROR] Deployment failed
    exit /b 1
)

if "%DRY_RUN%"=="true" (
    echo [SUCCESS] Dry run completed successfully
    exit /b 0
)

echo [SUCCESS] Application deployed successfully

REM Validate deployment
echo [INFO] Validating deployment...

REM Check pod status
echo [INFO] Checking pod status...
kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=cicd-pipeline"

REM Wait for pods to be ready
kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=cicd-pipeline" -n %NAMESPACE% --timeout=300s
if %errorlevel% neq 0 (
    echo [ERROR] Pods are not ready
    exit /b 1
)

REM Check services and ingress
echo [INFO] Checking services...
kubectl get svc -n %NAMESPACE%

echo [INFO] Checking ingress...
kubectl get ingress -n %NAMESPACE%

REM Test health endpoint
echo [INFO] Testing health endpoint...
set /a "PORT=8000 + %RANDOM% %% 1000"

REM Start port forwarding in background
start /b kubectl port-forward -n %NAMESPACE% svc/cicd-pipeline %PORT%:80

REM Wait for port forward to establish
timeout /t 5 >nul

REM Test health endpoint
for /l %%i in (1,1,10) do (
    curl -s -w "%%{http_code}" http://localhost:%PORT%/health > temp_health.txt 2>nul
    if !errorlevel! equ 0 (
        for /f %%a in (temp_health.txt) do (
            if "%%a"=="200" (
                echo [SUCCESS] Health check passed
                goto health_success
            )
        )
    )
    echo [INFO] Health check attempt %%i/10...
    timeout /t 3 >nul
)

echo [ERROR] Health check failed
exit /b 1

:health_success
del temp_health.txt 2>nul

REM Stop port forwarding
for /f "tokens=2" %%a in ('tasklist /fi "imagename eq kubectl.exe" /fo table /nh ^| findstr kubectl') do (
    taskkill /pid %%a /f >nul 2>&1
)

REM Setup monitoring
echo [INFO] Setting up production monitoring...

REM Apply ServiceMonitor
echo apiVersion: monitoring.coreos.com/v1 > temp_servicemonitor.yaml
echo kind: ServiceMonitor >> temp_servicemonitor.yaml
echo metadata: >> temp_servicemonitor.yaml
echo   name: cicd-pipeline-monitor >> temp_servicemonitor.yaml
echo   namespace: %NAMESPACE% >> temp_servicemonitor.yaml
echo spec: >> temp_servicemonitor.yaml
echo   selector: >> temp_servicemonitor.yaml
echo     matchLabels: >> temp_servicemonitor.yaml
echo       app.kubernetes.io/name: cicd-pipeline >> temp_servicemonitor.yaml
echo   endpoints: >> temp_servicemonitor.yaml
echo   - port: metrics >> temp_servicemonitor.yaml
echo     path: /metrics >> temp_servicemonitor.yaml
echo     interval: 30s >> temp_servicemonitor.yaml

kubectl apply -f temp_servicemonitor.yaml
del temp_servicemonitor.yaml

echo [SUCCESS] Monitoring setup completed

REM Generate deployment report
echo [INFO] Generating deployment report...

set report_file=PRODUCTION_DEPLOYMENT_REPORT_%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%.md
set report_file=%report_file: =0%

(
echo # 🚀 Production Deployment Report
echo.
echo **Date:** %date% %time%
echo **Namespace:** %NAMESPACE%
echo **Image Tag:** %IMAGE_TAG%
echo **Domain:** %DOMAIN%
echo.
echo ## Deployment Summary
echo.
echo - ✅ Application deployed successfully
echo - ✅ Health checks passing
echo - ✅ Monitoring configured
echo - ✅ Secrets generated
echo.
echo ## Access Information
echo.
echo - **Application URL:** https://%DOMAIN%
echo - **Health Check:** https://%DOMAIN%/health
echo - **Metrics:** https://%DOMAIN%/metrics
echo - **API Docs:** https://%DOMAIN%/docs
echo.
echo ## Next Steps
echo.
echo 1. Configure DNS to point %DOMAIN% to the load balancer
echo 2. Verify TLS certificates are issued
echo 3. Set up monitoring alerts
echo 4. Configure backup schedules
echo 5. Test disaster recovery procedures
echo.
echo ---
echo Generated by CI/CD Pipeline Production Deployment Script ^(Windows^)
) > "%report_file%"

echo [SUCCESS] Deployment report generated: %report_file%

echo.
echo [SUCCESS] 🎉 Production deployment completed successfully!
echo [INFO] Application URL: https://%DOMAIN%
echo [INFO] Health Check: curl https://%DOMAIN%/health
echo [INFO] API Documentation: https://%DOMAIN%/docs

goto end

:show_help
echo.
echo 🚀 CI/CD Pipeline Production Deployment Script
echo.
echo Usage: %0 [OPTIONS]
echo.
echo OPTIONS:
echo     --namespace NAMESPACE    Target namespace (default: cicd-production)
echo     --tag TAG               Docker image tag (default: latest)
echo     --domain DOMAIN         Application domain (default: api.yourcompany.com)
echo     --dry-run              Perform a dry run without making changes
echo     --rollback             Rollback to previous version
echo     --backup               Create backup before deployment
echo     --help                 Show this help message
echo.
echo EXAMPLES:
echo     %0                                          # Deploy with defaults
echo     %0 --tag v1.2.0 --domain api.myapp.com    # Deploy specific version
echo     %0 --dry-run                               # Test deployment
echo     %0 --rollback                              # Rollback deployment
echo     %0 --backup --tag v1.2.0                  # Backup and deploy
echo.

:end
endlocal
