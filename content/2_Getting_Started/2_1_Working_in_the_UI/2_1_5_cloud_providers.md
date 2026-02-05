---
title: "Cloud Provider APIs"
menuTitle: "Cloud Providers"
weight: 5
---

Integrating AWS, Azure, and GCP APIs for dynamic dropdowns.

## AWS Provider Integration

Location: `backend/providers/aws.py`

The AWS provider uses boto3 to query AWS resources for dynamic dropdowns.

---

## Adding a New AWS API

Example: Adding VPC discovery:

```python
import boto3

def get_vpcs(region: str, credentials: dict) -> List[dict]:
    """Get VPCs in a region."""
    ec2 = boto3.client(
        'ec2',
        region_name=region,
        aws_access_key_id=credentials.get('access_key'),
        aws_secret_access_key=credentials.get('secret_key'),
        aws_session_token=credentials.get('session_token')
    )

    response = ec2.describe_vpcs()

    return [
        {
            "id": vpc['VpcId'],
            "cidr": vpc['CidrBlock'],
            "name": get_tag_value(vpc.get('Tags', []), 'Name')
        }
        for vpc in response['Vpcs']
    ]
```

---

## Exposing via API Endpoint

```python
@router.get("/api/aws/vpcs")
async def list_vpcs(region: str):
    """List VPCs in the specified region."""
    credentials = get_current_credentials()
    if not credentials:
        raise HTTPException(status_code=401, detail="AWS credentials not configured")

    vpcs = get_vpcs(region, credentials)
    return {"vpcs": vpcs}
```

---

## Adding a New Cloud Provider

To add support for Azure or GCP:

### 1. Create Provider Module

`backend/providers/azure.py`:

```python
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

def get_regions() -> List[dict]:
    """Get available Azure regions."""
    # Implementation

def get_resource_groups(subscription_id: str) -> List[dict]:
    """Get resource groups."""
    # Implementation
```

### 2. Add API Routes

In `main.py`:

```python
from providers import azure

@router.get("/api/azure/regions")
async def list_azure_regions():
    return {"regions": azure.get_regions()}

@router.get("/api/azure/resource-groups")
async def list_resource_groups(subscription_id: str):
    return {"resource_groups": azure.get_resource_groups(subscription_id)}
```

### 3. Update Frontend

Update frontend to use new endpoints for Azure templates.

