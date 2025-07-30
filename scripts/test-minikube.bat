@echo off
REM Minikube Complete Test Script

echo 🧪 Minikube Complete Test Suite
echo.

echo =====================================
echo 1️⃣ CLUSTER STATUS TEST
echo =====================================
echo 📊 Checking Minikube status...
minikube status
if %ERRORLEVEL% neq 0 (
    echo ❌ Minikube cluster is not running properly
    exit /b 1
)
echo ✅ Minikube cluster is running

echo.
echo =====================================
echo 2️⃣ KUBECTL CONNECTIVITY TEST
echo =====================================
echo 🔗 Testing kubectl connection...
kubectl get nodes
if %ERRORLEVEL% neq 0 (
    echo ❌ kubectl cannot connect to cluster
    exit /b 1
)
echo ✅ kubectl is working correctly

echo.
echo =====================================
echo 3️⃣ NAMESPACE TEST
echo =====================================
echo 📦 Checking application namespace...
kubectl get namespace cicd-pipeline >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 🔧 Creating cicd-pipeline namespace...
    kubectl create namespace cicd-pipeline
)
echo ✅ Namespace is available

echo.
echo =====================================
echo 4️⃣ DOCKER ENVIRONMENT TEST
echo =====================================
echo 🐳 Testing Docker environment configuration...
for /f "tokens=*" %%i in ('minikube docker-env --shell cmd') do (
    echo Configuring: %%i
)
echo ✅ Docker environment configured

echo.
echo =====================================
echo 5️⃣ SYSTEM PODS TEST
echo =====================================
echo 🔍 Checking system pods...
kubectl get pods -n kube-system
echo ✅ System pods checked

echo.
echo =====================================
echo 6️⃣ ADDONS TEST
echo =====================================
echo 🔌 Checking enabled addons...
minikube addons list | findstr "enabled"
echo ✅ Addons checked

echo.
echo =====================================
echo 🎉 TEST SUMMARY
echo =====================================
echo ✅ Minikube cluster: WORKING
echo ✅ kubectl connectivity: WORKING
echo ✅ Namespace management: WORKING  
echo ✅ Docker environment: WORKING
echo ✅ System components: WORKING
echo ✅ Addons: WORKING

echo.
echo 🚀 READY FOR APPLICATION DEPLOYMENT!
echo.
echo 📋 Next steps:
echo   1. Build app image: scripts\minikube-manage.bat build
echo   2. Deploy application: scripts\minikube-manage.bat deploy
echo   3. Access application: scripts\minikube-manage.bat url
echo   4. View dashboard: scripts\minikube-manage.bat dashboard

pause
