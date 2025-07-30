@echo off
REM Lightweight Minikube Recovery Script for resource-constrained environments

echo 🚨 Lightweight Minikube Recovery Script
echo This will set up Minikube with reduced resource requirements

echo.
echo 🛑 Stopping any running Minikube cluster...
minikube stop >nul 2>&1

echo 🗑️ Deleting existing cluster...
minikube delete >nul 2>&1

echo ⏳ Waiting for cleanup...
timeout /t 3 /nobreak >nul

echo 🔄 Resetting Docker environment...
minikube docker-env -u --shell cmd >nul 2>&1

echo 🚀 Starting lightweight Minikube cluster...
echo 💡 Using reduced memory (6GB) and 2 CPUs for compatibility...
minikube start --driver=docker --cpus=2 --memory=6144 --disk-size=20g
if %ERRORLEVEL% neq 0 (
    echo ❌ Failed with 6GB, trying 4GB...
    minikube start --driver=docker --cpus=2 --memory=4096 --disk-size=20g
    if %ERRORLEVEL% neq 0 (
        echo ❌ Failed with 4GB, trying minimal setup (3GB)...
        minikube start --driver=docker --cpus=2 --memory=3072 --disk-size=15g
        if %ERRORLEVEL% neq 0 (
            echo ❌ All attempts failed. Please:
            echo   1. Close other applications to free memory
            echo   2. Increase Docker Desktop memory limit
            echo   3. Try running as Administrator
            pause
            exit /b 1
        )
    )
)

if %ERRORLEVEL% equ 0 (
    echo ✅ Minikube cluster started successfully!
    echo.
    echo 📊 Cluster Status:
    minikube status
    echo.
    echo 🔗 Next steps:
    echo   1. Run: scripts\minikube-manage.bat fix
    echo   2. Then: scripts\minikube-manage.bat build
    echo   3. Finally: scripts\minikube-manage.bat deploy
    echo.
    echo 💡 For better performance, consider:
    echo   - Closing other applications
    echo   - Increasing Docker Desktop memory to 8GB+
) else (
    echo ❌ Failed to start Minikube cluster
    echo 💡 Please check Docker Desktop settings
)

pause
