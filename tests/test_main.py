"""
Test main application endpoints
"""
import pytest
from fastapi import status

def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "message" in data
    assert "status" in data
    assert "version" in data
    assert data["status"] == "healthy"

def test_health_check(client):
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "status" in data
    assert "timestamp" in data
    assert data["status"] == "healthy"

def test_pipeline_status(client):
    """Test pipeline status endpoint"""
    response = client.get("/api/v1/pipeline/status")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "pipeline" in data
    assert "environment" in data
    assert "version" in data

def test_pipeline_trigger(client):
    """Test pipeline trigger endpoint"""
    response = client.post("/api/v1/pipeline/trigger")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "message" in data
    assert "pipeline_id" in data
    assert "status" in data
    assert data["status"] == "queued"

def test_ml_predict(client):
    """Test ML prediction endpoint"""
    response = client.get("/api/v1/ml/predict")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "prediction" in data
    assert "confidence" in data
    assert "model_version" in data

def test_metrics_endpoint(client):
    """Test Prometheus metrics endpoint"""
    response = client.get("/metrics")
    assert response.status_code == status.HTTP_200_OK
    # Check if it contains Prometheus metrics format
    assert "app_requests_total" in response.text or "# HELP" in response.text
