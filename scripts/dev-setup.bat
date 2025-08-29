@echo off
REM Development Environment Setup and Testing

echo 🛠️ CI/CD Pipeline Development Environment
echo ==========================================
echo.

REM Check if running from correct directory
if not exist "helm\cicd-pipeline\Chart.yaml" (
    echo ❌ Error: Please run this script from the project root directory
    echo Expected to find: helm\cicd-pipeline\Chart.yaml
    pause
    exit /b 1
)

echo =====================================
echo 📋 CHECKING PREREQUISITES
echo =====================================

echo 🐍 Checking Python...
python --version
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not found. Please install Python 3.8+ first.
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version') do set PYTHON_VERSION=%%i
echo ✅ Python %PYTHON_VERSION% is available

REM Run comprehensive environment check
echo.
echo 🔍 Running comprehensive environment check...
python scripts\check-environment.py
set ENV_CHECK_RESULT=%ERRORLEVEL%
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
echo 1. Full development environment setup
echo 2. Install dependencies only
echo 3. Check application structure
echo 4. View CI/CD pipeline configuration
echo 5. Test Minikube management
echo 6. Generate project documentation
echo 7. Test code quality tools
echo 8. View all available CLI commands
echo 9. Exit
echo.

set /p choice="Enter your choice (1-9): "

if "%choice%"=="1" goto full_setup
if "%choice%"=="2" goto install_deps
if "%choice%"=="3" goto check_structure
if "%choice%"=="4" goto view_pipeline
if "%choice%"=="5" goto test_minikube
if "%choice%"=="6" goto generate_docs
if "%choice%"=="7" goto test_quality
if "%choice%"=="8" goto show_cli
if "%choice%"=="9" goto end
goto invalid_choice

:full_setup
echo.
echo 🚀 Setting up complete development environment...
echo.

REM Create virtual environment
echo 🔧 Setting up Python virtual environment...
if not exist "venv" (
    python -m venv venv
    echo ✅ Virtual environment created
) else (
    echo ✅ Virtual environment already exists
)

REM Activate virtual environment and install dependencies
echo 📦 Installing dependencies in virtual environment...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt

REM Create necessary directories
echo 📁 Creating project directories...
if not exist "logs" mkdir logs
if not exist "data" mkdir data
if not exist "backups" mkdir backups
echo ✅ Project directories created

REM Create environment file
if not exist ".env" (
    echo ⚙️  Creating environment configuration...
    echo DATABASE_URL=postgresql://postgres:password@localhost:5432/cicd_development > .env
    echo REDIS_URL=redis://localhost:6379/0 >> .env
    echo SECRET_KEY=your-secret-key-here >> .env
    echo DEBUG=true >> .env
    echo ENVIRONMENT=development >> .env
    echo ✅ Environment file created
)

echo 🧪 Running tests...
python -m pytest tests/ -v
goto end

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
echo ❌ Invalid choice. Please select 1-9.
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
