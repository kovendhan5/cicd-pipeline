#!/bin/bash
# Automated Environment Setup and Validation (Linux/macOS)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 CI/CD Pipeline Environment Setup${NC}"
echo "====================================="
echo

# Create logs directory if it doesn't exist
mkdir -p logs

# Set log file with timestamp
timestamp=$(date +"%Y%m%d-%H%M%S")
logfile="logs/setup-${timestamp}.log"

echo -e "${PURPLE}📝 Logging to: ${logfile}${NC}"
echo "Starting environment setup at $(date)" > "$logfile"
echo

echo -e "${BLUE}🔍 Step 1: Environment Validation${NC}"
echo "================================="

# Check if we're in the right directory
if [[ ! -f "app/main.py" && ! -f "src/main.py" ]]; then
    echo -e "${RED}❌ Error: Not in the correct project directory${NC}"
    echo "Please run this script from the cicd-pipeline root directory"
    echo "Expected to find either app/main.py or src/main.py"
    exit 1
fi

echo "✅ Confirmed: In correct project directory" >> "$logfile"
echo -e "${GREEN}✅ Confirmed: In correct project directory${NC}"
echo

echo -e "${BLUE}🐳 Step 2: Docker Environment${NC}"
echo "============================="

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
    echo "Docker installation required" >> "$logfile"
    exit 1
fi

echo -e "${GREEN}✅ Docker is installed${NC}"
echo "Docker version check passed" >> "$logfile"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon not running. Please start Docker.${NC}"
    echo "Docker daemon not running" >> "$logfile"
    echo "Please start Docker and re-run this script"
    exit 1
else
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
    echo "Docker daemon confirmed running" >> "$logfile"
fi
echo

echo -e "${BLUE}🐍 Step 3: Python Environment${NC}"
echo "=============================="

# Check Python
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo -e "${RED}❌ Python not found. Please install Python 3.8+ first.${NC}"
    echo "Python installation required" >> "$logfile"
    exit 1
fi

# Determine Python command
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
else
    PYTHON_CMD="python"
    PIP_CMD="pip"
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
echo -e "${GREEN}✅ Python $PYTHON_VERSION found${NC}"
echo "Python $PYTHON_VERSION confirmed" >> "$logfile"

# Check if virtual environment exists
if [[ ! -d "venv" ]]; then
    echo -e "${YELLOW}📦 Creating Python virtual environment...${NC}"
    echo "Creating virtual environment" >> "$logfile"
    $PYTHON_CMD -m venv venv
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Failed to create virtual environment${NC}"
        echo "Virtual environment creation failed" >> "$logfile"
        exit 1
    fi
    echo -e "${GREEN}✅ Virtual environment created${NC}"
    echo "Virtual environment created successfully" >> "$logfile"
else
    echo -e "${GREEN}✅ Virtual environment already exists${NC}"
    echo "Virtual environment exists" >> "$logfile"
fi

# Activate virtual environment
echo -e "${YELLOW}🔧 Activating virtual environment...${NC}"
source venv/bin/activate
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Failed to activate virtual environment${NC}"
    echo "Virtual environment activation failed" >> "$logfile"
    exit 1
fi
echo -e "${GREEN}✅ Virtual environment activated${NC}"
echo "Virtual environment activated" >> "$logfile"

# Install/upgrade pip
echo -e "${YELLOW}📦 Upgrading pip...${NC}"
$PYTHON_CMD -m pip install --upgrade pip >> "$logfile" 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${YELLOW}⚠️  Warning: Failed to upgrade pip${NC}"
    echo "Pip upgrade failed" >> "$logfile"
else
    echo -e "${GREEN}✅ Pip upgraded successfully${NC}"
    echo "Pip upgraded" >> "$logfile"
fi

# Install requirements
echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
echo "Installing Python dependencies" >> "$logfile"
if [[ -f "requirements.txt" ]]; then
    pip install -r requirements.txt >> "$logfile" 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Failed to install some dependencies${NC}"
        echo "Dependencies installation had errors" >> "$logfile"
        echo "Check $logfile for details"
    else
        echo -e "${GREEN}✅ All dependencies installed successfully${NC}"
        echo "Dependencies installed successfully" >> "$logfile"
    fi
else
    echo -e "${YELLOW}⚠️  requirements.txt not found, skipping dependency installation${NC}"
    echo "requirements.txt not found" >> "$logfile"
fi
echo

echo -e "${BLUE}☸️  Step 4: Kubernetes Environment${NC}"
echo "=================================="

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl not found - Kubernetes features will be limited${NC}"
    echo "kubectl not found" >> "$logfile"
else
    echo -e "${GREEN}✅ kubectl is available${NC}"
    echo "kubectl confirmed" >> "$logfile"
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        echo -e "${YELLOW}⚠️  Helm not found - Helm deployments unavailable${NC}"
        echo "Helm not found" >> "$logfile"
    else
        echo -e "${GREEN}✅ Helm is available${NC}"
        echo "Helm confirmed" >> "$logfile"
    fi
    
    # Check Minikube
    if ! command -v minikube &> /dev/null; then
        echo -e "${YELLOW}⚠️  Minikube not found - local Kubernetes testing unavailable${NC}"
        echo "Minikube not found" >> "$logfile"
    else
        echo -e "${GREEN}✅ Minikube is available${NC}"
        echo "Minikube confirmed" >> "$logfile"
        
        # Check Minikube status
        if ! minikube status &> /dev/null; then
            echo -e "${YELLOW}⏸️  Minikube cluster not running${NC}"
            echo "💡 To start: ./scripts/minikube-manage.sh start"
            echo "Minikube cluster not running" >> "$logfile"
        else
            echo -e "${GREEN}✅ Minikube cluster is running${NC}"
            echo "Minikube cluster running" >> "$logfile"
        fi
    fi
fi
echo

echo -e "${BLUE}🧪 Step 5: Environment Testing${NC}"
echo "==============================="

echo -e "${YELLOW}🔍 Testing CLI tool...${NC}"
if [[ -f "cli.py" ]]; then
    $PYTHON_CMD cli.py check-env >> "$logfile" 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ CLI tool test failed${NC}"
        echo "CLI tool test failed" >> "$logfile"
    else
        echo -e "${GREEN}✅ CLI tool is working${NC}"
        echo "CLI tool test passed" >> "$logfile"
    fi
else
    echo -e "${YELLOW}⚠️  CLI tool not found, skipping test${NC}"
    echo "CLI tool not found" >> "$logfile"
fi

echo -e "${YELLOW}🔍 Testing Docker build...${NC}"
docker build -t cicd-pipeline-test . >> "$logfile" 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Docker build test failed${NC}"
    echo "Docker build test failed" >> "$logfile"
    echo "Check $logfile for details"
else
    echo -e "${GREEN}✅ Docker build successful${NC}"
    echo "Docker build test passed" >> "$logfile"
    
    # Clean up test image
    docker rmi cicd-pipeline-test &> /dev/null
fi

echo -e "${YELLOW}🔍 Testing FastAPI app...${NC}"
if [[ -f "app/main.py" ]]; then
    $PYTHON_CMD -c "from app.main import app; print('FastAPI import successful')" 2>/dev/null
elif [[ -f "src/main.py" ]]; then
    $PYTHON_CMD -c "from src.main import app; print('FastAPI import successful')" 2>/dev/null
else
    echo -e "${YELLOW}⚠️  FastAPI main.py not found${NC}"
    skip_fastapi_test=true
fi

if [[ -z "$skip_fastapi_test" ]]; then
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ FastAPI app test failed${NC}"
        echo "FastAPI app test failed" >> "$logfile"
    else
        echo -e "${GREEN}✅ FastAPI app imports successfully${NC}"
        echo "FastAPI app test passed" >> "$logfile"
    fi
fi

echo -e "${YELLOW}🔍 Testing Helm chart...${NC}"
if [[ -f "helm/cicd-pipeline/Chart.yaml" ]] && command -v helm &> /dev/null; then
    helm lint helm/cicd-pipeline >> "$logfile" 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Helm chart validation failed${NC}"
        echo "Helm chart validation failed" >> "$logfile"
    else
        echo -e "${GREEN}✅ Helm chart is valid${NC}"
        echo "Helm chart validation passed" >> "$logfile"
    fi
else
    echo -e "${YELLOW}⚠️  Helm chart not found or Helm not available, skipping validation${NC}"
    echo "Helm chart validation skipped" >> "$logfile"
fi

echo -e "${YELLOW}🔍 Testing environment configuration...${NC}"
if [[ -f "environments/values-dev.yaml" ]]; then
    echo -e "${GREEN}✅ Environment configurations found${NC}"
    echo "Environment configurations found" >> "$logfile"
else
    echo -e "${YELLOW}⚠️  Environment configurations not found${NC}"
    echo "Environment configurations not found" >> "$logfile"
fi
echo

echo -e "${BLUE}📊 Step 6: Environment Summary${NC}"
echo "==============================="

echo -e "${PURPLE}🎯 Setup Results:${NC}"
echo "================"
echo "Environment setup completed at $(date)" >> "$logfile"

# Count successes and failures
SUCCESS_COUNT=$(grep -c "✅" "$logfile" || echo 0)
ERROR_COUNT=$(grep -c "❌" "$logfile" || echo 0)

echo "Successful checks: $SUCCESS_COUNT"
echo "Failed checks: $ERROR_COUNT"
echo "Full log: $logfile"

echo
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "============="

if [[ $ERROR_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✅ Environment setup completed successfully!${NC}"
    echo
    echo "Ready to proceed with:"
    echo "1. 🐳 Start local development: docker-compose up --build"
    echo "2. ☸️  Start Minikube: ./scripts/minikube-manage.sh start"
    echo "3. 🧪 Run tests: python -m pytest tests/"
    echo "4. 🚀 Deploy with Helm: helm install cicd-pipeline helm/cicd-pipeline"
    echo "5. 📊 Validate pipeline: ./scripts/validate-complete-pipeline.sh"
    echo "6. 🎯 Production deploy: ./scripts/deploy-production.sh --help"
    echo
    echo "🔗 Quick Commands:"
    echo "- System diagnostics: ./scripts/system-diagnostics.sh"
    echo "- Complete validation: ./scripts/validate-complete-pipeline.sh"
    echo "- Production deployment: ./scripts/deploy-production.sh"
else
    echo -e "${YELLOW}⚠️  Setup completed with $ERROR_COUNT issues${NC}"
    echo
    echo "Please address the following:"
    echo "1. Review the log file: $logfile"
    echo "2. Install missing prerequisites"
    echo "3. Re-run this setup script"
    echo
    echo "For help:"
    echo "- Run: ./scripts/system-diagnostics.sh"
    echo "- Review: PROJECT_STATUS_FINAL.md"
    echo "- Quick Setup: QUICK_SETUP_GUIDE.md"
fi

echo
echo -e "${BLUE}📚 Documentation:${NC}"
echo "================"
echo "- Project Status: PROJECT_STATUS_FINAL.md"
echo "- Quick Setup Guide: QUICK_SETUP_GUIDE.md"
echo "- Production Kit: PRODUCTION_DEPLOYMENT_KIT.md"
echo "- Deployment Checklist: DEPLOYMENT_CHECKLIST.md"
echo "- Helm Guide: HELM_DEPLOYMENT_GUIDE.md"

echo
echo -e "${BLUE}🏆 Advanced Features Available:${NC}"
echo "==============================="
echo "- GitOps with ArgoCD (gitops/ directory)"
echo "- Multi-environment deployments (environments/ directory)"
echo "- Custom Grafana dashboards (monitoring/dashboards/)"
echo "- Cross-platform scripts (Windows + Linux/macOS)"
echo "- Comprehensive validation tools"
echo "- Production-ready security configurations"

echo
echo "Environment setup summary saved to: $logfile"
echo
echo -e "${BLUE}🎯 Next Actions:${NC}"
echo "==============="
echo "1. Review setup log: $logfile"
echo "2. Run system diagnostics: ./scripts/system-diagnostics.sh"
echo "3. Follow quick setup: QUICK_SETUP_GUIDE.md"
echo "4. Deploy locally: docker-compose up --build"

echo
echo "Press Enter to continue..."
read -r
