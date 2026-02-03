"""Root endpoint router - API status and health checks."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/api/status")
async def get_api_status():
    """
    Get API status for health checks.

    Useful for debugging and monitoring.
    """
    return {
        "status": "healthy",
        "application": "Terraform Configuration UI",
        "mode": "api"
    }
