---
title: "Writing Backend APIs"
menuTitle: "Backend APIs"
weight: 3
---

Adding FastAPI endpoints and Pydantic models.

## Backend Structure

```
backend/
├── main.py              # FastAPI app and routes
├── parsers/
│   └── tfvars.py        # Terraform variable parser
└── providers/
    └── aws.py           # AWS API integration
```

---

## Adding a New API Endpoint

Edit `backend/main.py`:

```python
from fastapi import APIRouter

router = APIRouter()

@router.get("/api/my-feature/data")
async def get_my_data():
    """Return data for my feature."""
    return {"status": "ok", "data": [...]}

@router.post("/api/my-feature/action")
async def perform_action(request: MyRequestModel):
    """Perform an action."""
    # Implementation
    return {"success": True}
```

---

## Request/Response Models

Use Pydantic models for type safety:

```python
from pydantic import BaseModel
from typing import List, Optional

class MyRequestModel(BaseModel):
    name: str
    enabled: bool = False
    options: Optional[List[str]] = None

class MyResponseModel(BaseModel):
    success: bool
    message: str
    data: dict
```

---

## Error Handling

```python
from fastapi import HTTPException

@router.get("/api/resource/{resource_id}")
async def get_resource(resource_id: str):
    resource = find_resource(resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    return resource
```

