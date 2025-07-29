"""
Configuration management
"""
from pydantic import BaseSettings, Field
from typing import Optional
import os

class Settings(BaseSettings):
    # Application settings
    app_name: str = Field(default="CI/CD Pipeline API", env="APP_NAME")
    app_version: str = Field(default="1.0.0", env="APP_VERSION")
    debug: bool = Field(default=False, env="DEBUG")
    environment: str = Field(default="development", env="ENV")
    
    # Database settings
    database_url: str = Field(
        default="postgresql://user:password@localhost:5432/cicd_pipeline",
        env="DATABASE_URL"
    )
    
    # Redis settings
    redis_url: str = Field(default="redis://localhost:6379/0", env="REDIS_URL")
    
    # Security settings
    secret_key: str = Field(default="your-secret-key-change-this", env="SECRET_KEY")
    algorithm: str = Field(default="HS256", env="ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    
    # CORS settings
    cors_origins: list = Field(default=["*"], env="CORS_ORIGINS")
    
    # Docker registry settings
    docker_registry_url: Optional[str] = Field(default=None, env="DOCKER_REGISTRY_URL")
    docker_registry_username: Optional[str] = Field(default=None, env="DOCKER_REGISTRY_USERNAME")
    docker_registry_password: Optional[str] = Field(default=None, env="DOCKER_REGISTRY_PASSWORD")
    
    # CI/CD settings
    webhook_secret: Optional[str] = Field(default=None, env="WEBHOOK_SECRET")
    max_pipeline_duration: int = Field(default=3600, env="MAX_PIPELINE_DURATION")  # seconds
    max_concurrent_pipelines: int = Field(default=5, env="MAX_CONCURRENT_PIPELINES")
    
    # Monitoring settings
    prometheus_enabled: bool = Field(default=True, env="PROMETHEUS_ENABLED")
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    
    # File storage settings
    artifacts_storage_path: str = Field(default="./artifacts", env="ARTIFACTS_STORAGE_PATH")
    max_artifact_size_mb: int = Field(default=100, env="MAX_ARTIFACT_SIZE_MB")
    
    class Config:
        env_file = ".env"
        case_sensitive = False

# Global settings instance
settings = Settings()

def get_settings() -> Settings:
    """Get application settings"""
    return settings
