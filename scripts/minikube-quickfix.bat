@echo off
REM Minikube Quick Fix Script

echo 🔧 Minikube Quick Fix - Resolving kubectl configuration issues
echo.

echo 1️⃣ Stopping Minikube...
minikube stop

echo 2️⃣ Starting Minikube with fresh configuration...
minikube start --driver=docker --cpus=2 --memory=4096

echo 3️⃣ Updating kubectl context...
minikube update-context

echo 4️⃣ Testing kubectl connection...
kubectl cluster-info
if %ERRORLEVEL% equ 0 (
    echo ✅ kubectl is working!
) else (
    echo ❌ kubectl still has issues
    echo 💡 Try: minikube delete && minikube start
)

echo.
echo 5️⃣ Checking cluster status...
minikube status

echo.
echo 🎉 Quick fix completed!
echo.
echo 📋 Next steps:
echo   scripts\minikube-manage.bat build
echo   scripts\minikube-manage.bat deploy

pause
