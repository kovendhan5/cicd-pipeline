"""
Database models using SQLAlchemy
"""
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text, 
    ForeignKey, Enum, BigInteger, Numeric
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
import enum

Base = declarative_base()

class PipelineStatus(enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"

class DeploymentEnvironment(enum.Enum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"

class UserRole(enum.Enum):
    ADMIN = "admin"
    DEVELOPER = "developer"
    VIEWER = "viewer"

class User(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.DEVELOPER)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    repositories = relationship("Repository", back_populates="owner")
    triggered_pipelines = relationship("Pipeline", back_populates="triggered_by_user")
    deployments = relationship("Deployment", back_populates="deployed_by_user")

class Repository(Base):
    __tablename__ = "repositories"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    url = Column(String(500), nullable=False)
    branch = Column(String(100), default="main")
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    owner = relationship("User", back_populates="repositories")
    pipelines = relationship("Pipeline", back_populates="repository")

class Pipeline(Base):
    __tablename__ = "pipelines"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    repository_id = Column(UUID(as_uuid=True), ForeignKey("repositories.id"))
    status = Column(Enum(PipelineStatus), default=PipelineStatus.PENDING)
    commit_hash = Column(String(40))
    commit_message = Column(Text)
    branch = Column(String(100))
    triggered_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    duration_seconds = Column(Integer)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    repository = relationship("Repository", back_populates="pipelines")
    triggered_by_user = relationship("User", back_populates="triggered_pipelines")
    steps = relationship("PipelineStep", back_populates="pipeline", cascade="all, delete-orphan")
    deployments = relationship("Deployment", back_populates="pipeline")
    artifacts = relationship("Artifact", back_populates="pipeline")
    metrics = relationship("PipelineMetric", back_populates="pipeline")

class PipelineStep(Base):
    __tablename__ = "pipeline_steps"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pipeline_id = Column(UUID(as_uuid=True), ForeignKey("pipelines.id", ondelete="CASCADE"))
    step_name = Column(String(100), nullable=False)
    step_order = Column(Integer, nullable=False)
    status = Column(Enum(PipelineStatus), default=PipelineStatus.PENDING)
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    duration_seconds = Column(Integer)
    logs = Column(Text)
    error_message = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    pipeline = relationship("Pipeline", back_populates="steps")

class Deployment(Base):
    __tablename__ = "deployments"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pipeline_id = Column(UUID(as_uuid=True), ForeignKey("pipelines.id"))
    environment = Column(Enum(DeploymentEnvironment), nullable=False)
    version = Column(String(50))
    image_tag = Column(String(100))
    status = Column(Enum(PipelineStatus), default=PipelineStatus.PENDING)
    deployed_by = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    deployed_at = Column(DateTime(timezone=True))
    rollback_id = Column(UUID(as_uuid=True), ForeignKey("deployments.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    pipeline = relationship("Pipeline", back_populates="deployments")
    deployed_by_user = relationship("User", back_populates="deployments")

class Artifact(Base):
    __tablename__ = "artifacts"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pipeline_id = Column(UUID(as_uuid=True), ForeignKey("pipelines.id"))
    name = Column(String(200), nullable=False)
    type = Column(String(50), nullable=False)  # 'docker_image', 'test_report', etc.
    url = Column(String(500))
    size_bytes = Column(BigInteger)
    checksum = Column(String(64))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    pipeline = relationship("Pipeline", back_populates="artifacts")

class PipelineMetric(Base):
    __tablename__ = "pipeline_metrics"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pipeline_id = Column(UUID(as_uuid=True), ForeignKey("pipelines.id"))
    metric_name = Column(String(100), nullable=False)
    metric_value = Column(Numeric(10, 2))
    metric_unit = Column(String(20))
    recorded_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    pipeline = relationship("Pipeline", back_populates="metrics")
