FROM python:3.11-slim

# Install git (required for template clone operations)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy dependency files first for layer caching
COPY pyproject.toml uv.lock ./

# Install dependencies (production only)
RUN uv sync --frozen --no-dev

# Copy application code
COPY app/ app/

# Create default data directories
RUN mkdir -p /data/clones

# Environment defaults for container deployment
ENV HOST=0.0.0.0
ENV PORT=8000
ENV DB_PATH=/data/registry.db
ENV CLONE_DIR=/data/clones

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
