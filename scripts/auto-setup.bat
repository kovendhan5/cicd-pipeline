@echo off
REM Automated Environment Setup and Validation

echo 🚀 CI/CD Pipeline Environment Setup
echo =====================================
echo.

REM Create logs directory if it doesn't exist
if not exist "logs" mkdir logs

REM Set log file with timestamp
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /format:value ^| findstr "="') do set datetime=%%i
set timestamp=%datetime:~0,8%-%datetime:~8,6%
set logfile=logs\setup-%timestamp%.log

echo 📝 Logging to: %logfile%
echo Starting environment setup at %date% %time% > %logfile%
echo.

echo 🔍 Step 1: Environment Validation
echo =================================

REM Check if we're in the right directory
if not exist "app\main.py" (
    if not exist "src\main.py" (
        echo ❌ Error: Not in the correct project directory
        echo Please run this script from the cicd-pipeline root directory
        echo Expected to find either app\main.py or src\main.py
        pause
        exit /b 1
    )
)

echo ✅ Confirmed: In correct project directory >> %logfile%
echo ✅ Confirmed: In correct project directory
echo.

echo 🐳 Step 2: Docker Environment
echo =============================

REM Check Docker
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker not found. Please install Docker Desktop first.
    echo Docker installation required >> %logfile%
    pause
    exit /b 1
)

echo ✅ Docker is installed
echo Docker version check passed >> %logfile%

REM Check if Docker daemon is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker daemon not running. Starting Docker Desktop...
    echo Starting Docker Desktop... >> %logfile%
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    echo ⏳ Waiting for Docker to start (this may take a few minutes)...
    :DOCKER_WAIT
    timeout /t 10 /nobreak >nul
    docker info >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Still waiting for Docker...
        goto DOCKER_WAIT
    )
    echo ✅ Docker Desktop started successfully
    echo Docker Desktop started >> %logfile%
) else (
    echo ✅ Docker daemon is running
    echo Docker daemon confirmed running >> %logfile%
)
echo.

echo 🐍 Step 3: Python Environment
echo ==============================

REM Check Python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not found. Please install Python 3.8+ first.
    echo Python installation required >> %logfile%
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo ✅ Python %PYTHON_VERSION% found
echo Python %PYTHON_VERSION% confirmed >> %logfile%

REM Check if virtual environment exists
if not exist "venv" (
    echo 📦 Creating Python virtual environment...
    echo Creating virtual environment >> %logfile%
    python -m venv venv
    if %ERRORLEVEL% neq 0 (
        echo ❌ Failed to create virtual environment
        echo Virtual environment creation failed >> %logfile%
        pause
        exit /b 1
    )
    echo ✅ Virtual environment created
    echo Virtual environment created successfully >> %logfile%
) else (
    echo ✅ Virtual environment already exists
    echo Virtual environment exists >> %logfile%
)

REM Activate virtual environment
echo 🔧 Activating virtual environment...
call venv\Scripts\activate.bat
if %ERRORLEVEL% neq 0 (
    echo ❌ Failed to activate virtual environment
    echo Virtual environment activation failed >> %logfile%
    pause
    exit /b 1
)
echo ✅ Virtual environment activated
echo Virtual environment activated >> %logfile%

REM Install/upgrade pip
echo 📦 Upgrading pip...
python -m pip install --upgrade pip >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  Warning: Failed to upgrade pip
    echo Pip upgrade failed >> %logfile%
) else (
    echo ✅ Pip upgraded successfully
    echo Pip upgraded >> %logfile%
)

REM Install requirements
echo 📦 Installing Python dependencies...
echo Installing Python dependencies >> %logfile%
if exist "requirements.txt" (
    pip install -r requirements.txt >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Failed to install some dependencies
        echo Dependencies installation had errors >> %logfile%
        echo Check %logfile% for details
    ) else (
        echo ✅ All dependencies installed successfully
        echo Dependencies installed successfully >> %logfile%
    )
) else (
    echo ⚠️  requirements.txt not found, skipping dependency installation
    echo requirements.txt not found >> %logfile%
)
echo.

echo ☸️  Step 4: Kubernetes Environment
echo ==================================

REM Check kubectl
kubectl version --client >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  kubectl not found - Kubernetes features will be limited
    echo kubectl not found >> %logfile%
) else (
    echo ✅ kubectl is available
    echo kubectl confirmed >> %logfile%
    
    REM Check Helm
    helm version >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Helm not found - Helm deployments unavailable
        echo Helm not found >> %logfile%
    ) else (
        echo ✅ Helm is available
        echo Helm confirmed >> %logfile%
    )
    
    REM Check Minikube
    minikube version >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Minikube not found - local Kubernetes testing unavailable
        echo Minikube not found >> %logfile%
    ) else (
        echo ✅ Minikube is available
        echo Minikube confirmed >> %logfile%
        
        REM Check Minikube status
        minikube status >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ⏸️  Minikube cluster not running
            echo 💡 To start: scripts\minikube-manage.bat start
            echo Minikube cluster not running >> %logfile%
        ) else (
            echo ✅ Minikube cluster is running
            echo Minikube cluster running >> %logfile%
        )
    )
)
echo.

echo 🧪 Step 5: Environment Testing
echo ===============================

echo 🔍 Testing CLI tool...
if exist "cli.py" (
    python cli.py check-env >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ CLI tool test failed
        echo CLI tool test failed >> %logfile%
    ) else (
        echo ✅ CLI tool is working
        echo CLI tool test passed >> %logfile%
    )
) else (
    echo ⚠️  CLI tool not found, skipping test
    echo CLI tool not found >> %logfile%
)

echo 🔍 Testing Docker build...
docker build -t cicd-pipeline-test . >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker build test failed
    echo Docker build test failed >> %logfile%
    echo Check %logfile% for details
) else (
    echo ✅ Docker build successful
    echo Docker build test passed >> %logfile%
    
    REM Clean up test image
    docker rmi cicd-pipeline-test >nul 2>&1
)

echo 🔍 Testing FastAPI app...
if exist "app\main.py" (
    python -c "from app.main import app; print('FastAPI import successful')" 2>nul
) else if exist "src\main.py" (
    python -c "from src.main import app; print('FastAPI import successful')" 2>nul
) else (
    echo ⚠️  FastAPI main.py not found
    goto skip_fastapi_test
)

if %ERRORLEVEL% neq 0 (
    echo ❌ FastAPI app test failed
    echo FastAPI app test failed >> %logfile%
) else (
    echo ✅ FastAPI app imports successfully
    echo FastAPI app test passed >> %logfile%
)

:skip_fastapi_test

echo 🔍 Testing Helm chart...
if exist "helm\cicd-pipeline\Chart.yaml" (
    helm lint helm\cicd-pipeline >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Helm chart validation failed
        echo Helm chart validation failed >> %logfile%
    ) else (
        echo ✅ Helm chart is valid
        echo Helm chart validation passed >> %logfile%
    )
) else (
    echo ⚠️  Helm chart not found, skipping validation
    echo Helm chart not found >> %logfile%
)

echo 🔍 Testing environment configuration...
if exist "environments\values-dev.yaml" (
    echo ✅ Environment configurations found
    echo Environment configurations found >> %logfile%
) else (
    echo ⚠️  Environment configurations not found
    echo Environment configurations not found >> %logfile%
)
echo.

echo 📊 Step 6: Environment Summary
echo ===============================

echo 🎯 Setup Results:
echo ================
echo Environment setup completed at %date% %time% >> %logfile%

REM Count successes and failures
findstr /c:"✅" %logfile% >temp_success.txt
for /f %%i in ('find /c /v "" ^< temp_success.txt') do set SUCCESS_COUNT=%%i
del temp_success.txt

findstr /c:"❌" %logfile% >temp_errors.txt
for /f %%i in ('find /c /v "" ^< temp_errors.txt') do set ERROR_COUNT=%%i
del temp_errors.txt

echo Successful checks: %SUCCESS_COUNT%
echo Failed checks: %ERROR_COUNT%
echo Full log: %logfile%

echo.
echo 🚀 Next Steps:
echo =============

if %ERROR_COUNT% equ 0 (
    echo ✅ Environment setup completed successfully!
    echo.
    echo Ready to proceed with:
    echo 1. 🐳 Start local development: docker-compose up --build
    echo 2. ☸️  Start Minikube: scripts\minikube-manage.bat start
    echo 3. 🧪 Run tests: python -m pytest tests/
    echo 4. 🚀 Deploy with Helm: helm install cicd-pipeline helm\cicd-pipeline
    echo 5. 📊 Validate pipeline: scripts\validate-complete-pipeline.bat
    echo 6. 🎯 Production deploy: scripts\deploy-production.bat --help
    echo.
    echo 🔗 Quick Commands:
    echo - System diagnostics: scripts\system-diagnostics.bat
    echo - Complete validation: scripts\validate-complete-pipeline.bat
    echo - Production deployment: scripts\deploy-production.bat
) else (
    echo ⚠️  Setup completed with %ERROR_COUNT% issues
    echo.
    echo Please address the following:
    echo 1. Review the log file: %logfile%
    echo 2. Install missing prerequisites
    echo 3. Re-run this setup script
    echo.
    echo For help:
    echo - Run: scripts\system-diagnostics.bat
    echo - Review: PROJECT_STATUS_FINAL.md
    echo - Quick Setup: QUICK_SETUP_GUIDE.md
)

echo.
echo 📚 Documentation:
echo ================
echo - Project Status: PROJECT_STATUS_FINAL.md
echo - Quick Setup Guide: QUICK_SETUP_GUIDE.md
echo - Production Kit: PRODUCTION_DEPLOYMENT_KIT.md
echo - Deployment Checklist: DEPLOYMENT_CHECKLIST.md
echo - Helm Guide: HELM_DEPLOYMENT_GUIDE.md

echo.
echo 🏆 Advanced Features Available:
echo ===============================
echo - GitOps with ArgoCD (gitops\ directory)
echo - Multi-environment deployments (environments\ directory)
echo - Custom Grafana dashboards (monitoring\dashboards\)
echo - Cross-platform scripts (Windows + Linux/macOS)
echo - Comprehensive validation tools
echo - Production-ready security configurations

echo.
echo Environment setup summary saved to: %logfile%
echo.
echo 🎯 Next Actions:
echo ===============
echo 1. Review setup log: %logfile%
echo 2. Run system diagnostics: scripts\system-diagnostics.bat
echo 3. Follow quick setup: QUICK_SETUP_GUIDE.md
echo 4. Deploy locally: docker-compose up --build
echo.
pause
