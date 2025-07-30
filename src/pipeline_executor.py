"""
Pipeline execution engine
"""
import asyncio
import subprocess
import tempfile
import shutil
import os
import docker
from datetime import datetime
from typing import Dict, List, Optional
from sqlalchemy.orm import Session
import structlog

from src.database import SessionLocal
from src.models import Pipeline, PipelineStep, Artifact
from src.config import get_settings

logger = structlog.get_logger()

class PipelineExecutor:
    """Pipeline execution engine"""
    
    def __init__(self):
        self.settings = get_settings()
        self.docker_client = docker.from_env()
    
    async def execute_pipeline(self, pipeline_id: str) -> bool:
        """Execute a complete pipeline"""
        db = SessionLocal()
        try:
            pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
            if not pipeline:
                logger.error("Pipeline not found", pipeline_id=pipeline_id)
                return False
            
            logger.info("Starting pipeline execution", pipeline_id=pipeline_id)
            
            # Update pipeline status
            pipeline.status = "running"
            pipeline.started_at = datetime.utcnow()
            db.commit()
            
            # Get pipeline steps
            steps = db.query(PipelineStep).filter(
                PipelineStep.pipeline_id == pipeline_id
            ).order_by(PipelineStep.step_order).all()
            
            success = True
            for step in steps:
                step_success = await self.execute_step(step, db)
                if not step_success:
                    success = False
                    break
            
            # Update final pipeline status
            pipeline.status = "success" if success else "failed"
            pipeline.completed_at = datetime.utcnow()
            if pipeline.started_at:
                duration = (pipeline.completed_at - pipeline.started_at).total_seconds()
                pipeline.duration_seconds = int(duration)
            
            db.commit()
            
            logger.info("Pipeline execution completed", 
                       pipeline_id=pipeline_id, 
                       status=pipeline.status)
            
            return success
            
        except Exception as e:
            logger.error("Pipeline execution failed", 
                        pipeline_id=pipeline_id, 
                        error=str(e))
            
            # Update pipeline status to failed
            pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
            if pipeline:
                pipeline.status = "failed"
                pipeline.completed_at = datetime.utcnow()
                db.commit()
            
            return False
        finally:
            db.close()
    
    async def execute_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute a single pipeline step"""
        logger.info("Executing step", 
                   step_name=step.step_name, 
                   pipeline_id=str(step.pipeline_id))
        
        # Update step status
        step.status = "running"
        step.started_at = datetime.utcnow()
        db.commit()
        
        try:
            # Execute step based on name
            if step.step_name.lower() == "checkout":
                success = await self.execute_checkout_step(step, db)
            elif step.step_name.lower() == "build":
                success = await self.execute_build_step(step, db)
            elif step.step_name.lower() == "test":
                success = await self.execute_test_step(step, db)
            elif step.step_name.lower() == "security scan":
                success = await self.execute_security_step(step, db)
            elif step.step_name.lower() == "deploy":
                success = await self.execute_deploy_step(step, db)
            else:
                logger.warning("Unknown step type", step_name=step.step_name)
                success = True  # Skip unknown steps
            
            # Update step completion
            step.status = "success" if success else "failed"
            step.completed_at = datetime.utcnow()
            if step.started_at:
                duration = (step.completed_at - step.started_at).total_seconds()
                step.duration_seconds = int(duration)
            
            db.commit()
            
            return success
            
        except Exception as e:
            logger.error("Step execution failed", 
                        step_name=step.step_name, 
                        error=str(e))
            
            step.status = "failed"
            step.completed_at = datetime.utcnow()
            step.error_message = str(e)
            db.commit()
            
            return False
    
    async def execute_checkout_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute checkout step"""
        pipeline = db.query(Pipeline).filter(Pipeline.id == step.pipeline_id).first()
        repository = pipeline.repository
        
        # Create temporary directory for checkout
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Clone repository
            cmd = [
                "git", "clone", "--depth", "1", 
                "--branch", pipeline.branch or "main",
                repository.url, temp_dir
            ]
            
            result = await self.run_command(cmd)
            
            if result.returncode == 0:
                step.logs = f"Successfully cloned repository to {temp_dir}"
                return True
            else:
                step.logs = f"Git clone failed: {result.stderr}"
                return False
                
        except Exception as e:
            step.logs = f"Checkout failed: {str(e)}"
            return False
        finally:
            # Cleanup temp directory
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir, ignore_errors=True)
    
    async def execute_build_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute build step"""
        pipeline = db.query(Pipeline).filter(Pipeline.id == step.pipeline_id).first()
        
        try:
            # Build Docker image
            image_tag = f"pipeline-{pipeline.id}:{pipeline.commit_hash[:8]}"
            
            # Simulate build process
            build_logs = []
            build_logs.append("Starting Docker build...")
            build_logs.append(f"Building image: {image_tag}")
            build_logs.append("Step 1/5: FROM python:3.9-slim")
            build_logs.append("Step 2/5: WORKDIR /app")
            build_logs.append("Step 3/5: COPY requirements.txt .")
            build_logs.append("Step 4/5: RUN pip install -r requirements.txt")
            build_logs.append("Step 5/5: COPY . .")
            build_logs.append("Successfully built image")
            
            step.logs = "\n".join(build_logs)
            
            # Create artifact record
            artifact = Artifact(
                pipeline_id=pipeline.id,
                name=f"docker-image-{pipeline.commit_hash[:8]}",
                type="docker_image",
                url=f"docker://{image_tag}",
                size_bytes=1024 * 1024 * 100  # 100MB example
            )
            db.add(artifact)
            
            return True
            
        except Exception as e:
            step.logs = f"Build failed: {str(e)}"
            return False
    
    async def execute_test_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute test step"""
        try:
            # Simulate test execution
            test_logs = []
            test_logs.append("Running test suite...")
            test_logs.append("pytest tests/ -v --cov=src")
            test_logs.append("test_main.py::test_root_endpoint PASSED")
            test_logs.append("test_main.py::test_health_check PASSED")
            test_logs.append("test_main.py::test_pipeline_status PASSED")
            test_logs.append("Coverage: 85%")
            test_logs.append("All tests passed!")
            
            step.logs = "\n".join(test_logs)
            
            # Create test report artifact
            pipeline = db.query(Pipeline).filter(Pipeline.id == step.pipeline_id).first()
            artifact = Artifact(
                pipeline_id=pipeline.id,
                name="test-report",
                type="test_report",
                url="/artifacts/test-report.html",
                size_bytes=1024 * 50  # 50KB example
            )
            db.add(artifact)
            
            return True
            
        except Exception as e:
            step.logs = f"Tests failed: {str(e)}"
            return False
    
    async def execute_security_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute security scan step"""
        try:
            # Simulate security scan
            security_logs = []
            security_logs.append("Running security scans...")
            security_logs.append("Bandit security scan: PASSED")
            security_logs.append("Safety dependency check: PASSED")
            security_logs.append("Docker image scan: PASSED")
            security_logs.append("No security vulnerabilities found")
            
            step.logs = "\n".join(security_logs)
            
            # Create security report artifact
            pipeline = db.query(Pipeline).filter(Pipeline.id == step.pipeline_id).first()
            artifact = Artifact(
                pipeline_id=pipeline.id,
                name="security-report",
                type="security_report",
                url="/artifacts/security-report.json",
                size_bytes=1024 * 10  # 10KB example
            )
            db.add(artifact)
            
            return True
            
        except Exception as e:
            step.logs = f"Security scan failed: {str(e)}"
            return False
    
    async def execute_deploy_step(self, step: PipelineStep, db: Session) -> bool:
        """Execute deployment step"""
        try:
            # Simulate deployment
            deploy_logs = []
            deploy_logs.append("Starting deployment...")
            deploy_logs.append("Pushing image to registry...")
            deploy_logs.append("Updating Kubernetes deployment...")
            deploy_logs.append("Rolling out new version...")
            deploy_logs.append("Deployment completed successfully!")
            
            step.logs = "\n".join(deploy_logs)
            
            return True
            
        except Exception as e:
            step.logs = f"Deployment failed: {str(e)}"
            return False
    
    async def run_command(self, cmd: List[str], cwd: Optional[str] = None) -> subprocess.CompletedProcess:
        """Run a shell command asynchronously"""
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=cwd
        )
        
        stdout, stderr = await process.communicate()
        
        return subprocess.CompletedProcess(
            args=cmd,
            returncode=process.returncode,
            stdout=stdout.decode(),
            stderr=stderr.decode()
        )

# Global executor instance
pipeline_executor = PipelineExecutor()
