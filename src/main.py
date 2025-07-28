"""
Main application entry point
"""
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import structlog
from prometheus_client import make_asgi_app, Counter, Histogram
import time

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Prometheus metrics
REQUEST_COUNT = Counter('app_requests_total', 'Total app requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Request latency')

# Create FastAPI app
app = FastAPI(
    title="CI/CD Pipeline API",
    description="A sample API with CI/CD pipeline implementation",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Middleware for metrics
@app.middleware("http")
async def add_metrics(request, call_next):
    start_time = time.time()
    
    response = await call_next(request)
    
    # Record metrics
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path
    ).inc()
    
    REQUEST_LATENCY.observe(time.time() - start_time)
    
    return response

@app.get("/")
async def root():
    """Root endpoint"""
    logger.info("Root endpoint accessed")
    return {
        "message": "Welcome to CI/CD Pipeline API",
        "status": "healthy",
        "version": "1.0.0"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": time.time()
    }

@app.get("/api/v1/pipeline/status")
async def pipeline_status():
    """Get pipeline status"""
    logger.info("Pipeline status requested")
    return {
        "pipeline": "active",
        "last_deployment": "2024-01-01T00:00:00Z",
        "environment": "production",
        "version": "1.0.0"
    }

@app.post("/api/v1/pipeline/trigger")
async def trigger_pipeline():
    """Trigger a new pipeline run"""
    logger.info("Pipeline trigger requested")
    return {
        "message": "Pipeline triggered successfully",
        "pipeline_id": "12345",
        "status": "queued"
    }

@app.get("/api/v1/ml/predict")
async def ml_predict():
    """ML prediction endpoint (placeholder)"""
    logger.info("ML prediction requested")
    return {
        "prediction": "sample_result",
        "confidence": 0.95,
        "model_version": "1.0.0"
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_config=None  # Use structlog configuration
    )
