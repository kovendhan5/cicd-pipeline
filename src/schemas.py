"""
Pydantic schemas for API request/response models
"""
from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from enum import Enum

class PipelineStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"

class DeploymentEnvironment(str, Enum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"

class UserRole(str, Enum):
    ADMIN = "admin"
    DEVELOPER = "developer"
    VIEWER = "viewer"

# Base schemas
class UserBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    role: UserRole = UserRole.DEVELOPER
    is_active: bool = True

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserResponse(UserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class RepositoryBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    url: str = Field(..., max_length=500)
    branch: str = Field(default="main", max_length=100)
    is_active: bool = True

class RepositoryCreate(RepositoryBase):
    owner_id: UUID

class RepositoryResponse(RepositoryBase):
    id: UUID
    owner_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class PipelineBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    commit_hash: Optional[str] = Field(None, max_length=40)
    commit_message: Optional[str] = None
    branch: Optional[str] = Field(None, max_length=100)

class PipelineCreate(PipelineBase):
    repository_id: UUID
    triggered_by: Optional[UUID] = None

class PipelineUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    status: Optional[PipelineStatus] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    duration_seconds: Optional[int] = None

class PipelineListResponse(BaseModel):
    id: UUID
    name: str
    status: PipelineStatus
    repository_id: UUID
    created_at: datetime
    started_at: Optional[datetime]
    completed_at: Optional[datetime]

    class Config:
        from_attributes = True

class PipelineStepBase(BaseModel):
    step_name: str = Field(..., min_length=1, max_length=100)
    step_order: int = Field(..., ge=1)

class PipelineStepCreate(PipelineStepBase):
    pipeline_id: UUID

class PipelineStepResponse(PipelineStepBase):
    id: UUID
    pipeline_id: UUID
    status: PipelineStatus
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    duration_seconds: Optional[int]
    logs: Optional[str]
    error_message: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

class PipelineResponse(PipelineBase):
    id: UUID
    repository_id: UUID
    status: PipelineStatus
    triggered_by: Optional[UUID]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    duration_seconds: Optional[int]
    created_at: datetime
    steps: List[PipelineStepResponse] = []

    class Config:
        from_attributes = True

class DeploymentBase(BaseModel):
    environment: DeploymentEnvironment
    version: Optional[str] = Field(None, max_length=50)
    image_tag: Optional[str] = Field(None, max_length=100)

class DeploymentCreate(DeploymentBase):
    pipeline_id: UUID
    deployed_by: UUID

class DeploymentResponse(DeploymentBase):
    id: UUID
    pipeline_id: UUID
    status: PipelineStatus
    deployed_by: UUID
    deployed_at: Optional[datetime]
    rollback_id: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True

class ArtifactBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    type: str = Field(..., max_length=50)
    url: Optional[str] = Field(None, max_length=500)
    size_bytes: Optional[int] = None
    checksum: Optional[str] = Field(None, max_length=64)

class ArtifactCreate(ArtifactBase):
    pipeline_id: UUID

class ArtifactResponse(ArtifactBase):
    id: UUID
    pipeline_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

class PipelineMetricBase(BaseModel):
    metric_name: str = Field(..., min_length=1, max_length=100)
    metric_value: Optional[float] = None
    metric_unit: Optional[str] = Field(None, max_length=20)

class PipelineMetricCreate(PipelineMetricBase):
    pipeline_id: UUID

class PipelineMetricResponse(PipelineMetricBase):
    id: UUID
    pipeline_id: UUID
    recorded_at: datetime

    class Config:
        from_attributes = True

# API Response models
class APIResponse(BaseModel):
    message: str
    data: Optional[dict] = None

class PaginatedResponse(BaseModel):
    items: List[dict]
    total: int
    page: int
    size: int
    pages: int
