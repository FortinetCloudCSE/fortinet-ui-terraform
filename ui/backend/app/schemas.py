"""Pydantic schemas for API request/response models."""
from datetime import datetime
from pydantic import BaseModel


class HealthResponse(BaseModel):
    """Health check response model."""
    status: str
    app_name: str
    version: str
    timestamp: datetime
