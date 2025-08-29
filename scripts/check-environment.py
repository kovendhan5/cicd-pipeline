#!/usr/bin/env python3
"""
CI/CD Pipeline Environment Checker
Validates the complete development and deployment environment
"""

import subprocess
import sys
import json
import os
import platform
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import urllib.request
import socket

class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

class EnvironmentChecker:
    """Environment validation and setup checker"""
    
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.success_count = 0
        self.total_checks = 0
        
    def print_header(self, title: str):
        """Print a formatted header"""
        print(f"\n{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.END}")
        print(f"{Colors.CYAN}{Colors.BOLD}{title.center(60)}{Colors.END}")
        print(f"{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.END}\n")
    
    def print_check(self, name: str, status: bool, message: str = "", warning: bool = False):
        """Print a check result"""
        self.total_checks += 1
        if status:
            self.success_count += 1
            icon = f"{Colors.GREEN}✅{Colors.END}"
        elif warning:
            icon = f"{Colors.YELLOW}⚠️{Colors.END}"
            self.warnings.append(f"{name}: {message}")
        else:
            icon = f"{Colors.RED}❌{Colors.END}"
            self.issues.append(f"{name}: {message}")
        
        print(f"{icon} {Colors.BOLD}{name}{Colors.END}")
        if message:
            print(f"   {message}")
    
    def run_command(self, command: List[str], capture_output: bool = True) -> Tuple[bool, str]:
        """Run a command and return success status and output"""
        try:
            result = subprocess.run(
                command,
                capture_output=capture_output,
                text=True,
                timeout=30
            )
            return result.returncode == 0, result.stdout.strip()
        except (subprocess.TimeoutExpired, FileNotFoundError, subprocess.SubprocessError):
            return False, ""
    
    def check_system_requirements(self):
        """Check system requirements"""
        self.print_header("🖥️ SYSTEM REQUIREMENTS")
        
        # Check OS
        os_name = platform.system()
        os_version = platform.release()
        self.print_check(
            "Operating System",
            True,
            f"{os_name} {os_version}"
        )
        
        # Check Python version
        python_version = platform.python_version()
        version_parts = [int(x) for x in python_version.split('.')]
        python_ok = version_parts >= [3, 8]
        
        self.print_check(
            "Python Version",
            python_ok,
            f"Python {python_version} {'✓' if python_ok else '(requires 3.8+)'}"
        )
        
        # Check available memory (approximate)
        try:
            if platform.system() == "Windows":
                success, output = self.run_command(["wmic", "computersystem", "get", "TotalPhysicalMemory", "/value"])
                if success:
                    for line in output.split('\n'):
                        if 'TotalPhysicalMemory=' in line:
                            memory_bytes = int(line.split('=')[1])
                            memory_gb = round(memory_bytes / (1024**3))
                            break
                    else:
                        memory_gb = 0
                else:
                    memory_gb = 0
            else:
                # Linux/macOS - use available tools
                success, output = self.run_command(["free", "-g"])
                if success:
                    lines = output.split('\n')
                    memory_line = next((line for line in lines if 'Mem:' in line), None)
                    if memory_line:
                        memory_gb = int(memory_line.split()[1])
                    else:
                        memory_gb = 0
                else:
                    memory_gb = 8  # Assume reasonable amount
            
            memory_ok = memory_gb >= 8
            self.print_check(
                "System Memory",
                memory_ok,
                f"{memory_gb}GB RAM {'✓' if memory_ok else '(8GB+ recommended)'}"
            )
            
        except (ValueError, IndexError):
            self.print_check(
                "System Memory",
                True,
                "Unable to detect (assuming adequate)",
                warning=True
            )
    
    def check_docker(self):
        """Check Docker installation and configuration"""
        self.print_header("🐳 DOCKER")
        
        # Check Docker installation
        docker_installed, docker_version = self.run_command(["docker", "--version"])
        self.print_check(
            "Docker Installation",
            docker_installed,
            f"Docker {docker_version.split()[-1] if docker_installed else 'not found'}"
        )
        
        if docker_installed:
            # Check Docker daemon
            daemon_running, _ = self.run_command(["docker", "info"])
            self.print_check(
                "Docker Daemon",
                daemon_running,
                "Running" if daemon_running else "Not running - start Docker Desktop"
            )
            
            if daemon_running:
                # Check Docker resources
                success, output = self.run_command(["docker", "info"])
                if success:
                    lines = output.split('\n')
                    for line in lines:
                        if 'Total Memory:' in line:
                            memory = line.split(':')[1].strip()
                            self.print_check("Docker Memory", True, memory)
                        elif 'CPUs:' in line:
                            cpus = line.split(':')[1].strip()
                            self.print_check("Docker CPUs", True, cpus)
    
    def check_kubernetes_tools(self):
        """Check Kubernetes tools"""
        self.print_header("☸️ KUBERNETES TOOLS")
        
        # Check kubectl
        kubectl_installed, kubectl_version = self.run_command(["kubectl", "version", "--client", "--short"])
        self.print_check(
            "kubectl",
            kubectl_installed,
            kubectl_version if kubectl_installed else "not found"
        )
        
        # Check Helm
        helm_installed, helm_version = self.run_command(["helm", "version", "--short"])
        self.print_check(
            "Helm",
            helm_installed,
            helm_version if helm_installed else "not found"
        )
        
        # Check Minikube
        minikube_installed, minikube_version = self.run_command(["minikube", "version"])
        if minikube_installed:
            version_line = next((line for line in minikube_version.split('\n') if 'minikube version:' in line), "")
            version = version_line.split(':')[-1].strip() if version_line else minikube_version
        else:
            version = "not found"
        
        self.print_check(
            "Minikube",
            minikube_installed,
            version
        )
        
        if minikube_installed:
            # Check Minikube status
            minikube_running, status_output = self.run_command(["minikube", "status"])
            self.print_check(
                "Minikube Cluster",
                minikube_running,
                "Running" if minikube_running else "Stopped"
            )
            
            if minikube_running and kubectl_installed:
                # Test cluster connectivity
                cluster_accessible, _ = self.run_command(["kubectl", "cluster-info"])
                self.print_check(
                    "Cluster Access",
                    cluster_accessible,
                    "Accessible" if cluster_accessible else "Cannot connect"
                )
    
    def check_development_tools(self):
        """Check development tools"""
        self.print_header("🛠️ DEVELOPMENT TOOLS")
        
        # Check Git
        git_installed, git_version = self.run_command(["git", "--version"])
        self.print_check(
            "Git",
            git_installed,
            git_version if git_installed else "not found"
        )
        
        # Check Python packages
        required_packages = [
            "fastapi", "uvicorn", "sqlalchemy", "redis", "pytest",
            "docker", "kubernetes", "pydantic"
        ]
        
        for package in required_packages:
            try:
                __import__(package.replace("-", "_"))
                self.print_check(f"Python package: {package}", True, "Installed")
            except ImportError:
                self.print_check(f"Python package: {package}", False, "Not installed")
    
    def check_project_structure(self):
        """Check project structure"""
        self.print_header("📁 PROJECT STRUCTURE")
        
        required_files = [
            "app/main.py",
            "app/models.py",
            "app/database.py",
            "Dockerfile",
            "docker-compose.yml",
            "requirements.txt",
            "helm/cicd-pipeline/Chart.yaml",
            "helm/cicd-pipeline/values.yaml",
            ".github/workflows/ci-cd.yml",
            "k8s/namespace.yaml",
            "k8s/deployment.yaml",
            "k8s/service.yaml"
        ]
        
        project_root = Path.cwd()
        for file_path in required_files:
            full_path = project_root / file_path
            exists = full_path.exists()
            self.print_check(
                f"File: {file_path}",
                exists,
                "Found" if exists else "Missing"
            )
    
    def check_network_connectivity(self):
        """Check network connectivity"""
        self.print_header("🌐 NETWORK CONNECTIVITY")
        
        # Check internet connectivity
        try:
            urllib.request.urlopen('https://www.google.com', timeout=10)
            self.print_check("Internet Connectivity", True, "Connected")
        except Exception:
            self.print_check("Internet Connectivity", False, "No connection")
        
        # Check Docker Hub connectivity
        try:
            urllib.request.urlopen('https://hub.docker.com', timeout=10)
            self.print_check("Docker Hub", True, "Accessible")
        except Exception:
            self.print_check("Docker Hub", False, "Not accessible")
        
        # Check GitHub connectivity
        try:
            urllib.request.urlopen('https://github.com', timeout=10)
            self.print_check("GitHub", True, "Accessible")
        except Exception:
            self.print_check("GitHub", False, "Not accessible")
    
    def check_environment_files(self):
        """Check environment configuration files"""
        self.print_header("⚙️ ENVIRONMENT CONFIGURATION")
        
        env_files = [
            "environments/values-dev.yaml",
            "environments/values-staging.yaml",
            "environments/values-prod.yaml",
            "environments/values-minikube.yaml"
        ]
        
        for env_file in env_files:
            exists = Path(env_file).exists()
            self.print_check(
                f"Config: {env_file}",
                exists,
                "Found" if exists else "Missing"
            )
    
    def generate_report(self):
        """Generate final report"""
        self.print_header("📊 ENVIRONMENT REPORT")
        
        success_rate = (self.success_count / self.total_checks * 100) if self.total_checks > 0 else 0
        
        print(f"{Colors.BOLD}Overall Status:{Colors.END}")
        print(f"  ✅ Successful checks: {self.success_count}/{self.total_checks} ({success_rate:.1f}%)")
        print(f"  ⚠️  Warnings: {len(self.warnings)}")
        print(f"  ❌ Issues: {len(self.issues)}")
        
        if self.warnings:
            print(f"\n{Colors.YELLOW}{Colors.BOLD}⚠️ WARNINGS:{Colors.END}")
            for warning in self.warnings:
                print(f"  • {warning}")
        
        if self.issues:
            print(f"\n{Colors.RED}{Colors.BOLD}❌ ISSUES TO RESOLVE:{Colors.END}")
            for issue in self.issues:
                print(f"  • {issue}")
            
            print(f"\n{Colors.BLUE}{Colors.BOLD}💡 RECOMMENDATIONS:{Colors.END}")
            print("  1. Install missing tools using package managers:")
            print("     - Windows: choco install docker-desktop kubernetes-cli minikube")
            print("     - macOS: brew install docker kubectl minikube helm")
            print("     - Linux: Use your distribution's package manager")
            print("  2. Install Python dependencies: pip install -r requirements.txt")
            print("  3. Start Docker Desktop and enable Kubernetes")
            print("  4. Initialize Minikube: minikube start --driver=docker")
        
        # Overall assessment
        if success_rate >= 90:
            print(f"\n{Colors.GREEN}{Colors.BOLD}🎉 EXCELLENT! Your environment is ready for development.{Colors.END}")
        elif success_rate >= 75:
            print(f"\n{Colors.YELLOW}{Colors.BOLD}👍 GOOD! Your environment is mostly ready with minor issues.{Colors.END}")
        else:
            print(f"\n{Colors.RED}{Colors.BOLD}🔧 NEEDS WORK! Please resolve the issues above before proceeding.{Colors.END}")
        
        return len(self.issues) == 0
    
    def run_all_checks(self):
        """Run all environment checks"""
        print(f"{Colors.CYAN}{Colors.BOLD}")
        print("🔍 CI/CD Pipeline Environment Checker")
        print("====================================")
        print(f"{Colors.END}")
        
        self.check_system_requirements()
        self.check_docker()
        self.check_kubernetes_tools()
        self.check_development_tools()
        self.check_project_structure()
        self.check_environment_files()
        self.check_network_connectivity()
        
        return self.generate_report()

def main():
    """Main entry point"""
    checker = EnvironmentChecker()
    
    try:
        success = checker.run_all_checks()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Check interrupted by user{Colors.END}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Unexpected error: {e}{Colors.END}")
        sys.exit(1)

if __name__ == "__main__":
    main()
