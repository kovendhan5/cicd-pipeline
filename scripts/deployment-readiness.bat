@echo off
REM Deployment Readiness Checker

echo 🎯 CI/CD Pipeline Deployment Readiness Checker
echo ===============================================
echo.

REM Set up logging
if not exist "logs" mkdir logs
for /f "tokens=2 delims==" %%i in ('wmic os get localdatetime /format:value ^| findstr "="') do set datetime=%%i
set timestamp=%datetime:~0,8%-%datetime:~8,6%
set logfile=logs\readiness-check-%timestamp%.log
echo Deployment readiness check started at %date% %time% > %logfile%

echo 📝 Check log: %logfile%
echo.

set READY_COUNT=0
set NOT_READY_COUNT=0
set WARNING_COUNT=0

REM Initialize readiness categories
set PREREQUISITES_READY=0
set DOCKER_READY=0
set KUBERNETES_READY=0
set APPLICATION_READY=0
set SECURITY_READY=0
set DOCUMENTATION_READY=0

echo 🔍 Phase 1: Prerequisites Assessment
echo ====================================

REM Check project structure
echo 📁 Project Structure Check...
if exist "src\main.py" (
    echo ✅ FastAPI application found
    echo FastAPI application found >> %logfile%
    set /a READY_COUNT+=1
) else (
    echo ❌ FastAPI application missing
    echo FastAPI application missing >> %logfile%
    set /a NOT_READY_COUNT+=1
)

if exist "Dockerfile" (
    echo ✅ Dockerfile found
    echo Dockerfile found >> %logfile%
    set /a READY_COUNT+=1
) else (
    echo ❌ Dockerfile missing
    echo Dockerfile missing >> %logfile%
    set /a NOT_READY_COUNT+=1
)

if exist "docker-compose.yml" (
    echo ✅ Docker Compose configuration found
    echo Docker Compose found >> %logfile%
    set /a READY_COUNT+=1
) else (
    echo ❌ Docker Compose configuration missing
    echo Docker Compose missing >> %logfile%
    set /a NOT_READY_COUNT+=1
)

if exist "k8s" (
    echo ✅ Kubernetes manifests directory found
    echo Kubernetes manifests found >> %logfile%
    set /a READY_COUNT+=1
) else (
    echo ❌ Kubernetes manifests missing
    echo Kubernetes manifests missing >> %logfile%
    set /a NOT_READY_COUNT+=1
)

if exist ".github\workflows" (
    echo ✅ GitHub Actions workflows found
    echo GitHub Actions workflows found >> %logfile%
    set /a READY_COUNT+=1
) else (
    echo ❌ GitHub Actions workflows missing
    echo GitHub Actions workflows missing >> %logfile%
    set /a NOT_READY_COUNT+=1
)

REM Calculate prerequisites readiness
if %NOT_READY_COUNT% equ 0 (
    set PREREQUISITES_READY=1
    echo ✅ Prerequisites: READY
    echo Prerequisites: READY >> %logfile%
) else (
    echo ❌ Prerequisites: NOT READY (%NOT_READY_COUNT% issues)
    echo Prerequisites: NOT READY >> %logfile%
)
echo.

echo 🐳 Phase 2: Docker Environment Assessment
echo ==========================================

set DOCKER_ISSUES=0

REM Check Docker installation
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker not installed
    echo Docker not installed >> %logfile%
    set /a DOCKER_ISSUES+=1
) else (
    echo ✅ Docker installed
    echo Docker installed >> %logfile%
)

REM Check Docker daemon
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker daemon not running
    echo Docker daemon not running >> %logfile%
    set /a DOCKER_ISSUES+=1
) else (
    echo ✅ Docker daemon running
    echo Docker daemon running >> %logfile%
    
    REM Check Docker resources
    for /f "tokens=3" %%i in ('docker info 2^>nul ^| findstr "Total Memory"') do set DOCKER_MEMORY=%%i
    if defined DOCKER_MEMORY (
        echo ✅ Docker memory allocated: %DOCKER_MEMORY%
        echo Docker memory: %DOCKER_MEMORY% >> %logfile%
    ) else (
        echo ⚠️  Could not determine Docker memory allocation
        echo Docker memory unknown >> %logfile%
        set /a WARNING_COUNT+=1
    )
)

REM Test Docker build capability
echo 🔍 Testing Docker build...
docker build --help >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker build not available
    echo Docker build not available >> %logfile%
    set /a DOCKER_ISSUES+=1
) else (
    echo ✅ Docker build available
    echo Docker build available >> %logfile%
)

if %DOCKER_ISSUES% equ 0 (
    set DOCKER_READY=1
    echo ✅ Docker Environment: READY
    echo Docker Environment: READY >> %logfile%
) else (
    echo ❌ Docker Environment: NOT READY (%DOCKER_ISSUES% issues)
    echo Docker Environment: NOT READY >> %logfile%
)
echo.

echo ☸️  Phase 3: Kubernetes Environment Assessment
echo ==============================================

set K8S_ISSUES=0

REM Check kubectl
kubectl version --client >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ kubectl not installed
    echo kubectl not installed >> %logfile%
    set /a K8S_ISSUES+=1
) else (
    echo ✅ kubectl installed
    echo kubectl installed >> %logfile%
)

REM Check Minikube
minikube version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  Minikube not installed (optional for local development)
    echo Minikube not installed >> %logfile%
    set /a WARNING_COUNT+=1
) else (
    echo ✅ Minikube installed
    echo Minikube installed >> %logfile%
    
    REM Check Minikube status
    minikube status >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Minikube cluster not running
        echo Minikube cluster not running >> %logfile%
        set /a WARNING_COUNT+=1
    ) else (
        echo ✅ Minikube cluster running
        echo Minikube cluster running >> %logfile%
    )
)

REM Validate Kubernetes manifests
echo 🔍 Validating Kubernetes manifests...
set MANIFEST_ERRORS=0
for %%f in (k8s\*.yaml) do (
    kubectl apply --dry-run=client -f %%f >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ❌ Invalid manifest: %%f
        echo Invalid manifest: %%f >> %logfile%
        set /a MANIFEST_ERRORS+=1
    )
)

if %MANIFEST_ERRORS% equ 0 (
    echo ✅ All Kubernetes manifests valid
    echo All manifests valid >> %logfile%
) else (
    echo ❌ %MANIFEST_ERRORS% invalid Kubernetes manifests
    echo %MANIFEST_ERRORS% invalid manifests >> %logfile%
    set /a K8S_ISSUES+=1
)

if %K8S_ISSUES% equ 0 (
    set KUBERNETES_READY=1
    echo ✅ Kubernetes Environment: READY
    echo Kubernetes Environment: READY >> %logfile%
) else (
    echo ❌ Kubernetes Environment: NOT READY (%K8S_ISSUES% issues)
    echo Kubernetes Environment: NOT READY >> %logfile%
)
echo.

echo 🚀 Phase 4: Application Readiness Assessment
echo =============================================

set APP_ISSUES=0

REM Check Python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not available
    echo Python not available >> %logfile%
    set /a APP_ISSUES+=1
) else (
    echo ✅ Python available
    echo Python available >> %logfile%
)

REM Check FastAPI imports
python -c "from src.main import app" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ FastAPI application import failed
    echo FastAPI import failed >> %logfile%
    set /a APP_ISSUES+=1
) else (
    echo ✅ FastAPI application imports successfully
    echo FastAPI import successful >> %logfile%
)

REM Check requirements
if exist "requirements.txt" (
    echo ✅ Requirements file found
    echo Requirements file found >> %logfile%
    
    REM Check if requirements are installed
    pip check >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo ⚠️  Dependency conflicts detected
        echo Dependency conflicts >> %logfile%
        set /a WARNING_COUNT+=1
    ) else (
        echo ✅ Dependencies compatible
        echo Dependencies compatible >> %logfile%
    )
) else (
    echo ❌ Requirements file missing
    echo Requirements file missing >> %logfile%
    set /a APP_ISSUES+=1
)

REM Check CLI tool
python cli.py --help >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ CLI tool not working
    echo CLI tool not working >> %logfile%
    set /a APP_ISSUES+=1
) else (
    echo ✅ CLI tool functional
    echo CLI tool functional >> %logfile%
)

if %APP_ISSUES% equ 0 (
    set APPLICATION_READY=1
    echo ✅ Application: READY
    echo Application: READY >> %logfile%
) else (
    echo ❌ Application: NOT READY (%APP_ISSUES% issues)
    echo Application: NOT READY >> %logfile%
)
echo.

echo 🔐 Phase 5: Security Readiness Assessment
echo ==========================================

set SECURITY_ISSUES=0

REM Check for exposed secrets
if exist ".env" (
    findstr /i "password\|secret\|key\|token" .env >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ⚠️  Potential secrets found in .env file
        echo Secrets in .env file >> %logfile%
        set /a WARNING_COUNT+=1
    ) else (
        echo ✅ No obvious secrets in .env
        echo No secrets in .env >> %logfile%
    )
) else (
    echo ✅ No .env file (good for production)
    echo No .env file >> %logfile%
)

REM Check Dockerfile security
findstr /i "ADD.*http\|RUN.*chmod 777" Dockerfile >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo ⚠️  Potential security issues in Dockerfile
    echo Dockerfile security issues >> %logfile%
    set /a WARNING_COUNT+=1
) else (
    echo ✅ No obvious Dockerfile security issues
    echo Dockerfile security OK >> %logfile%
)

REM Check GitHub workflows security
if exist ".github\workflows\*.yml" (
    findstr /i "password\|secret\|key" .github\workflows\*.yml >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo ⚠️  Potential hardcoded secrets in workflows
        echo Hardcoded secrets in workflows >> %logfile%
        set /a WARNING_COUNT+=1
    ) else (
        echo ✅ No hardcoded secrets in workflows
        echo No hardcoded secrets in workflows >> %logfile%
    )
)

REM Check for security documentation
if exist "SECURITY_CONFIG.md" (
    echo ✅ Security configuration documentation found
    echo Security documentation found >> %logfile%
) else (
    echo ❌ Security configuration documentation missing
    echo Security documentation missing >> %logfile%
    set /a SECURITY_ISSUES+=1
)

if %SECURITY_ISSUES% equ 0 (
    set SECURITY_READY=1
    echo ✅ Security: READY
    echo Security: READY >> %logfile%
) else (
    echo ❌ Security: NOT READY (%SECURITY_ISSUES% issues)
    echo Security: NOT READY >> %logfile%
)
echo.

echo 📚 Phase 6: Documentation Readiness Assessment
echo ===============================================

set DOC_ISSUES=0

if exist "README.md" (
    echo ✅ README found
    echo README found >> %logfile%
) else (
    echo ❌ README missing
    echo README missing >> %logfile%
    set /a DOC_ISSUES+=1
)

if exist "DEPLOYMENT_GUIDE.md" (
    echo ✅ Deployment guide found
    echo Deployment guide found >> %logfile%
) else (
    echo ❌ Deployment guide missing
    echo Deployment guide missing >> %logfile%
    set /a DOC_ISSUES+=1
)

if exist "PROJECT_STATUS.md" (
    echo ✅ Project status documentation found
    echo Project status found >> %logfile%
) else (
    echo ❌ Project status documentation missing
    echo Project status missing >> %logfile%
    set /a DOC_ISSUES+=1
)

if %DOC_ISSUES% equ 0 (
    set DOCUMENTATION_READY=1
    echo ✅ Documentation: READY
    echo Documentation: READY >> %logfile%
) else (
    echo ❌ Documentation: NOT READY (%DOC_ISSUES% issues)
    echo Documentation: NOT READY >> %logfile%
)
echo.

echo 📊 Final Deployment Readiness Assessment
echo ==========================================

echo Readiness check completed at %date% %time% >> %logfile%
echo.

REM Calculate overall readiness
set /a TOTAL_CATEGORIES=6
set /a READY_CATEGORIES=%PREREQUISITES_READY%+%DOCKER_READY%+%KUBERNETES_READY%+%APPLICATION_READY%+%SECURITY_READY%+%DOCUMENTATION_READY%
set /a READINESS_PERCENTAGE=(%READY_CATEGORIES%*100)/%TOTAL_CATEGORIES%

echo 🎯 Deployment Readiness Summary:
echo ================================
echo Prerequisites:      %PREREQUISITES_READY%/1 (Essential)
echo Docker Environment: %DOCKER_READY%/1 (Essential)
echo Kubernetes:         %KUBERNETES_READY%/1 (Essential)
echo Application:        %APPLICATION_READY%/1 (Essential)
echo Security:           %SECURITY_READY%/1 (Important)
echo Documentation:      %DOCUMENTATION_READY%/1 (Important)
echo.
echo Overall Readiness: %READY_CATEGORIES%/%TOTAL_CATEGORIES% categories (%READINESS_PERCENTAGE%%%)
echo Warnings: %WARNING_COUNT%

echo.
echo Final assessment saved to: %logfile%
echo.

if %READINESS_PERCENTAGE% equ 100 (
    echo 🎉 DEPLOYMENT READY!
    echo ==================
    echo ✅ All systems are ready for deployment
    echo ✅ No critical issues found
    if %WARNING_COUNT% gtr 0 (
        echo ⚠️  %WARNING_COUNT% warnings to review (non-critical)
    )
    echo.
    echo 🚀 Ready to proceed with:
    echo  1. Local development: docker-compose up --build
    echo  2. Minikube deployment: scripts\minikube-manage.bat start
    echo  3. Cloud deployment: Follow DEPLOYMENT_GUIDE.md
    echo  4. CI/CD pipeline: Push to GitHub to trigger workflows
    echo.
    echo DEPLOYMENT READY >> %logfile%
) else if %READINESS_PERCENTAGE% geq 80 (
    echo ⚠️  MOSTLY READY FOR DEPLOYMENT
    echo ==============================
    echo ✅ Core systems ready (%READINESS_PERCENTAGE%%%)
    echo ⚠️  %WARNING_COUNT% warnings and minor issues
    echo.
    echo 🔧 Address these issues for optimal deployment:
    if %PREREQUISITES_READY% equ 0 echo   - Fix project structure issues
    if %DOCKER_READY% equ 0 echo   - Resolve Docker environment issues
    if %KUBERNETES_READY% equ 0 echo   - Fix Kubernetes configuration
    if %APPLICATION_READY% equ 0 echo   - Resolve application issues
    if %SECURITY_READY% equ 0 echo   - Address security concerns
    if %DOCUMENTATION_READY% equ 0 echo   - Complete documentation
    echo.
    echo MOSTLY READY >> %logfile%
) else (
    echo ❌ NOT READY FOR DEPLOYMENT
    echo ===========================
    echo ❌ Critical issues must be resolved (%READINESS_PERCENTAGE%%% ready)
    echo.
    echo 🔧 Critical fixes needed:
    if %PREREQUISITES_READY% equ 0 echo   - ❌ Fix project structure
    if %DOCKER_READY% equ 0 echo   - ❌ Resolve Docker issues
    if %KUBERNETES_READY% equ 0 echo   - ❌ Fix Kubernetes setup
    if %APPLICATION_READY% equ 0 echo   - ❌ Fix application issues
    if %SECURITY_READY% equ 0 echo   - ❌ Address security issues
    if %DOCUMENTATION_READY% equ 0 echo   - ❌ Complete documentation
    echo.
    echo 💡 Recommended actions:
    echo  1. Run: scripts\system-diagnostics.bat
    echo  2. Run: scripts\auto-setup.bat
    echo  3. Review: PROJECT_STATUS.md
    echo  4. Re-run this readiness check
    echo.
    echo NOT READY >> %logfile%
)

echo.
echo 📞 Need Help?
echo =============
echo - System setup: scripts\auto-setup.bat
echo - Diagnostics: scripts\system-diagnostics.bat
echo - Testing: scripts\test-suite.bat
echo - Master control: scripts\master-control.bat
echo - Documentation: PROJECT_STATUS.md

echo.
pause
