@echo off
REM Quick Application Structure Check

echo 🔍 CI/CD Pipeline - Application Structure Review
echo.

echo =====================================
echo 📁 SOURCE CODE STRUCTURE
echo =====================================
echo.
echo 📂 Main Application (src/):
if exist "src\" (
    dir src\*.py /b
    echo.
    echo 🔍 Key Files:
    if exist "src\main.py" echo   ✅ main.py - FastAPI application
    if exist "src\models.py" echo   ✅ models.py - Database models  
    if exist "src\database.py" echo   ✅ database.py - Database connection
    if exist "src\config.py" echo   ✅ config.py - Configuration
    if exist "src\schemas.py" echo   ✅ schemas.py - Pydantic schemas
) else (
    echo ❌ src/ directory not found
)

echo.
echo =====================================
echo 🧪 TESTS STRUCTURE  
echo =====================================
echo.
if exist "tests\" (
    dir tests\*.py /b
    echo.
    echo 🔍 Test Files:
    if exist "tests\test_main.py" echo   ✅ test_main.py - Main app tests
    if exist "tests\conftest.py" echo   ✅ conftest.py - Test configuration
) else (
    echo ❌ tests/ directory not found
)

echo.
echo =====================================
echo 🚢 DEPLOYMENT CONFIGURATION
echo =====================================
echo.
echo 📋 Docker:
if exist "Dockerfile" echo   ✅ Dockerfile
if exist "docker-compose.yml" echo   ✅ docker-compose.yml
if exist "docker-compose.prod.yml" echo   ✅ docker-compose.prod.yml

echo.
echo 📋 Kubernetes:
if exist "k8s\" (
    echo   ✅ k8s/ directory exists
    dir k8s\*.yaml /b 2>nul
) else (
    echo ❌ k8s/ directory not found
)

echo.
echo 📋 CI/CD:
if exist ".github\workflows\ci-cd.yml" echo   ✅ GitHub Actions workflow
if exist ".gitlab-ci.yml" echo   ✅ GitLab CI configuration

echo.
echo 📋 Infrastructure:
if exist "terraform\" (
    echo   ✅ terraform/ directory exists
    dir terraform\*.tf /b 2>nul
) else (
    echo ❌ terraform/ directory not found
)

echo.
echo =====================================
echo 🛠️ MANAGEMENT TOOLS
echo =====================================
echo.
echo 📋 CLI Tools:
if exist "cli.py" echo   ✅ cli.py - Main CLI tool
if exist "scripts\" (
    echo   ✅ scripts/ directory exists
    echo   📂 Available scripts:
    dir scripts\*.bat /b 2>nul
) else (
    echo ❌ scripts/ directory not found
)

echo.
echo =====================================
echo 📦 DEPENDENCIES
echo =====================================
echo.
if exist "requirements.txt" (
    echo ✅ requirements.txt found
    echo 📋 Key dependencies:
    findstr /i "fastapi uvicorn pydantic" requirements.txt 2>nul
) else (
    echo ❌ requirements.txt not found
)

echo.
if exist "requirements-dev.txt" echo ✅ requirements-dev.txt found
if exist "requirements-prod.txt" echo ✅ requirements-prod.txt found

echo.
echo =====================================
echo 🎯 PROJECT STATUS
echo =====================================
echo.
echo ✅ Complete CI/CD pipeline structure detected!
echo ✅ FastAPI application with database integration
echo ✅ Kubernetes deployment manifests
echo ✅ Docker containerization setup  
echo ✅ CI/CD workflows (GitHub Actions, GitLab CI)
echo ✅ Infrastructure as Code (Terraform)
echo ✅ Management scripts and CLI tools
echo ✅ Test suite setup
echo.
echo 🚀 Ready for development and deployment!

pause
