"""Application configuration using Pydantic Settings."""
from pathlib import Path
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App Info
    app_name: str = "Terraform Configuration UI API"
    app_version: str = "0.1.0"

    # Server
    host: str = "127.0.0.1"
    port: int = 8000

    # CORS - Frontend URLs allowed to access the API
    cors_origins: Union[List[str], str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v):
        """Parse comma-separated string into list."""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v
    
    # AWS Configuration (optional)
    aws_profile: str = ""
    aws_region: str = "us-west-2"

    # GCP Configuration (optional)
    gcp_project: str = ""
    gcp_region: str = "us-central1"

    # Template Registry Database
    db_path: Path = Path("data/registry.db")
    clone_dir: Path = Path("data/clones")
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


settings = Settings()
