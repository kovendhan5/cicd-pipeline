@echo off
REM Comprehensive Testing and Validation Suite

echo 🧪 CI/CD Pipeline Testing Suite
echo ================================
echo.

REM Set up logging
if not exist "logs" mkdir logs
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /format:value ^| findstr "="') do set datetime=%%i
set timestamp=%datetime:~0,8%-%datetime:~8,6%
set logfile=logs\test-run-%timestamp%.log
echo Test run started at %date% %time% > %logfile%

echo 📝 Test log: %logfile%
echo.

set TESTS_PASSED=0
set TESTS_FAILED=0
set TESTS_SKIPPED=0

REM Function to run test and track results
:RUN_TEST
set TEST_NAME=%1
echo 🔍 Testing: %TEST_NAME%
echo Testing: %TEST_NAME% >> %logfile%
shift
%*
if %ERRORLEVEL% equ 0 (
    echo ✅ PASSED: %TEST_NAME%
    echo PASSED: %TEST_NAME% >> %logfile%
    set /a TESTS_PASSED+=1
) else (
    echo ❌ FAILED: %TEST_NAME%
    echo FAILED: %TEST_NAME% >> %logfile%
    set /a TESTS_FAILED+=1
)
echo.
goto :EOF

echo 🔧 Pre-Test Environment Check
echo =============================

REM Check if we're in the right directory
if not exist "src\main.py" (
    echo ❌ Error: Not in the correct project directory
    echo Please run this script from the cicd-pipeline root directory >> %logfile%
    pause
    exit /b 1
)

echo ✅ In correct project directory
echo.

echo 🐍 Unit Tests
echo =============

echo 🔍 Python Import Tests...
python -c "import sys; print('Python version:', sys.version)" >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not available
    set /a TESTS_FAILED+=1
) else (
    echo ✅ Python available
    set /a TESTS_PASSED+=1
)

echo 🔍 FastAPI Import Test...
python -c "from src.main import app; print('FastAPI import successful')" >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ FastAPI import failed
    echo FastAPI import failed >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    echo ✅ FastAPI imports successfully
    echo FastAPI import successful >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Database Models Test...
python -c "from src.models import User, Pipeline; print('Models import successful')" >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Database models import failed
    echo Database models import failed >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    echo ✅ Database models import successfully
    echo Database models import successful >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 CLI Tool Test...
python cli.py --help >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ CLI tool failed
    echo CLI tool failed >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    echo ✅ CLI tool working
    echo CLI tool working >> %logfile%
    set /a TESTS_PASSED+=1
)

REM Run pytest if available
echo 🔍 PyTest Suite...
python -m pytest --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  PyTest not available - skipping unit tests
    echo PyTest not available >> %logfile%
    set /a TESTS_SKIPPED+=1
) else (
    python -m pytest tests/ -v >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Some unit tests failed
        echo Unit tests failed >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ All unit tests passed
        echo Unit tests passed >> %logfile%
        set /a TESTS_PASSED+=1
    )
)
echo.

echo 🐳 Docker Tests
echo ===============

echo 🔍 Docker Availability...
docker --version >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker not available
    echo Docker not available >> %logfile%
    set /a TESTS_FAILED+=1
    echo ⚠️  Skipping Docker tests
    goto SKIP_DOCKER_TESTS
) else (
    echo ✅ Docker available
    echo Docker available >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Docker Daemon Test...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker daemon not running
    echo Docker daemon not running >> %logfile%
    set /a TESTS_FAILED+=1
    echo ⚠️  Skipping Docker tests
    goto SKIP_DOCKER_TESTS
) else (
    echo ✅ Docker daemon running
    echo Docker daemon running >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Dockerfile Validation...
docker build --no-cache -t fastapi-app-test . >> %logfile% 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker build failed
    echo Docker build failed >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    echo ✅ Docker build successful
    echo Docker build successful >> %logfile%
    set /a TESTS_PASSED+=1
    
    echo 🔍 Container Run Test...
    docker run --rm -d --name fastapi-test -p 8001:8000 fastapi-app-test >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Container failed to start
        echo Container failed to start >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ Container started successfully
        echo Container started successfully >> %logfile%
        set /a TESTS_PASSED+=1
        
        REM Wait a moment for the container to fully start
        timeout /t 5 /nobreak >nul
        
        echo 🔍 Health Check Test...
        curl -f http://localhost:8001/health >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ❌ Health check failed
            echo Health check failed >> %logfile%
            set /a TESTS_FAILED+=1
        ) else (
            echo ✅ Health check passed
            echo Health check passed >> %logfile%
            set /a TESTS_PASSED+=1
        )
        
        REM Stop the test container
        docker stop fastapi-test >nul 2>&1
    )
    
    REM Clean up test image
    docker rmi fastapi-app-test >nul 2>&1
)

echo 🔍 Docker Compose Test...
if exist "docker-compose.yml" (
    docker-compose config >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Docker Compose configuration invalid
        echo Docker Compose config invalid >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ Docker Compose configuration valid
        echo Docker Compose config valid >> %logfile%
        set /a TESTS_PASSED+=1
    )
) else (
    echo ⚠️  docker-compose.yml not found
    echo Docker Compose file not found >> %logfile%
    set /a TESTS_SKIPPED+=1
)

:SKIP_DOCKER_TESTS
echo.

echo ☸️  Kubernetes Tests
echo ===================

echo 🔍 kubectl Availability...
kubectl version --client >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ kubectl not available
    echo kubectl not available >> %logfile%
    set /a TESTS_FAILED+=1
    echo ⚠️  Skipping Kubernetes tests
    goto SKIP_K8S_TESTS
) else (
    echo ✅ kubectl available
    echo kubectl available >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Kubernetes Manifests Validation...
for %%f in (k8s\*.yaml) do (
    kubectl apply --dry-run=client -f %%f >> %logfile% 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Invalid manifest: %%f
        echo Invalid manifest: %%f >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ Valid manifest: %%f
        echo Valid manifest: %%f >> %logfile%
        set /a TESTS_PASSED+=1
    )
)

echo 🔍 Minikube Status...
minikube version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Minikube not available
    echo Minikube not available >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    minikube status >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Minikube cluster not running
        echo Minikube cluster not running >> %logfile%
        set /a TESTS_SKIPPED+=1
    ) else (
        echo ✅ Minikube cluster running
        echo Minikube cluster running >> %logfile%
        set /a TESTS_PASSED+=1
        
        echo 🔍 Minikube Connectivity...
        kubectl get nodes >> %logfile% 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ❌ Cannot connect to Minikube cluster
            echo Cannot connect to Minikube cluster >> %logfile%
            set /a TESTS_FAILED+=1
        ) else (
            echo ✅ Minikube cluster accessible
            echo Minikube cluster accessible >> %logfile%
            set /a TESTS_PASSED+=1
        )
    )
)

:SKIP_K8S_TESTS
echo.

echo 🔐 Security Tests
echo =================

echo 🔍 Secrets Detection...
if exist ".env" (
    findstr /i "password\|secret\|key\|token" .env >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ⚠️  Potential secrets found in .env file
        echo Potential secrets in .env >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ No obvious secrets in .env
        echo No obvious secrets in .env >> %logfile%
        set /a TESTS_PASSED+=1
    )
) else (
    echo ✅ No .env file found (good)
    echo No .env file found >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Dockerfile Security...
findstr /i "ADD.*http\|RUN.*chmod 777" Dockerfile >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ⚠️  Potential security issues in Dockerfile
    echo Dockerfile security issues >> %logfile%
    set /a TESTS_FAILED+=1
) else (
    echo ✅ No obvious security issues in Dockerfile
    echo Dockerfile security check passed >> %logfile%
    set /a TESTS_PASSED+=1
)

echo 🔍 Requirements Security...
if exist "requirements.txt" (
    findstr /i "==[0-9]\+\.[0-9]" requirements.txt >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Some packages don't have version pins
        echo Package versions not pinned >> %logfile%
        set /a TESTS_FAILED+=1
    ) else (
        echo ✅ Package versions are pinned
        echo Package versions pinned >> %logfile%
        set /a TESTS_PASSED+=1
    )
) else (
    echo ⚠️  requirements.txt not found
    echo requirements.txt not found >> %logfile%
    set /a TESTS_SKIPPED+=1
)
echo.

echo 📊 Test Results Summary
echo =======================

echo Test execution completed at %date% %time% >> %logfile%
echo.
echo 📈 Results:
echo ==========
echo Tests Passed:  %TESTS_PASSED%
echo Tests Failed:  %TESTS_FAILED%
echo Tests Skipped: %TESTS_SKIPPED%
echo.

set /a TOTAL_TESTS=%TESTS_PASSED%+%TESTS_FAILED%
if %TOTAL_TESTS% equ 0 (
    echo No tests were executed
    echo Overall Status: ⚠️  UNKNOWN
) else (
    set /a SUCCESS_RATE=(%TESTS_PASSED%*100)/%TOTAL_TESTS%
    echo Success Rate: %SUCCESS_RATE%%%
    
    if %TESTS_FAILED% equ 0 (
        echo Overall Status: ✅ ALL TESTS PASSED
        echo Overall Status: ALL TESTS PASSED >> %logfile%
    ) else if %SUCCESS_RATE% geq 80 (
        echo Overall Status: ⚠️  MOSTLY PASSING ^(%TESTS_FAILED% failures^)
        echo Overall Status: MOSTLY PASSING >> %logfile%
    ) else (
        echo Overall Status: ❌ MANY FAILURES ^(%TESTS_FAILED% failures^)
        echo Overall Status: MANY FAILURES >> %logfile%
    )
)

echo.
echo 📝 Detailed log: %logfile%

if %TESTS_FAILED% gtr 0 (
    echo.
    echo 🔧 Recommended Actions:
    echo =====================
    echo 1. Review the detailed log file
    echo 2. Install missing dependencies
    echo 3. Fix configuration issues
    echo 4. Re-run the tests
    echo.
    echo For help:
    echo - Run: scripts\system-diagnostics.bat
    echo - Review: PROJECT_STATUS.md
)

echo.
pause
