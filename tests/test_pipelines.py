"""
Test configuration for pipeline API endpoints
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import uuid

from src.main import app
from src.database import get_db, Base
from src.models import User, Repository, Pipeline

# Create test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="module")
def client():
    """Test client fixture"""
    Base.metadata.create_all(bind=engine)
    with TestClient(app) as c:
        yield c
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db_session():
    """Database session fixture"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture
def sample_user(db_session):
    """Create a sample user"""
    user = User(
        username="testuser",
        email="test@example.com",
        password_hash="hashed_password",
        role="developer"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user

@pytest.fixture
def sample_repository(db_session, sample_user):
    """Create a sample repository"""
    repo = Repository(
        name="test-repo",
        url="https://github.com/test/repo.git",
        owner_id=sample_user.id
    )
    db_session.add(repo)
    db_session.commit()
    db_session.refresh(repo)
    return repo

@pytest.fixture
def sample_pipeline(db_session, sample_repository, sample_user):
    """Create a sample pipeline"""
    pipeline = Pipeline(
        name="test-pipeline",
        repository_id=sample_repository.id,
        triggered_by=sample_user.id,
        commit_hash="abc123",
        branch="main"
    )
    db_session.add(pipeline)
    db_session.commit()
    db_session.refresh(pipeline)
    return pipeline
