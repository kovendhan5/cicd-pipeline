@echo off
REM Complete Minikube Reset and Setup

echo 🔧 Complete Minikube Reset and Setup
echo This will completely reset Minikube and start fresh
echo.

set /p confirm="Do you want to proceed? This will delete your current cluster (y/n): "
if /i not "%confirm%"=="y" exit /b 0



echo.
echo 1️⃣ Deleting existing cluster completely...
minikube delete --all --purge

echo 2️⃣ Waiting for cleanup...
timeout /t 5 /nobreak >nul

echo 3️⃣ Starting fresh Minikube cluster...
minikube start --driver=docker --cpus=2 --memory=4096 --kubernetes-version=stable

echo 4️⃣ Enabling essential addons...
minikube addons enable ingress
minikube addons enable dashboard
minikube addons enable storage-provisioner

echo 5️⃣ Configuring kubectl...
minikube update-context

echo 6️⃣ Testing connection...
kubectl cluster-info
if %ERRORLEVEL% equ 0 (
    echo ✅ kubectl is working correctly!
    echo.
    echo 📊 Cluster Information:
    kubectl get nodes
    echo.
    echo 🎉 Minikube is ready for use!
    echo.
    echo 📋 Next steps:
    echo   1. Build your app: scripts\minikube-manage.bat build
    echo   2. Deploy your app: scripts\minikube-manage.bat deploy
    echo   3. Access dashboard: scripts\minikube-manage.bat dashboard
) else (
    echo ❌ kubectl connection failed
    echo 💡 Manual steps:
    echo   1. Check Docker Desktop is running
    echo   2. Run: minikube delete
    echo   3. Run: minikube start --driver=docker
    echo   4. Run: minikube update-context
)

echo.
pause
