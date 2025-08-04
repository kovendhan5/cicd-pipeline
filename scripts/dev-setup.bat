@echo off
REM Development Environment Setup and Testing

echo 🛠️ CI/CD Pipeline Development Environment
echo.

echo =====================================
echo 📋 CHECKING PREREQUISITES
echo =====================================

echo 🐍 Checking Python...
python --version
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not found. Please install Python 3.9+ first.
    pause
    exit /b 1
)



echo ✅ Python is available
echo.

echo 📦 Checking pip...
pip --version
if %ERRORLEVEL% neq 0 (
    echo ❌ pip not found. Please ensure pip is installed.
    pause
    exit /b 1
)

echo ✅ pip is available
echo.

echo =====================================
echo 🔧 DEVELOPMENT SETUP OPTIONS
echo =====================================
echo.
echo Choose an option:
echo 1. Install dependencies and test locally
echo 2. Check application structure
echo 3. View CI/CD pipeline configuration
echo 4. Test Minikube management
echo 5. Generate project documentation
echo 6. Test code quality tools
echo 7. View all available CLI commands
echo 8. Exit
echo.

set /p choice="Enter your choice (1-8): "

if "%choice%"=="1" goto install_deps
if "%choice%"=="2" goto check_structure
if "%choice%"=="3" goto view_pipeline
if "%choice%"=="4" goto test_minikube
if "%choice%"=="5" goto generate_docs
if "%choice%"=="6" goto test_quality
if "%choice%"=="7" goto show_cli
if "%choice%"=="8" goto end
goto invalid_choice

:install_deps
echo.
echo 📦 Installing Python dependencies...
echo.
echo ⚠️  Note: This will install packages globally. Consider using a virtual environment.
set /p confirm="Continue? (y/n): "
if /i not "%confirm%"=="y" goto end

pip install -r requirements.txt
if %ERRORLEVEL% neq 0 (
    echo ⚠️ Some dependencies failed to install. Trying dev requirements...
    pip install -r requirements-dev.txt
)

echo.
echo ✅ Dependencies installation attempted.
echo 🧪 Running tests...
python -m pytest tests/ -v
goto end

:check_structure
echo.
echo 📁 Project Structure:
echo.
dir /s /b src\*.py
echo.
echo 📋 Configuration Files:
dir *.yml *.yaml *.json *.toml 2>nul
echo.
echo 📜 Scripts:
dir scripts\*.bat scripts\*.sh 2>nul
goto end

:view_pipeline
echo.
echo 🔄 CI/CD Pipeline Configuration:
echo.
echo === GitHub Actions ===
if exist ".github\workflows\ci-cd.yml" (
    type .github\workflows\ci-cd.yml | more
) else (
    echo ❌ GitHub Actions workflow not found
)
echo.
echo === Docker Configuration ===
if exist "Dockerfile" (
    type Dockerfile | more
) else (
    echo ❌ Dockerfile not found
)
goto end

:test_minikube
echo.
echo 🚢 Testing Minikube Management:
echo.
scripts\minikube-manage.bat status
echo.
scripts\minikube-manage.bat help
goto end

:generate_docs
echo.
echo 📚 Generating Project Documentation...
echo.
echo === Project Overview ===
if exist "readme.md" (
    type readme.md
)
echo.
echo === API Documentation ===
echo To view API docs, start the server and visit: http://localhost:8000/docs
echo.
echo === Available Scripts ===
dir scripts\*.bat /b
goto end

:test_quality
echo.
echo 🔍 Testing Code Quality Tools...
echo.
python cli.py lint
echo.
python cli.py format-code
goto end

:show_cli
echo.
echo 🛠️ Available CLI Commands:
echo.
python cli.py --help
echo.
echo 📋 Detailed command usage:
echo   python cli.py [command] --help
goto end

:invalid_choice
echo ❌ Invalid choice. Please select 1-8.
pause
goto end

:end
echo.
echo 🎉 Development environment check complete!
echo.
echo 📋 Next steps:
echo   1. Install dependencies if not done: pip install -r requirements.txt
echo   2. Start development server: python cli.py serve
echo   3. Run tests: python cli.py test
echo   4. Access API docs: http://localhost:8000/docs
echo   5. Manage Minikube: scripts\minikube-manage.bat [command]
echo.
pause
