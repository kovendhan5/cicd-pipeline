@echo off
REM 🔧 CI/CD Pipeline - Advanced Health Check Script (Windows)

setlocal enabledelayedexpansion

REM Configuration with defaults
if "%NAMESPACE%"=="" set NAMESPACE=cicd-production
if "%TIMEOUT%"=="" set TIMEOUT=300s
if "%RETRIES%"=="" set RETRIES=3

REM Parse command line arguments
:parse_args
if "%1"=="--namespace" (
    set NAMESPACE=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--timeout" (
    set TIMEOUT=%2
    shift
    shift
    goto parse_args
)
if "%1"=="--retries" (
    set RETRIES=%2
    shift
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

echo [INFO] 🔍 CI/CD Pipeline Advanced Health Check
echo [INFO] =====================================
echo.
echo [INFO] Namespace: %NAMESPACE%
echo [INFO] Timeout: %TIMEOUT%
echo [INFO] Retries: %RETRIES%
echo.

set OVERALL_STATUS=0

REM Prerequisites check
echo [INFO] 📋 Prerequisites Check
echo [INFO] =====================

REM Check kubectl
kubectl version --client >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ kubectl is required for health checks
    exit /b 1
)

REM Check cluster connectivity
kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ Cannot connect to Kubernetes cluster
    exit /b 1
)
echo [SUCCESS] ✅ Connected to Kubernetes cluster

REM Check namespace exists
kubectl get namespace %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ Namespace %NAMESPACE% does not exist
    exit /b 1
)
echo [SUCCESS] ✅ Namespace %NAMESPACE% exists
echo.

REM Application Health Checks
echo [INFO] 🚀 Application Health Checks
echo [INFO] ============================

REM Check main application pods
echo [INFO] 🔍 Checking Main Application...
kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=cicd-pipeline" --no-headers >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ No pods found for Main Application
    set OVERALL_STATUS=1
) else (
    REM Check if all pods are running
    for /f %%i in ('kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=cicd-pipeline" --no-headers ^| findstr /v "Running Completed" ^| find /c /v ""') do set NOT_READY=%%i
    if !NOT_READY! gtr 0 (
        echo [ERROR] ❌ !NOT_READY! pods are not ready for Main Application
        kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=cicd-pipeline"
        set OVERALL_STATUS=1
    ) else (
        echo [SUCCESS] ✅ Main Application pods are healthy
    )
)

REM Check main application service
kubectl get svc cicd-pipeline -n %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ Service cicd-pipeline not found
    set OVERALL_STATUS=1
) else (
    echo [SUCCESS] ✅ Main Application service is healthy
)

REM Check application logs for errors
echo [INFO] 🔍 Checking Main Application logs for errors...
kubectl logs -n %NAMESPACE% -l "app.kubernetes.io/name=cicd-pipeline" --tail=100 --since=5m >temp_logs.txt 2>nul
if exist temp_logs.txt (
    findstr /i "error exception failed fatal" temp_logs.txt >temp_errors.txt 2>nul
    if exist temp_errors.txt (
        for /f %%i in ('type temp_errors.txt ^| find /c /v ""') do set ERROR_COUNT=%%i
        if !ERROR_COUNT! gtr 0 (
            echo [WARNING] ⚠️  Found !ERROR_COUNT! error(s) in Main Application logs
            echo [INFO] Recent errors:
            type temp_errors.txt | head -3 2>nul
        ) else (
            echo [SUCCESS] ✅ No recent errors in Main Application logs
        )
        del temp_errors.txt
    ) else (
        echo [SUCCESS] ✅ No recent errors in Main Application logs
    )
    del temp_logs.txt
)
echo.

REM Database Health Checks
echo [INFO] 🗃️  Database Health Checks
echo [INFO] =========================

REM Check PostgreSQL pods
echo [INFO] 🔍 Checking PostgreSQL Database...
kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=postgresql" --no-headers >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ No pods found for PostgreSQL Database
    set OVERALL_STATUS=1
) else (
    for /f %%i in ('kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=postgresql" --no-headers ^| findstr /v "Running Completed" ^| find /c /v ""') do set NOT_READY=%%i
    if !NOT_READY! gtr 0 (
        echo [ERROR] ❌ !NOT_READY! pods are not ready for PostgreSQL Database
        set OVERALL_STATUS=1
    ) else (
        echo [SUCCESS] ✅ PostgreSQL Database pods are healthy
    )
)

REM Check PostgreSQL service
kubectl get svc cicd-pipeline-postgresql -n %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ Service cicd-pipeline-postgresql not found
    set OVERALL_STATUS=1
) else (
    echo [SUCCESS] ✅ PostgreSQL Database service is healthy
)
echo.

REM Cache Health Checks
echo [INFO] 🗂️  Cache Health Checks
echo [INFO] =====================

REM Check Redis pods
echo [INFO] 🔍 Checking Redis Cache...
kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=redis" --no-headers >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ No pods found for Redis Cache
    set OVERALL_STATUS=1
) else (
    for /f %%i in ('kubectl get pods -n %NAMESPACE% -l "app.kubernetes.io/name=redis" --no-headers ^| findstr /v "Running Completed" ^| find /c /v ""') do set NOT_READY=%%i
    if !NOT_READY! gtr 0 (
        echo [ERROR] ❌ !NOT_READY! pods are not ready for Redis Cache
        set OVERALL_STATUS=1
    ) else (
        echo [SUCCESS] ✅ Redis Cache pods are healthy
    )
)

REM Check Redis service
kubectl get svc cicd-pipeline-redis -n %NAMESPACE% >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ❌ Service cicd-pipeline-redis not found
    set OVERALL_STATUS=1
) else (
    echo [SUCCESS] ✅ Redis Cache service is healthy
)
echo.

REM Network Health Checks
echo [INFO] 🌐 Network Health Checks
echo [INFO] =======================

REM Check ingress
kubectl get ingress -n %NAMESPACE% >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ Ingress is configured
    kubectl get ingress -n %NAMESPACE%
) else (
    echo [WARNING] ⚠️  No ingress found
)

REM Check network policies
for /f %%i in ('kubectl get networkpolicies -n %NAMESPACE% --no-headers 2^>nul ^| find /c /v ""') do set NETPOL_COUNT=%%i
if !NETPOL_COUNT! gtr 0 (
    echo [SUCCESS] ✅ Network policies are configured (!NETPOL_COUNT!)
) else (
    echo [WARNING] ⚠️  No network policies found
)
echo.

REM Security Health Checks
echo [INFO] 🔒 Security Health Checks
echo [INFO] ========================

REM Check RBAC
for /f %%i in ('kubectl get rolebindings,clusterrolebindings -n %NAMESPACE% --no-headers 2^>nul ^| find /c /v ""') do set RBAC_COUNT=%%i
if !RBAC_COUNT! gtr 0 (
    echo [SUCCESS] ✅ RBAC is configured (!RBAC_COUNT! bindings)
) else (
    echo [WARNING] ⚠️  Limited RBAC configuration
)

REM Check secrets
kubectl get secrets -n %NAMESPACE% --no-headers >temp_secrets.txt 2>nul
if exist temp_secrets.txt (
    findstr /v "default-token sh.helm.release" temp_secrets.txt >temp_app_secrets.txt 2>nul
    if exist temp_app_secrets.txt (
        for /f %%i in ('type temp_app_secrets.txt ^| find /c /v ""') do set SECRET_COUNT=%%i
        if !SECRET_COUNT! gtr 0 (
            echo [SUCCESS] ✅ Secrets are configured (!SECRET_COUNT!)
        ) else (
            echo [ERROR] ❌ No application secrets found
            set OVERALL_STATUS=1
        )
        del temp_app_secrets.txt
    ) else (
        echo [ERROR] ❌ No application secrets found
        set OVERALL_STATUS=1
    )
    del temp_secrets.txt
)
echo.

REM Performance Health Checks
echo [INFO] ⚡ Performance Health Checks
echo [INFO] ============================

REM Check HPA
kubectl get hpa -n %NAMESPACE% >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ Horizontal Pod Autoscaler is configured
    kubectl get hpa -n %NAMESPACE%
) else (
    echo [WARNING] ⚠️  No Horizontal Pod Autoscaler found
)

REM Check resource quotas
kubectl get resourcequota -n %NAMESPACE% >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ Resource quotas are configured
) else (
    echo [WARNING] ⚠️  No resource quotas found
)

REM Check pod disruption budgets
for /f %%i in ('kubectl get pdb -n %NAMESPACE% --no-headers 2^>nul ^| find /c /v ""') do set PDB_COUNT=%%i
if !PDB_COUNT! gtr 0 (
    echo [SUCCESS] ✅ Pod Disruption Budgets are configured (!PDB_COUNT!)
) else (
    echo [WARNING] ⚠️  No Pod Disruption Budgets found
)
echo.

REM Monitoring Health Checks
echo [INFO] 📊 Monitoring Health Checks
echo [INFO] ==========================

REM Check ServiceMonitor
kubectl get servicemonitor -n %NAMESPACE% >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ ServiceMonitor is configured
) else (
    echo [WARNING] ⚠️  No ServiceMonitor found for Prometheus
)

REM Try to check metrics endpoint
echo [INFO] Testing metrics endpoint...
kubectl port-forward -n %NAMESPACE% svc/cicd-pipeline 8080:80 >nul 2>&1 &
set PF_PID=%BACKGROUND_PID%
timeout /t 3 >nul

curl -s -f http://localhost:8080/metrics >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ Metrics endpoint is accessible
) else (
    echo [WARNING] ⚠️  Metrics endpoint may not be working
)

REM Kill port-forward process
taskkill /f /im kubectl.exe >nul 2>&1
echo.

REM Backup and Recovery Checks
echo [INFO] 💾 Backup and Recovery Health
echo [INFO] =============================

REM Check for backup CronJobs
for /f %%i in ('kubectl get cronjobs -n %NAMESPACE% --no-headers 2^>nul ^| find /c /v ""') do set CRONJOB_COUNT=%%i
if !CRONJOB_COUNT! gtr 0 (
    echo [SUCCESS] ✅ Backup jobs are configured (!CRONJOB_COUNT!)
    kubectl get cronjobs -n %NAMESPACE%
) else (
    echo [WARNING] ⚠️  No backup jobs found
)

REM Check persistent volumes
for /f %%i in ('kubectl get pvc -n %NAMESPACE% --no-headers 2^>nul ^| find /c /v ""') do set PV_COUNT=%%i
if !PV_COUNT! gtr 0 (
    echo [SUCCESS] ✅ Persistent volumes are configured (!PV_COUNT!)
) else (
    echo [WARNING] ⚠️  No persistent volumes found
)
echo.

REM Overall Health Summary
echo [INFO] 📋 Health Check Summary
echo [INFO] ======================

if %OVERALL_STATUS% equ 0 (
    echo [SUCCESS] 🎉 Overall Status: HEALTHY
    echo [SUCCESS] ✅ All critical components are functioning properly
) else (
    echo [WARNING] ⚠️  Overall Status: ISSUES DETECTED
    echo [ERROR] ❌ Some components require attention
)

echo.
echo [INFO] 🔧 Recommended Actions:
if %OVERALL_STATUS% neq 0 (
    echo - Review failed health checks above
    echo - Check pod logs for detailed error information
    echo - Verify resource allocation and limits
    echo - Ensure all dependencies are properly configured
) else (
    echo - Monitor resource usage trends
    echo - Review and update scaling policies if needed
    echo - Verify backup procedures are working
    echo - Schedule regular health checks
)

echo.
echo [INFO] 📈 Next Steps:
echo - Set up automated health monitoring
echo - Configure alerting for critical issues
echo - Implement health check automation in CI/CD
echo - Document troubleshooting procedures

echo.
echo [INFO] Health check completed with exit code: %OVERALL_STATUS%
goto end

:show_help
echo.
echo 🔍 CI/CD Pipeline Advanced Health Check Script
echo.
echo Usage: %0 [OPTIONS]
echo.
echo OPTIONS:
echo     --namespace NAMESPACE    Target namespace (default: cicd-production)
echo     --timeout TIMEOUT       Timeout for operations (default: 300s)
echo     --retries RETRIES        Number of retries (default: 3)
echo     --help                   Show this help message
echo.
echo EXAMPLES:
echo     %0                                          # Check default namespace
echo     %0 --namespace cicd-dev                     # Check dev namespace
echo     %0 --namespace production --retries 5       # Check with more retries
echo.

:end
endlocal
exit /b %OVERALL_STATUS%
