#!/usr/bin/env python3
"""
Command-line interface for the CI/CD pipeline
"""
import click
import asyncio
import uvicorn
from pathlib import Path
import subprocess
import sys
import os

@click.group()
def cli():
    """CI/CD Pipeline Management CLI"""
    pass

@cli.command()
@click.option('--host', default='0.0.0.0', help='Host to bind to')
@click.option('--port', default=8000, help='Port to bind to')
@click.option('--reload', is_flag=True, help='Enable auto-reload')
@click.option('--workers', default=1, help='Number of worker processes')
def serve(host, port, reload, workers):
    """Start the API server"""
    click.echo(f"🚀 Starting CI/CD Pipeline API on {host}:{port}")
    
    if reload:
        uvicorn.run(
            "src.main:app",
            host=host,
            port=port,
            reload=reload,
            log_level="info"
        )
    else:
        uvicorn.run(
            "src.main:app",
            host=host,
            port=port,
            workers=workers,
            log_level="info"
        )

@cli.command()
def init_db():
    """Initialize the database with tables and sample data"""
    click.echo("🗄️  Initializing database...")
    
    try:
        from src.database import create_tables
        create_tables()
        click.echo("✅ Database initialized successfully!")
    except Exception as e:
        click.echo(f"❌ Database initialization failed: {e}")
        sys.exit(1)

@cli.command()
@click.confirmation_option(prompt="Are you sure you want to drop all tables?")
def drop_db():
    """Drop all database tables"""
    click.echo("🗑️  Dropping database tables...")
    
    try:
        from src.database import drop_tables
        drop_tables()
        click.echo("✅ Database tables dropped successfully!")
    except Exception as e:
        click.echo(f"❌ Failed to drop tables: {e}")
        sys.exit(1)

@cli.command()
def test():
    """Run the test suite"""
    click.echo("🧪 Running tests...")
    
    result = subprocess.run([
        sys.executable, "-m", "pytest", 
        "tests/", "-v", "--cov=src", "--cov-report=term-missing"
    ])
    
    if result.returncode == 0:
        click.echo("✅ All tests passed!")
    else:
        click.echo("❌ Some tests failed!")
        sys.exit(1)

@cli.command()
def lint():
    """Run code quality checks"""
    click.echo("🔍 Running code quality checks...")
    
    checks = [
        (["black", "--check", "."], "Black formatting"),
        (["isort", "--check-only", "."], "Import sorting"),
        (["flake8", "."], "Flake8 linting"),
        (["mypy", "src"], "Type checking"),
    ]
    
    failed = False
    for cmd, name in checks:
        click.echo(f"Running {name}...")
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            click.echo(f"✅ {name} passed")
        else:
            click.echo(f"❌ {name} failed:")
            click.echo(result.stdout)
            click.echo(result.stderr)
            failed = True
    
    if failed:
        sys.exit(1)
    else:
        click.echo("✅ All checks passed!")

@cli.command()
def format_code():
    """Format code with black and isort"""
    click.echo("🎨 Formatting code...")
    
    subprocess.run(["black", "."])
    subprocess.run(["isort", "."])
    
    click.echo("✅ Code formatted!")

@cli.command()
@click.option('--environment', default='development', 
              type=click.Choice(['development', 'staging', 'production']))
def deploy(environment):
    """Deploy the application"""
    click.echo(f"🚀 Deploying to {environment}...")
    
    script_name = "deploy.bat" if os.name == "nt" else "deploy.sh"
    script_path = Path("scripts") / script_name
    
    if not script_path.exists():
        click.echo(f"❌ Deploy script not found: {script_path}")
        sys.exit(1)
    
    if os.name != "nt":  # Make script executable on Unix-like systems
        subprocess.run(["chmod", "+x", str(script_path)])
    
    result = subprocess.run([str(script_path), environment])
    
    if result.returncode == 0:
        click.echo(f"✅ Deployment to {environment} completed!")
    else:
        click.echo(f"❌ Deployment to {environment} failed!")
        sys.exit(1)

@cli.command()
def build():
    """Build Docker image"""
    click.echo("🐳 Building Docker image...")
    
    result = subprocess.run([
        "docker", "build", "-t", "cicd-pipeline:latest", "."
    ])
    
    if result.returncode == 0:
        click.echo("✅ Docker image built successfully!")
    else:
        click.echo("❌ Docker build failed!")
        sys.exit(1)

@cli.command()
@click.option('--services', default='all', help='Services to start (comma-separated)')
def up(services):
    """Start services with docker-compose"""
    click.echo("🐳 Starting services...")
    
    cmd = ["docker-compose", "up", "-d"]
    if services != 'all':
        cmd.extend(services.split(','))
    
    result = subprocess.run(cmd)
    
    if result.returncode == 0:
        click.echo("✅ Services started successfully!")
        click.echo("🌐 API: http://localhost:8000")
        click.echo("📊 Grafana: http://localhost:3000")
        click.echo("📈 Prometheus: http://localhost:9090")
    else:
        click.echo("❌ Failed to start services!")
        sys.exit(1)

@cli.command()
def down():
    """Stop services"""
    click.echo("🛑 Stopping services...")
    
    result = subprocess.run(["docker-compose", "down"])
    
    if result.returncode == 0:
        click.echo("✅ Services stopped successfully!")
    else:
        click.echo("❌ Failed to stop services!")
        sys.exit(1)

@cli.command()
def logs():
    """Show logs from services"""
    click.echo("📜 Showing logs...")
    subprocess.run(["docker-compose", "logs", "-f"])

@cli.command()
def status():
    """Show status of services"""
    click.echo("📊 Service status:")
    subprocess.run(["docker-compose", "ps"])

if __name__ == "__main__":
    cli()
