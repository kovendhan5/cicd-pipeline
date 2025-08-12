@echo off
REM Final Launch and Validation Script for CI/CD Pipeline

echo 🎯 CI/CD Pipeline - Final Launch ^& Validation
echo ================================================
echo.

REM Set up logging
if not exist "logs" mkdir logs
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /format:value ^| findstr "="') do set datetime=%%i
set timestamp=%datetime:~0,8%-%datetime:~8,6%
set logfile=logs\final-launch-%timestamp%.log
echo Final launch and validation started at %date% %time% > %logfile%

echo 📝 Launch log: %logfile%
echo.

REM Check if we're in the right directory
if not exist "src\main.py" (
    echo ❌ Error: Not in the correct project directory
    echo Please run this script from the cicd-pipeline root directory
    pause
    exit /b 1
)

echo 🚀 Phase 1: Final Environment Validation
echo =========================================

echo 🔍 Running comprehensive system check...
call scripts\deployment-readiness.bat > temp_readiness.log 2>&1

REM Check readiness results
findstr "DEPLOYMENT READY" temp_readiness.log >nul
if %ERRORLEVEL% equ 0 (
    echo ✅ System is DEPLOYMENT READY!
    echo System ready for launch >> %logfile%
) else (
    findstr "MOSTLY READY" temp_readiness.log >nul
    if %ERRORLEVEL% equ 0 (
        echo ⚠️  System is MOSTLY READY - proceeding with caution
        echo System mostly ready >> %logfile%
    ) else (
        echo ❌ System NOT READY for deployment
        echo Please address issues before launching
        echo System not ready >> %logfile%
        type temp_readiness.log
        del temp_readiness.log
        pause
        exit /b 1
    )
)
del temp_readiness.log
echo.

echo 🎯 Phase 2: Launch Options
echo ===========================

echo Choose your launch scenario:
echo.
echo 1️⃣  🐳 Local Development Launch (Docker Compose)
echo 2️⃣  ☸️  Minikube Deployment Launch (Local Kubernetes)
echo 3️⃣  🌐 Cloud Deployment Preparation
echo 4️⃣  🧪 Full Testing Suite
echo 5️⃣  📊 Generate Final Report
echo 6️⃣  🎯 Interactive Setup (Master Control)
echo 0️⃣  ❌ Exit
echo.

set /p launch_choice="Enter your choice (0-6): "

if "%launch_choice%"=="1" goto LOCAL_DOCKER
if "%launch_choice%"=="2" goto MINIKUBE_DEPLOY
if "%launch_choice%"=="3" goto CLOUD_PREP
if "%launch_choice%"=="4" goto FULL_TEST
if "%launch_choice%"=="5" goto FINAL_REPORT
if "%launch_choice%"=="6" goto MASTER_CONTROL
if "%launch_choice%"=="0" goto EXIT

echo Invalid choice. Please try again.
pause
goto LAUNCH_OPTIONS

:LOCAL_DOCKER
echo.
echo 🐳 Local Development Launch
echo ===========================

echo 🔍 Checking Docker environment...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker daemon not running
    echo 💡 Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo ⏳ Waiting for Docker to start...
    :DOCKER_WAIT_LOCAL
    timeout /t 10 /nobreak >nul
    docker info >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Still waiting for Docker...
        goto DOCKER_WAIT_LOCAL
    )
    echo ✅ Docker started successfully
) else (
    echo ✅ Docker is running
)

echo.
echo 🏗️  Building and launching application...
echo docker-compose up --build >> %logfile%
docker-compose up --build
goto LAUNCH_SUCCESS

:MINIKUBE_DEPLOY
echo.
echo ☸️  Minikube Deployment Launch
echo =============================

echo 🔍 Checking Minikube status...
minikube status >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  Minikube not running. Starting Minikube...
    call scripts\minikube-manage.bat start
) else (
    echo ✅ Minikube is running
)

echo.
echo 🚀 Deploying to Minikube...
python cli.py deploy --env dev >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Deployment failed. Check logs for details.
    echo Minikube deployment failed >> %logfile%
    pause
    goto LAUNCH_OPTIONS
) else (
    echo ✅ Successfully deployed to Minikube
    echo Minikube deployment successful >> %logfile%
)

echo.
echo 🔍 Getting application URL...
for /f %%i in ('minikube ip') do set MINIKUBE_IP=%%i
echo 🌐 Application URL: http://%MINIKUBE_IP%:30000
echo Application URL: http://%MINIKUBE_IP%:30000 >> %logfile%

echo.
echo 📊 Checking deployment status...
kubectl get pods -l app=fastapi-app
goto LAUNCH_SUCCESS

:CLOUD_PREP
echo.
echo 🌐 Cloud Deployment Preparation
echo ===============================

echo 📋 Cloud deployment checklist:
echo.
echo ✅ 1. GitHub Repository Setup:
echo    - Code pushed to GitHub
echo    - Repository secrets configured
echo    - Workflows validated
echo.
echo ✅ 2. Container Registry:
echo    - Docker Hub / GitHub Container Registry
echo    - Registry credentials in GitHub secrets
echo.
echo ✅ 3. Cloud Infrastructure:
echo    - Kubernetes cluster (EKS/AKS/GKE)
echo    - kubectl configured for cluster
echo    - Monitoring namespace created
echo.
echo ✅ 4. Secrets Configuration:
echo    Required GitHub Secrets:
echo    - REGISTRY_USERNAME
echo    - REGISTRY_PASSWORD  
echo    - KUBECONFIG_DEV (base64 encoded)
echo    - KUBECONFIG_STAGING (base64 encoded)
echo    - KUBECONFIG_PROD (base64 encoded)
echo    - SLACK_WEBHOOK (optional)
echo.
echo 📚 Next Steps:
echo 1. Review DEPLOYMENT_GUIDE.md
echo 2. Configure GitHub repository secrets
echo 3. Create cloud Kubernetes clusters
echo 4. Push code to trigger CI/CD pipeline
echo.

echo Cloud preparation guide displayed >> %logfile%
pause
goto LAUNCH_OPTIONS

:FULL_TEST
echo.
echo 🧪 Full Testing Suite
echo =====================

echo 🔍 Running comprehensive test suite...
call scripts\test-suite.bat
echo.
echo Test suite completed. Review results above.
echo Full test suite completed >> %logfile%
pause
goto LAUNCH_OPTIONS

:FINAL_REPORT
echo.
echo 📊 Generating Final Project Report
echo ==================================

call scripts\generate-completion-report.bat
echo Final report generated >> %logfile%
goto LAUNCH_OPTIONS

:MASTER_CONTROL
echo.
echo 🎯 Launching Master Control Center
echo ==================================

call scripts\master-control.bat
echo Master control session completed >> %logfile%
goto LAUNCH_OPTIONS

:LAUNCH_SUCCESS
echo.
echo 🎉 Launch Successful!
echo ====================

echo ✅ Your CI/CD pipeline is now running!
echo Launch completed successfully at %date% %time% >> %logfile%

echo.
echo 🔧 Useful Commands:
echo ==================
if "%launch_choice%"=="1" (
    echo - View logs: docker-compose logs -f
    echo - Stop: docker-compose down
    echo - Access app: http://localhost:8000
) else if "%launch_choice%"=="2" (
    echo - View logs: kubectl logs -l app=fastapi-app -f
    echo - Status: kubectl get pods
    echo - Access app: http://%MINIKUBE_IP%:30000
)

echo.
echo 📚 Documentation:
echo ================
echo - Project Status: PROJECT_STATUS.md
echo - Deployment Guide: DEPLOYMENT_GUIDE.md
echo - Security Config: SECURITY_CONFIG.md
echo - Success Summary: FINAL_SUCCESS.md

echo.
echo 🎯 Next Steps:
echo =============
echo 1. Test your application
echo 2. Monitor performance
echo 3. Deploy to staging/production
echo 4. Set up monitoring alerts
echo 5. Train your team

echo.
echo 📊 Launch Summary:
echo =================
echo - Launch Type: %launch_choice%
echo - Status: Successful
echo - Log File: %logfile%
echo - Timestamp: %date% %time%

goto FINAL_MESSAGE

:LAUNCH_OPTIONS
goto LAUNCH_OPTIONS

:EXIT
echo.
echo 👋 Exiting CI/CD Pipeline Launch Script
echo Session ended >> %logfile%
goto FINAL_MESSAGE

:FINAL_MESSAGE
echo.
echo 🏆 CI/CD Pipeline Project Complete!
echo ===================================
echo.
echo Your enterprise-grade CI/CD pipeline is ready for action!
echo.
echo 📞 Need Help?
echo - Run: scripts\master-control.bat
echo - Check: PROJECT_STATUS.md
echo - Troubleshoot: scripts\system-diagnostics.bat
echo.
echo 🚀 Happy Coding and Deploying!
echo.
pause
