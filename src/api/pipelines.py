"""
API endpoints for pipeline management
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
import structlog

from src.database import get_db
from src.models import Pipeline, PipelineStep, Repository, User
from src.schemas import (
    PipelineCreate, PipelineResponse, PipelineStepResponse,
    PipelineUpdate, PipelineListResponse
)

logger = structlog.get_logger()
router = APIRouter(prefix="/api/v1/pipelines", tags=["pipelines"])

@router.post("/", response_model=PipelineResponse)
async def create_pipeline(
    pipeline: PipelineCreate,
    db: Session = Depends(get_db)
):
    """Create a new pipeline"""
    logger.info("Creating new pipeline", name=pipeline.name)
    
    # Check if repository exists
    repository = db.query(Repository).filter(Repository.id == pipeline.repository_id).first()
    if not repository:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Repository not found"
        )
    
    db_pipeline = Pipeline(**pipeline.dict())
    db.add(db_pipeline)
    db.commit()
    db.refresh(db_pipeline)
    
    logger.info("Pipeline created successfully", pipeline_id=str(db_pipeline.id))
    return db_pipeline

@router.get("/", response_model=List[PipelineListResponse])
async def list_pipelines(
    skip: int = 0,
    limit: int = 100,
    status: Optional[str] = None,
    repository_id: Optional[UUID] = None,
    db: Session = Depends(get_db)
):
    """List pipelines with optional filtering"""
    query = db.query(Pipeline)
    
    if status:
        query = query.filter(Pipeline.status == status)
    if repository_id:
        query = query.filter(Pipeline.repository_id == repository_id)
    
    pipelines = query.offset(skip).limit(limit).all()
    return pipelines

@router.get("/{pipeline_id}", response_model=PipelineResponse)
async def get_pipeline(
    pipeline_id: UUID,
    db: Session = Depends(get_db)
):
    """Get a specific pipeline by ID"""
    pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
    if not pipeline:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pipeline not found"
        )
    return pipeline

@router.put("/{pipeline_id}", response_model=PipelineResponse)
async def update_pipeline(
    pipeline_id: UUID,
    pipeline_update: PipelineUpdate,
    db: Session = Depends(get_db)
):
    """Update a pipeline"""
    pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
    if not pipeline:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pipeline not found"
        )
    
    for field, value in pipeline_update.dict(exclude_unset=True).items():
        setattr(pipeline, field, value)
    
    db.commit()
    db.refresh(pipeline)
    
    logger.info("Pipeline updated", pipeline_id=str(pipeline_id))
    return pipeline

@router.delete("/{pipeline_id}")
async def delete_pipeline(
    pipeline_id: UUID,
    db: Session = Depends(get_db)
):
    """Delete a pipeline"""
    pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
    if not pipeline:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pipeline not found"
        )
    
    db.delete(pipeline)
    db.commit()
    
    logger.info("Pipeline deleted", pipeline_id=str(pipeline_id))
    return {"message": "Pipeline deleted successfully"}

@router.get("/{pipeline_id}/steps", response_model=List[PipelineStepResponse])
async def get_pipeline_steps(
    pipeline_id: UUID,
    db: Session = Depends(get_db)
):
    """Get all steps for a pipeline"""
    pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
    if not pipeline:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pipeline not found"
        )
    
    steps = db.query(PipelineStep).filter(
        PipelineStep.pipeline_id == pipeline_id
    ).order_by(PipelineStep.step_order).all()
    
    return steps

@router.post("/{pipeline_id}/trigger")
async def trigger_pipeline(
    pipeline_id: UUID,
    db: Session = Depends(get_db)
):
    """Trigger a pipeline execution"""
    pipeline = db.query(Pipeline).filter(Pipeline.id == pipeline_id).first()
    if not pipeline:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pipeline not found"
        )
    
    # Here you would integrate with your actual CI/CD system
    # For now, we'll just update the status
    pipeline.status = "running"
    db.commit()
    
    logger.info("Pipeline triggered", pipeline_id=str(pipeline_id))
    return {"message": "Pipeline triggered successfully", "pipeline_id": str(pipeline_id)}
