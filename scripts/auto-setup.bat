@echo off
REM Automated Environment Setup and Validation

echo 🚀 CI/CD Pipeline Environment Setup
echo ====================================
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
if not exist "src\main.py" (
    echo ❌ Error: Not in the correct project directory
    echo Please run this script from the cicd-pipeline root directory
    pause
    exit /b 1
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
python cli.py check-env >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ CLI tool test failed
    echo CLI tool test failed >> %logfile%
) else (
    echo ✅ CLI tool is working
    echo CLI tool test passed >> %logfile%
)

echo 🔍 Testing Docker build...
docker build -t fastapi-app-test . >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker build test failed
    echo Docker build test failed >> %logfile%
    echo Check %logfile% for details
) else (
    echo ✅ Docker build successful
    echo Docker build test passed >> %logfile%
    
    REM Clean up test image
    docker rmi fastapi-app-test >nul 2>&1
)

echo 🔍 Testing FastAPI app...
python -c "from src.main import app; print('FastAPI import successful')" 2>nul
if %ERRORLEVEL% neq 0 (
    echo ❌ FastAPI app test failed
    echo FastAPI app test failed >> %logfile%
) else (
    echo ✅ FastAPI app imports successfully
    echo FastAPI app test passed >> %logfile%
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
    echo 4. 🚀 Deploy to dev: python cli.py deploy --env dev
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
    echo - Review: PROJECT_STATUS.md
)

echo.
echo 📚 Documentation:
echo ================
echo - Project Status: PROJECT_STATUS.md
echo - Deployment Guide: DEPLOYMENT_GUIDE.md
echo - Security Config: SECURITY_CONFIG.md

echo.
echo Environment setup summary saved to: %logfile%
echo.
pause
