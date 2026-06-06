"""FastAPI application factory and configuration."""
import logging
from datetime import datetime, timezone
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.db import init_db, close_db
from app.schemas import HealthResponse
from app.api import root, aws, gcp, templates, tfvars_ui, template_terraform, template_files

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    # Startup
    logger.info("Starting %s v%s", settings.app_name, settings.app_version)
    logger.info("CORS origins: %s", settings.cors_origins)
    await init_db(settings.db_path)
    yield
    # Shutdown
    await close_db()
    logger.info("Shutting down %s", settings.app_name)


# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    description="REST API for dynamic Terraform configuration UI with AWS and GCP validation",
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/swagger",
    redoc_url="/redoc",
    redirect_slashes=False,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(root.router, tags=["root"])
app.include_router(aws.router)
app.include_router(gcp.router)
app.include_router(templates.router)
app.include_router(tfvars_ui.router)
app.include_router(template_terraform.router)
app.include_router(template_files.router)


@app.get("/health", response_model=HealthResponse, tags=["health"])
async def health_check() -> HealthResponse:
    """
    Health check endpoint.
    
    Returns API status and basic information.
    """
    return HealthResponse(
        status="healthy",
        app_name=settings.app_name,
        version=settings.app_version,
        timestamp=datetime.now(timezone.utc)
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
        log_level="info"
    )
