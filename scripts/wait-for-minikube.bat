@echo off
REM Simple Minikube status checker

echo 🔍 Checking Minikube startup progress...
echo.

:check_loop
echo ⏳ Checking cluster status...
minikube status | findstr "Running"
if %ERRORLEVEL% equ 0 (
    echo ✅ Cluster appears to be running!
    goto success
)

echo 💤 Waiting 10 seconds...
timeout /t 10 /nobreak >nul
goto check_loop

:success
echo.
echo 📊 Full Status:
minikube status
echo.
echo 🎉 Minikube cluster is ready!
echo.
echo 📋 Next steps:
echo   1. Configure kubectl: minikube update-context
echo   2. Check nodes: kubectl get nodes
echo   3. Build app: scripts\minikube-manage.bat build
echo   4. Deploy app: scripts\minikube-manage.bat deploy

pause
