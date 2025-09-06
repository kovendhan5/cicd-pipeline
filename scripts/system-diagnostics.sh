#!/bin/bash
# 🔧 CI/CD Pipeline System Setup & Diagnostics (Linux/macOS)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 CI/CD Pipeline System Setup & Diagnostics${NC}"
echo "=============================================="
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  WARNING: Running as root${NC}"
    echo "Some operations may not work correctly with root privileges"
    echo
fi

echo -e "${BLUE}📊 System Analysis:${NC}"
echo "=================="

# System Information
echo -e "${BLUE}🖥️  System Information:${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_NAME=$(lsb_release -si 2>/dev/null || echo "Linux")
    OS_VERSION=$(lsb_release -sr 2>/dev/null || uname -r)
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_NAME="macOS"
    OS_VERSION=$(sw_vers -productVersion)
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
    TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))
else
    OS_NAME="Unknown"
    OS_VERSION="Unknown"
    TOTAL_RAM_GB="Unknown"
fi

echo "  OS: $OS_NAME $OS_VERSION"
echo "  Total RAM: ${TOTAL_RAM_GB}GB"
echo

# CPU Information
echo -e "${BLUE}🔲 CPU Information:${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CPU_NAME=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    CPU_CORES=$(nproc)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_NAME=$(sysctl -n machdep.cpu.brand_string)
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    CPU_NAME="Unknown"
    CPU_CORES="Unknown"
fi

echo "  CPU: $CPU_NAME"
echo "  Cores: $CPU_CORES"
echo

# Disk Space
echo -e "${BLUE}💾 Storage Information:${NC}"
FREE_SPACE_HUMAN=$(df -h / | awk 'NR==2{print $4}')
FREE_SPACE_GB=$(df / | awk 'NR==2{print int($4/1024/1024)}')
echo "  Free Space: ${FREE_SPACE_HUMAN} (${FREE_SPACE_GB}GB)"
if [[ $FREE_SPACE_GB -lt 20 ]]; then
    echo -e "  ${RED}⚠️  WARNING: Low disk space - less than 20GB free${NC}"
else
    echo -e "  ${GREEN}✅ Adequate disk space available${NC}"
fi
echo

echo -e "${BLUE}🔍 Prerequisites Check:${NC}"
echo "======================="

# Check Docker
echo -e "${BLUE}🐳 Docker:${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo -e "  ${GREEN}✅ Docker installed - Version $DOCKER_VERSION${NC}"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo -e "  ${GREEN}✅ Docker daemon is running${NC}"
    else
        echo -e "  ${RED}❌ Docker daemon not running${NC}"
    fi
else
    echo -e "  ${RED}❌ Docker not installed or not in PATH${NC}"
    echo "  💡 Install from: https://docs.docker.com/get-docker/"
fi
echo

# Check kubectl
echo -e "${BLUE}☸️  Kubernetes CLI (kubectl):${NC}"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || echo "installed")
    echo -e "  ${GREEN}✅ kubectl installed - $KUBECTL_VERSION${NC}"
    
    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        echo -e "  ${GREEN}✅ Connected to Kubernetes cluster${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Not connected to any Kubernetes cluster${NC}"
    fi
else
    echo -e "  ${RED}❌ kubectl not installed or not in PATH${NC}"
    echo "  💡 Install from: https://kubernetes.io/docs/tasks/tools/"
fi
echo

# Check Helm
echo -e "${BLUE}⚓ Helm:${NC}"
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | awk '{print $1}' || echo "installed")
    echo -e "  ${GREEN}✅ Helm installed - $HELM_VERSION${NC}"
else
    echo -e "  ${RED}❌ Helm not installed or not in PATH${NC}"
    echo "  💡 Install from: https://helm.sh/docs/intro/install/"
fi
echo

# Check Minikube
echo -e "${BLUE}🎯 Minikube:${NC}"
if command -v minikube &> /dev/null; then
    MINIKUBE_VERSION=$(minikube version | grep "minikube version" | awk '{print $3}')
    echo -e "  ${GREEN}✅ Minikube installed - $MINIKUBE_VERSION${NC}"
    
    # Check Minikube status
    if minikube status &> /dev/null; then
        echo -e "  ${GREEN}✅ Minikube cluster is running${NC}"
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "N/A")
        echo "  Cluster IP: $MINIKUBE_IP"
    else
        echo -e "  ${YELLOW}⏸️  Minikube cluster is stopped${NC}"
    fi
else
    echo -e "  ${RED}❌ Minikube not installed or not in PATH${NC}"
    echo "  💡 Install from: https://minikube.sigs.k8s.io/docs/start/"
fi
echo

# Check Python
echo -e "${BLUE}🐍 Python:${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo -e "  ${GREEN}✅ Python installed - $PYTHON_VERSION${NC}"
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        echo -e "  ${GREEN}✅ pip3 available${NC}"
    else
        echo -e "  ${RED}❌ pip3 not available${NC}"
    fi
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version | awk '{print $2}')
    echo -e "  ${GREEN}✅ Python installed - $PYTHON_VERSION${NC}"
    
    # Check pip
    if command -v pip &> /dev/null; then
        echo -e "  ${GREEN}✅ pip available${NC}"
    else
        echo -e "  ${RED}❌ pip not available${NC}"
    fi
else
    echo -e "  ${RED}❌ Python not installed or not in PATH${NC}"
    echo "  💡 Install from: https://www.python.org/downloads/"
fi
echo

# Check Git
echo -e "${BLUE}📝 Git:${NC}"
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | awk '{print $3}')
    echo -e "  ${GREEN}✅ Git installed - $GIT_VERSION${NC}"
else
    echo -e "  ${RED}❌ Git not installed or not in PATH${NC}"
    echo "  💡 Install from: https://git-scm.com/downloads"
fi
echo

# Check Node.js (optional)
echo -e "${BLUE}📦 Node.js (Optional):${NC}"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "  ${GREEN}✅ Node.js installed - $NODE_VERSION${NC}"
    
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        echo -e "  ${GREEN}✅ npm available - $NPM_VERSION${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠️  Node.js not installed (optional for some tools)${NC}"
    echo "  💡 Install from: https://nodejs.org/"
fi
echo

echo -e "${BLUE}🚀 Recommendations:${NC}"
echo "==================="

echo -e "${BLUE}📋 System Requirements Status:${NC}"
if [[ $TOTAL_RAM_GB -lt 8 ]]; then
    echo -e "  ${RED}❌ RAM: ${TOTAL_RAM_GB}GB (Minimum 8GB recommended)${NC}"
elif [[ $TOTAL_RAM_GB -lt 16 ]]; then
    echo -e "  ${YELLOW}⚠️  RAM: ${TOTAL_RAM_GB}GB (16GB+ recommended for optimal performance)${NC}"
else
    echo -e "  ${GREEN}✅ RAM: ${TOTAL_RAM_GB}GB (Excellent)${NC}"
fi

if [[ $CPU_CORES -lt 4 ]]; then
    echo -e "  ${YELLOW}⚠️  CPU: $CPU_CORES cores (4+ cores recommended)${NC}"
else
    echo -e "  ${GREEN}✅ CPU: $CPU_CORES cores (Good)${NC}"
fi

if [[ $FREE_SPACE_GB -lt 20 ]]; then
    echo -e "  ${RED}❌ Storage: ${FREE_SPACE_GB}GB free (20GB+ recommended)${NC}"
else
    echo -e "  ${GREEN}✅ Storage: ${FREE_SPACE_GB}GB free (Good)${NC}"
fi
echo

echo -e "${BLUE}🔧 Setup Actions:${NC}"
echo "================"

echo "1. 📥 Install Missing Prerequisites:"
command -v docker &> /dev/null || echo "   - Install Docker: https://docs.docker.com/get-docker/"
command -v kubectl &> /dev/null || echo "   - Install kubectl: https://kubernetes.io/docs/tasks/tools/"
command -v helm &> /dev/null || echo "   - Install Helm: https://helm.sh/docs/intro/install/"
command -v minikube &> /dev/null || echo "   - Install Minikube: https://minikube.sigs.k8s.io/docs/start/"
command -v python3 &> /dev/null || command -v python &> /dev/null || echo "   - Install Python: https://www.python.org/downloads/"
command -v git &> /dev/null || echo "   - Install Git: https://git-scm.com/downloads"

echo
echo "2. 🐳 Configure Docker:"
echo "   - Ensure Docker daemon is running"
echo "   - Allocate 6-8GB RAM minimum"
echo "   - Configure resource limits"

echo
echo "3. ☸️  Initialize Minikube:"
echo "   - Run: ./scripts/minikube-manage.sh start"
echo "   - Or: minikube start --driver=docker --cpus=4 --memory=6144"

echo
echo "4. 🛠️  Setup Development Environment:"
echo "   - Run: ./scripts/dev-setup.sh"
echo "   - Install Python dependencies: pip3 install -r requirements.txt"

echo
echo "5. 🧪 Test Setup:"
echo "   - Run: python3 cli.py check-env"
echo "   - Run: docker-compose up --build"
echo "   - Run: ./scripts/test-minikube.sh"

echo
echo "6. 📊 Performance Testing:"
echo "   - Run: ./scripts/validate-complete-pipeline.sh"
echo "   - Load test: k6 run tests/load-test.js"
echo "   - Monitor: kubectl top pods --all-namespaces"

echo
echo "7. 🚀 Production Deployment:"
echo "   - Run: ./scripts/deploy-production.sh --dry-run"
echo "   - Deploy: ./scripts/deploy-production.sh --namespace production"
echo "   - Monitor: kubectl get pods -n production -w"

echo
echo -e "${BLUE}📞 Need Help?${NC}"
echo "============="
echo "- Review: QUICK_SETUP_GUIDE.md"
echo "- Project Status: PROJECT_FINAL_SUMMARY.md"
echo "- Deployment Guide: PRODUCTION_DEPLOYMENT_KIT.md"
echo "- Complete Checklist: DEPLOYMENT_CHECKLIST.md"
echo "- Helm Guide: HELM_DEPLOYMENT_GUIDE.md"
echo "- Troubleshooting: ./scripts/minikube-manage.sh troubleshoot"

echo
echo -e "${BLUE}🏆 Advanced Features Available:${NC}"
echo "==============================="
echo "- GitOps with ArgoCD"
echo "- Multi-environment Helm deployments"
echo "- Custom Grafana monitoring dashboards"
echo "- Automated backup and rollback procedures"
echo "- Cross-platform deployment scripts"
echo "- Security scanning and compliance checks"

echo
echo -e "${BLUE}🎯 Quick Commands:${NC}"
echo "=================="
echo "For immediate testing:"
echo "  ./scripts/validate-complete-pipeline.sh"
echo
echo "For production deployment:"
echo "  ./scripts/deploy-production.sh --help"
echo
echo "For development environment:"
echo "  docker-compose up --build"
echo "  minikube start"
echo "  ./scripts/test-minikube.sh"

echo
echo "Press Enter to continue..."
read -r
