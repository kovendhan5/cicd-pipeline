"""
Test configuration and fixtures
"""
import pytest
from fastapi.testclient import TestClient
from src.main import app

@pytest.fixture
def client():
    """Test client fixture"""
    return TestClient(app)

@pytest.fixture
def sample_data():
    """Sample test data"""
    return {
        "test_message": "Hello, World!",
        "test_number": 42
    }
