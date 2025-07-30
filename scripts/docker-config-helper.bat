@echo off
REM Docker Desktop Configuration Helper

echo 🐳 Docker Desktop Configuration Helper
echo.

echo 📊 Current Docker Status:
docker info 2>nul | findstr "Total Memory"
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker is not running or accessible
    echo 💡 Please start Docker Desktop and try again
    pause
    exit /b 1
)

echo.
echo 🔍 Checking available memory...
for /f "tokens=2" %%i in ('docker info 2^>nul ^| findstr "Total Memory"') do set DOCKER_MEMORY=%%i

echo Docker Memory Available: %DOCKER_MEMORY%
echo.

echo 💡 Recommendations for Minikube:
echo   - Minimum: 4GB (4096MB) for basic functionality
echo   - Recommended: 6GB (6144MB) for smooth operation
echo   - Optimal: 8GB+ (8192MB+) for full features
echo.

echo 🔧 To increase Docker Desktop memory:
echo   1. Open Docker Desktop
echo   2. Go to Settings (gear icon)
echo   3. Select Resources ^> Advanced
echo   4. Increase Memory slider to at least 6GB
echo   5. Click "Apply ^& Restart"
echo.

echo 🚀 Current Minikube configuration options:
echo   Light:   scripts\minikube-recovery-light.bat
echo   Regular: scripts\minikube-manage.bat start
echo.

pause
