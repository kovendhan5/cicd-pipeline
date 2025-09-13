@echo off
REM Development Environment Setup and Testing

echo 🛠️ CI/CD Pipeline Development Environment Setup
echo =================================================

echo.
echo 📋 CHECKING PREREQUISITES
echo =========================

echo 🐍 Checking Python...
python --version
if %ERRORLEVEL% neq 0 (
    echo ❌ Python not found. Please install Python 3.9+ first.
    echo 💡 Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo ✅ Python is available

echo 📦 Checking pip...
pip --version
if %ERRORLEVEL% neq 0 (
    echo ❌ pip not found. Please ensure pip is installed.
    pause
    exit /b 1
)

echo ✅ pip is available

echo 🐳 Checking Docker...
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  Docker not found. Some features will be limited.
    echo 💡 Install Docker Desktop for full functionality
) else (
    echo ✅ Docker is available
)

echo ☸️  Checking Kubernetes tools...
kubectl version --client >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  kubectl not found. Kubernetes features will be limited.
) else (
    echo ✅ kubectl is available
)

helm version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ⚠️  Helm not found. Helm deployment features will be limited.
) else (
    echo ✅ Helm is available
)

echo.

echo 🔧 DEVELOPMENT SETUP OPTIONS
echo ============================
echo.
echo Choose an option:
echo 1. 📦 Install dependencies and setup environment
echo 2. 🏗️  Setup virtual environment
echo 3. 🐳 Setup Docker development environment
echo 4. 📁 Check application structure
echo 5. 🔄 View CI/CD pipeline configuration
echo 6. ☸️  Test Kubernetes tools (Minikube)
echo 7. 📚 Generate project documentation
echo 8. 🔍 Test code quality tools
echo 9. 🛠️  View all available CLI commands
echo 10. 🚀 Quick start development server
echo 11. 🧪 Run comprehensive tests
echo 12. 📊 Run system diagnostics
echo 13. ❌ Exit
echo.

set /p choice="Enter your choice (1-13): "

if "%choice%"=="1" goto install_deps
if "%choice%"=="2" goto setup_venv
if "%choice%"=="3" goto setup_docker
if "%choice%"=="4" goto check_structure
if "%choice%"=="5" goto view_pipeline
if "%choice%"=="6" goto test_kubernetes
if "%choice%"=="7" goto generate_docs
if "%choice%"=="8" goto test_quality
if "%choice%"=="9" goto show_cli
if "%choice%"=="10" goto quick_start
if "%choice%"=="11" goto run_tests
if "%choice%"=="12" goto run_diagnostics
if "%choice%"=="13" goto end
goto invalid_choice

:install_deps
echo.
echo 📦 Installing Python dependencies...
echo.
echo Creating virtual environment if it doesn't exist...
if not exist "venv" (
    python -m venv venv
    echo ✅ Virtual environment created
) else (
    echo ✅ Virtual environment already exists
)

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo Installing/upgrading pip...
python -m pip install --upgrade pip

echo Installing production dependencies...
if exist "requirements.txt" (
    pip install -r requirements.txt
    echo ✅ Production dependencies installed
) else (
    echo ⚠️  requirements.txt not found
)

echo Installing development dependencies...
if exist "requirements-dev.txt" (
    pip install -r requirements-dev.txt
    echo ✅ Development dependencies installed
) else (
    echo ⚠️  requirements-dev.txt not found
)

echo.
echo ✅ Dependencies installation completed.
echo 🧪 Running basic tests...
if exist "tests" (
    python -m pytest tests/ -v --tb=short
) else (
    echo ⚠️  Tests directory not found
)
goto end

:setup_venv
echo.
echo 🏗️  Setting up virtual environment...
echo.
if exist "venv" (
    echo ⚠️  Virtual environment already exists
    set /p recreate="Recreate? (y/n): "
    if /i "%recreate%"=="y" (
        echo Removing existing virtual environment...
        rmdir /s /q venv
    ) else (
        goto end
    )
)

echo Creating virtual environment...
python -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip

echo ✅ Virtual environment setup completed
echo 💡 To activate: call venv\Scripts\activate.bat
goto end

:setup_docker
echo.
echo 🐳 Setting up Docker development environment...
echo.
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Docker not found. Please install Docker Desktop first.
    goto end
)

echo Building development Docker image...
docker build -t cicd-pipeline:dev .

echo Setting up Docker Compose environment...
if exist "docker-compose.yml" (
    echo Creating .env file for Docker Compose...
    if not exist ".env" (
        echo DATABASE_URL=postgresql://dev_user:dev_password@db:5432/cicd_dev > .env
        echo REDIS_URL=redis://redis:6379/0 >> .env
        echo SECRET_KEY=dev-secret-key >> .env
        echo DEBUG=true >> .env
    )
    
    echo Starting development services...
    docker-compose up -d
    echo ✅ Docker development environment ready
    echo 🌐 Application: http://localhost:8000
    echo 📊 API Docs: http://localhost:8000/docs
) else (
    echo ⚠️  docker-compose.yml not found
)
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

:test_kubernetes
echo.
echo ☸️  Testing Kubernetes Tools:
echo.
echo === Minikube Status ===
if exist "scripts\minikube-manage.bat" (
    scripts\minikube-manage.bat status
    echo.
    echo === Available Minikube Commands ===
    scripts\minikube-manage.bat help
) else (
    echo ❌ Minikube management script not found
)

echo.
echo === Helm Charts ===
if exist "helm\cicd-pipeline" (
    echo Validating Helm chart...
    helm lint helm\cicd-pipeline
    echo ✅ Helm chart validation completed
) else (
    echo ⚠️  Helm chart not found at helm\cicd-pipeline
)

echo.
echo === Kubernetes Manifests ===
if exist "k8s" (
    echo Found Kubernetes manifests:
    dir k8s\*.yaml /b
) else (
    echo ⚠️  Kubernetes manifests not found
)
goto end

:generate_docs
echo.
echo 📚 Generating Project Documentation...
echo.
echo === Project Overview ===
if exist "README.md" (
    echo Found README.md:
    type README.md | more
) else if exist "readme.md" (
    echo Found readme.md:
    type readme.md | more
) else (
    echo ⚠️  README.md not found
)

echo.
echo === Available Documentation ===
echo Found documentation files:
dir *.md /b 2>nul
echo.
dir docs\*.md /b 2>nul

echo.
echo === Project Structure ===
echo Main directories:
for /d %%i in (*) do echo   📁 %%i

echo.
echo === Configuration Files ===
dir *.yml *.yaml *.json *.toml /b 2>nul

echo.
echo === API Documentation ===
echo 💡 To view interactive API docs, start the server and visit:
echo    http://localhost:8000/docs
echo    http://localhost:8000/redoc
goto end

:quick_start
echo.
echo 🚀 Quick Start Development Server...
echo.
if not exist "venv" (
    echo Setting up virtual environment first...
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install --upgrade pip
    if exist "requirements.txt" pip install -r requirements.txt
) else (
    call venv\Scripts\activate.bat
)

echo.
echo Starting FastAPI development server...
if exist "app\main.py" (
    echo Using app/main.py
    python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
) else if exist "src\main.py" (
    echo Using src/main.py
    python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
) else if exist "cli.py" (
    echo Using CLI serve command
    python cli.py serve
) else (
    echo ❌ Could not find main application file
    echo Expected: app\main.py, src\main.py, or cli.py
)
goto end

:run_tests
echo.
echo 🧪 Running Comprehensive Tests...
echo.
if not exist "venv" (
    echo ⚠️  Virtual environment not found. Setting up...
    python -m venv venv
    call venv\Scripts\activate.bat
    if exist "requirements.txt" pip install -r requirements.txt
) else (
    call venv\Scripts\activate.bat
)

echo.
echo === Unit Tests ===
if exist "tests" (
    python -m pytest tests/ -v --tb=short --cov=app --cov-report=term-missing
) else (
    echo ⚠️  Tests directory not found
)

echo.
echo === Code Quality ===
if exist "cli.py" (
    python cli.py lint
    python cli.py format-check
) else (
    echo Running manual quality checks...
    python -m black --check . 2>nul || echo ⚠️  Black not available
    python -m flake8 . 2>nul || echo ⚠️  Flake8 not available
    python -m mypy . 2>nul || echo ⚠️  MyPy not available
)

echo.
echo === Security Scan ===
python -m bandit -r app/ 2>nul || echo ⚠️  Bandit not available

echo ✅ Comprehensive testing completed
goto end

:run_diagnostics
echo.
echo 📊 Running System Diagnostics...
echo.
if exist "scripts\system-diagnostics.bat" (
    scripts\system-diagnostics.bat
) else (
    echo ❌ System diagnostics script not found
    echo Expected: scripts\system-diagnostics.bat
)
goto end

:test_quality
echo.
echo 🔍 Testing Code Quality Tools...
echo.
if not exist "venv" (
    echo Setting up virtual environment for quality checks...
    python -m venv venv
    call venv\Scripts\activate.bat
    pip install --upgrade pip
    if exist "requirements-dev.txt" pip install -r requirements-dev.txt
) else (
    call venv\Scripts\activate.bat
)

echo.
echo === Code Formatting ===
python -m black --check . 2>nul || echo ⚠️  Black not available - install with: pip install black

echo.
echo === Code Linting ===
python -m flake8 . 2>nul || echo ⚠️  Flake8 not available - install with: pip install flake8

echo.
echo === Type Checking ===
python -m mypy . 2>nul || echo ⚠️  MyPy not available - install with: pip install mypy

echo.
echo === Security Scanning ===
python -m bandit -r app/ -f json 2>nul || python -m bandit -r src/ -f json 2>nul || echo ⚠️  Bandit not available - install with: pip install bandit

echo.
echo === CLI Quality Commands ===
if exist "cli.py" (
    echo Available CLI quality commands:
    python cli.py --help | findstr "lint\|format\|test\|quality"
) else (
    echo ⚠️  CLI script not found
)
goto end

:show_cli
echo.
echo 🛠️  Available CLI Commands:
echo.
if exist "cli.py" (
    python cli.py --help
    echo.
    echo 📋 Detailed command usage:
    echo   python cli.py [command] --help
) else (
    echo ❌ CLI script (cli.py) not found
    echo.
    echo 🔧 Available Scripts:
    echo === Development Scripts ===
    dir scripts\*.bat /b
    echo.
    echo === Available Python Commands ===
    echo   python -m uvicorn app.main:app --reload    (start server)
    echo   python -m pytest tests/                    (run tests)
    echo   python -m black .                          (format code)
    echo   python -m flake8 .                         (lint code)
)
goto end

:invalid_choice
echo ❌ Invalid choice. Please select 1-13.
pause
goto end

:end
echo.
echo 🎉 Development environment setup complete!
echo.
echo 📋 Quick Reference:
echo ==================
echo.
echo 🚀 Start Development:
echo   1. Setup environment: scripts\auto-setup.bat
echo   2. Install dependencies: Choose option 1 or 2
echo   3. Start server: Choose option 10 or python cli.py serve
echo   4. Access API: http://localhost:8000/docs
echo.
echo 🧪 Testing & Quality:
echo   • Run tests: Choose option 11 or python -m pytest tests/
echo   • Check quality: Choose option 8
echo   • System diagnostics: Choose option 12
echo.
echo 🐳 Docker Development:
echo   • Setup Docker env: Choose option 3
echo   • Start services: docker-compose up --build
echo   • View logs: docker-compose logs -f
echo.
echo ☸️  Kubernetes Development:
echo   • Test K8s tools: Choose option 6
echo   • Start Minikube: scripts\minikube-manage.bat start
echo   • Deploy to K8s: helm install cicd-pipeline helm\cicd-pipeline
echo.
echo 📚 Documentation:
echo   • Project docs: Choose option 7
echo   • API docs: http://localhost:8000/docs (when server running)
echo   • Setup guide: QUICK_SETUP_GUIDE.md
echo   • Deployment guide: PRODUCTION_DEPLOYMENT_KIT.md
echo.
echo 🔧 Advanced Features:
echo   • Complete validation: scripts\validate-complete-pipeline.bat
echo   • Production deployment: scripts\deploy-production.bat
echo   • System diagnostics: scripts\system-diagnostics.bat
echo   • Multi-environment setup: environments\ directory
echo.
echo 💡 Next Steps:
echo   1. Choose a setup option from the menu above
echo   2. Follow the QUICK_SETUP_GUIDE.md for detailed instructions
echo   3. Review PROJECT_STATUS_FINAL.md for complete feature overview
echo   4. Start coding and testing your changes!
echo.
pause
