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
echo 🔍 Checking Docker configuration...
for /f "tokens=3" %%i in ('docker info 2^>nul ^| findstr "Total Memory"') do set DOCKER_MEMORY=%%i
for /f "tokens=2" %%i in ('docker info 2^>nul ^| findstr "CPUs"') do set DOCKER_CPUS=%%i
for /f "tokens=3" %%i in ('docker info 2^>nul ^| findstr "Server Version"') do set DOCKER_VERSION=%%i

echo Docker Version: %DOCKER_VERSION%
echo Docker CPUs: %DOCKER_CPUS%
echo Docker Memory: %DOCKER_MEMORY%

echo.
echo 📋 System Resources Analysis:
wmic computersystem get TotalPhysicalMemory /format:value | findstr "=" > temp_mem.txt
for /f "tokens=2 delims==" %%i in (temp_mem.txt) do set TOTAL_RAM=%%i
del temp_mem.txt

set /a TOTAL_RAM_GB=%TOTAL_RAM:~0,-9%
echo System Total RAM: %TOTAL_RAM_GB%GB

if %TOTAL_RAM_GB% LSS 8 (
    echo ⚠️  WARNING: System has less than 8GB RAM - consider upgrading
) else if %TOTAL_RAM_GB% LSS 16 (
    echo ✅ System RAM adequate for development
) else (
    echo 🚀 Excellent system resources for development
)
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
