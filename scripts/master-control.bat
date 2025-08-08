@echo off
REM Master CI/CD Pipeline Automation Script

echo 🎯 CI/CD Pipeline Master Control
echo =================================
echo.

REM Check if running from correct directory
if not exist "src\main.py" (
    echo ❌ Error: Please run this script from the cicd-pipeline root directory
    pause
    exit /b 1
)

echo 🚀 Welcome to the CI/CD Pipeline Control Center
echo.
echo What would you like to do?
echo.
echo 1️⃣  📊 System Diagnostics - Check system requirements
echo 2️⃣  🔧 Auto Setup - Automated environment setup
echo 3️⃣  🧪 Run Tests - Comprehensive testing suite
echo 4️⃣  🐳 Docker Setup - Configure Docker environment
echo 5️⃣  ☸️  Minikube Management - Start/stop/manage Minikube
echo 6️⃣  🏗️  Build ^& Deploy - Build and deploy application
echo 7️⃣  📊 Status Check - Check current environment status
echo 8️⃣  🔍 Troubleshoot - Diagnostic and troubleshooting tools
echo 9️⃣  📚 Documentation - Open guides and documentation
echo 🔟  🎯 Deployment Readiness - Check production readiness
echo 🅰️  📋 Generate Report - Create project completion report
echo 0️⃣  ❌ Exit
echo.

set /p choice="Enter your choice (0-9, A): "

if "%choice%"=="1" goto DIAGNOSTICS
if "%choice%"=="2" goto AUTO_SETUP
if "%choice%"=="3" goto RUN_TESTS
if "%choice%"=="4" goto DOCKER_SETUP
if "%choice%"=="5" goto MINIKUBE_MGMT
if "%choice%"=="6" goto BUILD_DEPLOY
if "%choice%"=="7" goto STATUS_CHECK
if "%choice%"=="8" goto TROUBLESHOOT
if "%choice%"=="9" goto DOCUMENTATION
if "%choice%"=="0" goto EXIT

echo Invalid choice. Please try again.
pause
goto START

:DIAGNOSTICS
echo.
echo 🔍 Running System Diagnostics...
echo =================================
call scripts\system-diagnostics.bat
goto MENU_RETURN

:AUTO_SETUP
echo.
echo 🔧 Starting Automated Setup...
echo ==============================
call scripts\auto-setup.bat
goto MENU_RETURN

:RUN_TESTS
echo.
echo 🧪 Running Test Suite...
echo ========================
call scripts\test-suite.bat
goto MENU_RETURN

:DOCKER_SETUP
echo.
echo 🐳 Docker Configuration Helper...
echo =================================
call scripts\docker-config-helper.bat
goto MENU_RETURN

:MINIKUBE_MGMT
echo.
echo ☸️  Minikube Management...
echo =========================
echo.
echo Available commands:
echo 1. Start Minikube
echo 2. Stop Minikube
echo 3. Restart Minikube
echo 4. Check Status
echo 5. Troubleshoot
echo 6. Back to main menu
echo.
set /p minikube_choice="Enter choice (1-6): "

if "%minikube_choice%"=="1" (
    call scripts\minikube-manage.bat start
) else if "%minikube_choice%"=="2" (
    call scripts\minikube-manage.bat stop
) else if "%minikube_choice%"=="3" (
    call scripts\minikube-manage.bat restart
) else if "%minikube_choice%"=="4" (
    call scripts\minikube-manage.bat status
) else if "%minikube_choice%"=="5" (
    call scripts\minikube-manage.bat troubleshoot
) else if "%minikube_choice%"=="6" (
    goto MENU_RETURN
) else (
    echo Invalid choice
    pause
)
goto MENU_RETURN

:BUILD_DEPLOY
echo.
echo 🏗️  Build ^& Deploy...
echo =====================
echo.
echo Available options:
echo 1. Build Docker image
echo 2. Start local development (docker-compose)
echo 3. Deploy to development environment
echo 4. Deploy to staging environment
echo 5. Deploy to production environment
echo 6. Back to main menu
echo.
set /p deploy_choice="Enter choice (1-6): "

if "%deploy_choice%"=="1" (
    echo Building Docker image...
    docker build -t fastapi-app .
) else if "%deploy_choice%"=="2" (
    echo Starting local development environment...
    docker-compose up --build
) else if "%deploy_choice%"=="3" (
    echo Deploying to development...
    python cli.py deploy --env dev
) else if "%deploy_choice%"=="4" (
    echo Deploying to staging...
    python cli.py deploy --env staging --approve
) else if "%deploy_choice%"=="5" (
    echo Deploying to production...
    python cli.py deploy --env prod --approve
) else if "%deploy_choice%"=="6" (
    goto MENU_RETURN
) else (
    echo Invalid choice
    pause
)
goto MENU_RETURN

:STATUS_CHECK
echo.
echo 📊 Environment Status Check...
echo ==============================
python cli.py status
echo.
echo Docker status:
docker info 2>nul | findstr "Total Memory\|CPUs\|Server Version" || echo Docker not available
echo.
echo Minikube status:
minikube status 2>nul || echo Minikube not running
echo.
echo Kubernetes context:
kubectl config current-context 2>nul || echo No Kubernetes context
echo.
pause
goto MENU_RETURN

:TROUBLESHOOT
echo.
echo 🔍 Troubleshooting Tools...
echo ===========================
echo.
echo Available tools:
echo 1. Check Docker configuration
echo 2. Test Minikube connectivity
echo 3. Validate Kubernetes manifests
echo 4. Check application health
echo 5. View recent logs
echo 6. Network diagnostics
echo 7. Back to main menu
echo.
set /p trouble_choice="Enter choice (1-7): "

if "%trouble_choice%"=="1" (
    call scripts\docker-config-helper.bat
) else if "%trouble_choice%"=="2" (
    call scripts\test-minikube.bat
) else if "%trouble_choice%"=="3" (
    echo Validating Kubernetes manifests...
    for %%f in (k8s\*.yaml) do (
        echo Checking %%f...
        kubectl apply --dry-run=client -f %%f
    )
    pause
) else if "%trouble_choice%"=="4" (
    echo Checking application health...
    python cli.py health-check
    pause
) else if "%trouble_choice%"=="5" (
    echo Recent logs:
    if exist "logs" (
        dir /od logs\*.log
        echo.
        set /p log_choice="Enter log filename to view (or press Enter to skip): "
        if not "!log_choice!"=="" (
            type "logs\!log_choice!"
        )
    ) else (
        echo No logs directory found
    )
    pause
) else if "%trouble_choice%"=="6" (
    echo Network diagnostics...
    echo Testing Docker network...
    docker network ls
    echo.
    echo Testing Minikube network...
    minikube ip 2>nul || echo Minikube not running
    echo.
    echo Testing internet connectivity...
    ping -n 1 8.8.8.8 >nul && echo Internet: OK || echo Internet: Failed
    pause
) else if "%trouble_choice%"=="7" (
    goto MENU_RETURN
) else (
    echo Invalid choice
    pause
)
goto MENU_RETURN

:DOCUMENTATION
echo.
echo 📚 Documentation ^& Guides...
echo =============================
echo.
echo Available documentation:
echo 1. Project Status ^& Next Steps (PROJECT_STATUS.md)
echo 2. Deployment Guide (DEPLOYMENT_GUIDE.md)
echo 3. Security Configuration (SECURITY_CONFIG.md)
echo 4. README (readme.md)
echo 5. Open all documentation
echo 6. Back to main menu
echo.
set /p doc_choice="Enter choice (1-6): "

if "%doc_choice%"=="1" (
    start PROJECT_STATUS.md
) else if "%doc_choice%"=="2" (
    start DEPLOYMENT_GUIDE.md
) else if "%doc_choice%"=="3" (
    start SECURITY_CONFIG.md
) else if "%doc_choice%"=="4" (
    start readme.md
) else if "%doc_choice%"=="5" (
    start PROJECT_STATUS.md
    start DEPLOYMENT_GUIDE.md
    start SECURITY_CONFIG.md
    start readme.md
) else if "%doc_choice%"=="6" (
    goto MENU_RETURN
) else (
    echo Invalid choice
    pause
)
goto MENU_RETURN

:MENU_RETURN
echo.
echo Press any key to return to main menu...
pause >nul
cls

:START
echo 🎯 CI/CD Pipeline Master Control
echo =================================
echo.
echo What would you like to do?
echo.
echo 1️⃣  📊 System Diagnostics - Check system requirements
echo 2️⃣  🔧 Auto Setup - Automated environment setup
echo 3️⃣  🧪 Run Tests - Comprehensive testing suite
echo 4️⃣  🐳 Docker Setup - Configure Docker environment
echo 5️⃣  ☸️  Minikube Management - Start/stop/manage Minikube
echo 6️⃣  🏗️  Build ^& Deploy - Build and deploy application
echo 7️⃣  📊 Status Check - Check current environment status
echo 8️⃣  🔍 Troubleshoot - Diagnostic and troubleshooting tools
echo 9️⃣  📚 Documentation - Open guides and documentation
echo 0️⃣  ❌ Exit
echo.

set /p choice="Enter your choice (0-9): "

if "%choice%"=="1" goto DIAGNOSTICS
if "%choice%"=="2" goto AUTO_SETUP
if "%choice%"=="3" goto RUN_TESTS
if "%choice%"=="4" goto DOCKER_SETUP
if "%choice%"=="5" goto MINIKUBE_MGMT
if "%choice%"=="6" goto BUILD_DEPLOY
if "%choice%"=="7" goto STATUS_CHECK
if "%choice%"=="8" goto TROUBLESHOOT
if "%choice%"=="9" goto DOCUMENTATION
if "%choice%"=="0" goto EXIT

echo Invalid choice. Please try again.
pause
goto START

:EXIT
echo.
echo 👋 Thank you for using the CI/CD Pipeline Control Center!
echo.
echo Quick reference:
echo - System status: scripts\system-diagnostics.bat
echo - Auto setup: scripts\auto-setup.bat
echo - Run tests: scripts\test-suite.bat
echo - Minikube: scripts\minikube-manage.bat
echo - CLI tool: python cli.py --help
echo.
echo 📚 Documentation:
echo - PROJECT_STATUS.md - Project overview and next steps
echo - DEPLOYMENT_GUIDE.md - Complete deployment instructions
echo - SECURITY_CONFIG.md - Security best practices
echo.
echo Happy coding! 🚀
pause
