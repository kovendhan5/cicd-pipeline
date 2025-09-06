@echo off
REM Complete System Setup and Diagnostics

echo 🔧 CI/CD Pipeline System Setup ^& Diagnostics
echo ==============================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %echo 📞 Need Help?
echo =============
echo - Review: QUICK_SETUP_GUIDE.md
echo - Project Status: PROJECT_FINAL_SUMMARY.md
echo - Deployment Guide: PRODUCTION_DEPLOYMENT_KIT.md
echo - Complete Checklist: DEPLOYMENT_CHECKLIST.md
echo - Helm Guide: HELM_DEPLOYMENT_GUIDE.md
echo - Troubleshooting: scripts\minikube-manage.bat troubleshoot

echo.
echo 🏆 Advanced Features Available:
echo ===============================
echo - GitOps with ArgoCD
echo - Multi-environment Helm deployments
echo - Custom Grafana monitoring dashboards
echo - Automated backup and rollback procedures
echo - Cross-platform deployment scripts
echo - Security scanning and compliance checks

echo.
echo 🎯 Quick Commands:
echo ==================
echo For immediate testing:
echo   scripts\validate-complete-pipeline.bat
echo.
echo For production deployment:
echo   scripts\deploy-production.bat --help
echo.
echo For development environment:
echo   docker-compose up --build
echo   minikube start
echo   scripts\test-minikube.batEVEL% neq 0 (
    echo ⚠️  WARNING: Not running as administrator
    echo Some operations may require elevated privileges
    echo.
)

echo 📊 System Analysis:
echo ==================

REM System Information
echo 🖥️  System Information:
wmic computersystem get Manufacturer,Model,TotalPhysicalMemory /format:value | findstr "=" > temp_system.txt
for /f "tokens=2 delims==" %%i in ('findstr "Manufacturer" temp_system.txt') do set MANUFACTURER=%%i
for /f "tokens=2 delims==" %%i in ('findstr "Model" temp_system.txt') do set MODEL=%%i
for /f "tokens=2 delims==" %%i in ('findstr "TotalPhysicalMemory" temp_system.txt') do set TOTAL_RAM=%%i
del temp_system.txt

set /a TOTAL_RAM_GB=%TOTAL_RAM:~0,-9%
echo   Manufacturer: %MANUFACTURER%
echo   Model: %MODEL%
echo   Total RAM: %TOTAL_RAM_GB%GB
echo.

REM CPU Information
echo 🔲 CPU Information:
wmic cpu get Name,NumberOfCores,NumberOfLogicalProcessors /format:value | findstr "=" > temp_cpu.txt
for /f "tokens=2 delims==" %%i in ('findstr "Name" temp_cpu.txt') do set CPU_NAME=%%i
for /f "tokens=2 delims==" %%i in ('findstr "NumberOfCores" temp_cpu.txt') do set CPU_CORES=%%i
for /f "tokens=2 delims==" %%i in ('findstr "NumberOfLogicalProcessors" temp_cpu.txt') do set CPU_THREADS=%%i
del temp_cpu.txt
echo   CPU: %CPU_NAME%
echo   Cores: %CPU_CORES%
echo   Threads: %CPU_THREADS%
echo.

REM Disk Space
echo 💾 Storage Information:
for /f "tokens=3" %%i in ('dir C:\ /-c ^| findstr "bytes free"') do set FREE_SPACE=%%i
set /a FREE_SPACE_GB=%FREE_SPACE:~0,-9%
echo   Free Space on C:\: %FREE_SPACE_GB%GB
if %FREE_SPACE_GB% LSS 20 (
    echo   ⚠️  WARNING: Low disk space - less than 20GB free
) else (
    echo   ✅ Adequate disk space available
)
echo.

echo 🔍 Prerequisites Check:
echo =======================

REM Check Docker
echo 🐳 Docker Desktop:
docker --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=3" %%i in ('docker --version') do set DOCKER_VERSION=%%i
    echo   ✅ Docker installed - Version %DOCKER_VERSION%
    
    REM Check if Docker daemon is running
    docker info >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo   ✅ Docker daemon is running
        
        REM Get Docker resource allocation
        for /f "tokens=3" %%i in ('docker info 2^>nul ^| findstr "Total Memory"') do set DOCKER_MEMORY=%%i
        for /f "tokens=2" %%i in ('docker info 2^>nul ^| findstr "CPUs"') do set DOCKER_CPUS=%%i
        echo   Docker Memory: %DOCKER_MEMORY%
        echo   Docker CPUs: %DOCKER_CPUS%
    ) else (
        echo   ❌ Docker daemon not running - please start Docker Desktop
    )
) else (
    echo   ❌ Docker not installed or not in PATH
    echo   💡 Download from: https://www.docker.com/products/docker-desktop
)
echo.

REM Check kubectl
echo ☸️  Kubernetes CLI (kubectl):
kubectl version --client >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=3" %%i in ('kubectl version --client --short') do set KUBECTL_VERSION=%%i
    echo   ✅ kubectl installed - %KUBECTL_VERSION%
) else (
    echo   ❌ kubectl not installed or not in PATH
    echo   💡 Install via: choco install kubernetes-cli
)
echo.

REM Check Minikube
echo 🎯 Minikube:
minikube version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=3" %%i in ('minikube version ^| findstr "minikube version"') do set MINIKUBE_VERSION=%%i
    echo   ✅ Minikube installed - %MINIKUBE_VERSION%
    
    REM Check Minikube status
    minikube status >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo   ✅ Minikube cluster is running
        minikube ip >nul 2>&1
        if %ERRORLEVEL% equ 0 (
            for /f %%i in ('minikube ip') do set MINIKUBE_IP=%%i
            echo   Cluster IP: %MINIKUBE_IP%
        )
    ) else (
        echo   ⏸️  Minikube cluster is stopped
    )
) else (
    echo   ❌ Minikube not installed or not in PATH
    echo   💡 Install via: choco install minikube
)
echo.

REM Check Python
echo 🐍 Python:
python --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=2" %%i in ('python --version') do set PYTHON_VERSION=%%i
    echo   ✅ Python installed - %PYTHON_VERSION%
    
    REM Check pip
    pip --version >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo   ✅ pip available
    ) else (
        echo   ❌ pip not available
    )
) else (
    echo   ❌ Python not installed or not in PATH
    echo   💡 Download from: https://www.python.org/downloads/
)
echo.

REM Check Git
echo 📝 Git:
git --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=3" %%i in ('git --version') do set GIT_VERSION=%%i
    echo   ✅ Git installed - %GIT_VERSION%
) else (
    echo   ❌ Git not installed or not in PATH
    echo   💡 Download from: https://git-scm.com/download/win
)
echo.

REM Check Node.js (optional)
echo 📦 Node.js (Optional):
node --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f %%i in ('node --version') do set NODE_VERSION=%%i
    echo   ✅ Node.js installed - %NODE_VERSION%
) else (
    echo   ⚠️  Node.js not installed (optional for some tools)
    echo   💡 Download from: https://nodejs.org/
)
echo.

echo 🚀 Recommendations:
echo ===================

echo 📋 System Requirements Status:
if %TOTAL_RAM_GB% LSS 8 (
    echo   ❌ RAM: %TOTAL_RAM_GB%GB ^(Minimum 8GB recommended^)
) else if %TOTAL_RAM_GB% LSS 16 (
    echo   ⚠️  RAM: %TOTAL_RAM_GB%GB ^(16GB+ recommended for optimal performance^)
) else (
    echo   ✅ RAM: %TOTAL_RAM_GB%GB ^(Excellent^)
)

if %CPU_CORES% LSS 4 (
    echo   ⚠️  CPU: %CPU_CORES% cores ^(4+ cores recommended^)
) else (
    echo   ✅ CPU: %CPU_CORES% cores ^(Good^)
)

if %FREE_SPACE_GB% LSS 20 (
    echo   ❌ Storage: %FREE_SPACE_GB%GB free ^(20GB+ recommended^)
) else (
    echo   ✅ Storage: %FREE_SPACE_GB%GB free ^(Good^)
)
echo.

echo 🔧 Setup Actions:
echo =================

echo 1. 📥 Install Missing Prerequisites:
docker --version >nul 2>&1 || echo    - Install Docker Desktop: https://www.docker.com/products/docker-desktop
kubectl version --client >nul 2>&1 || echo    - Install kubectl: choco install kubernetes-cli
minikube version >nul 2>&1 || echo    - Install Minikube: choco install minikube
python --version >nul 2>&1 || echo    - Install Python: https://www.python.org/downloads/
git --version >nul 2>&1 || echo    - Install Git: https://git-scm.com/download/win

echo.
echo 2. 🐳 Configure Docker Desktop:
echo    - Allocate 6-8GB RAM minimum
echo    - Enable Kubernetes ^(optional^)
echo    - Configure resource limits

echo.
echo 3. ☸️  Initialize Minikube:
echo    - Run: scripts\minikube-manage.bat start
echo    - Or: minikube start --driver=docker --cpus=4 --memory=6144

echo.
echo 4. 🛠️  Setup Development Environment:
echo    - Run: scripts\dev-setup.bat
echo    - Install Python dependencies: pip install -r requirements.txt

echo.
echo 5. 🧪 Test Setup:
echo    - Run: python cli.py check-env
echo    - Run: docker-compose up --build
echo    - Run: scripts\test-minikube.bat

echo.
echo 6. 📊 Performance Testing:
echo    - Run: scripts\validate-complete-pipeline.bat
echo    - Load test: k6 run tests\load-test.js
echo    - Monitor: kubectl top pods --all-namespaces

echo.
echo 7. 🚀 Production Deployment:
echo    - Run: scripts\deploy-production.bat --dry-run
echo    - Deploy: scripts\deploy-production.bat --namespace production
echo    - Monitor: kubectl get pods -n production -w

echo.
echo 📞 Need Help?
echo =============
echoo - Review: PROJECT_STATUS.md
echo - Deployment Guide: DEPLOYMENT_GUIDE.md
echo - Security Config: SECURITY_CONFIG.md
echo - Troubleshooting: scripts\minikube-manage.bat troubleshoot

echo.
echo Press any key to continue...
pause >nul
