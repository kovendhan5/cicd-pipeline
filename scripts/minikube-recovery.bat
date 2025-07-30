@echo off
REM Quick Minikube Recovery Script

echo 🚨 Minikube Recovery Script
echo This will clean up and restart your Minikube environment

echo.
echo 🛑 Stopping any running Minikube cluster...
minikube stop >nul 2>&1

echo 🗑️ Deleting existing cluster...
minikube delete >nul 2>&1

echo ⏳ Waiting for cleanup...
timeout /t 3 /nobreak >nul

echo 🔄 Resetting Docker environment...
minikube docker-env -u --shell cmd >nul 2>&1

echo 🚀 Starting fresh Minikube cluster...
minikube start --driver=docker --cpus=4 --memory=8192
if %ERRORLEVEL% neq 0 (
    echo ❌ Failed with Docker driver, trying hyperv...
    minikube start --driver=hyperv --cpus=4 --memory=8192
)

if %ERRORLEVEL% equ 0 (
    echo ✅ Minikube cluster started successfully!
    echo.
    echo 📊 Cluster Status:
    minikube status
    echo.
    echo 🔗 Next steps:
    echo   1. Run: scripts\minikube-setup-fixed.bat
    echo   2. Or use: scripts\minikube-manage.bat [command]
) else (
    echo ❌ Failed to start Minikube cluster
    echo 💡 Please check:
    echo   1. Docker Desktop is running
    echo   2. Hyper-V is enabled (Windows features)
    echo   3. Your system has enough resources (4GB+ RAM free)
)

pause
