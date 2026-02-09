"""GCP resource validation endpoints."""
import json
import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/gcp", tags=["gcp"])

# In-memory credential storage for service account JSON
_session_credentials: dict = {}


class GCPCredentials(BaseModel):
    """GCP service account credentials."""
    type: str = "service_account"
    project_id: str
    private_key_id: str
    private_key: str
    client_email: str
    client_id: str
    auth_uri: str = "https://accounts.google.com/o/oauth2/auth"
    token_uri: str = "https://oauth2.googleapis.com/token"
    auth_provider_x509_cert_url: str = "https://www.googleapis.com/oauth2/v1/certs"
    client_x509_cert_url: str = ""


class GCPRegion(BaseModel):
    """GCP Region model."""
    name: str
    display_name: str


class GCPZone(BaseModel):
    """GCP Zone model."""
    name: str
    region: str
    status: str


class GCPNetwork(BaseModel):
    """GCP VPC Network model."""
    name: str
    self_link: str
    auto_create_subnetworks: bool


class GCPSubnetwork(BaseModel):
    """GCP Subnetwork model."""
    name: str
    ip_cidr_range: str
    region: str
    network: str


class LabelDiscoveryRequest(BaseModel):
    """Request model for label-based resource discovery."""
    label_key: str = "fortinet-role"
    label_value: str
    resource_type: str  # "vpc-network", "subnetwork", "instance"


class LabeledResource(BaseModel):
    """Model for a resource discovered by label."""
    resource_id: str
    resource_type: str
    label_value: str
    name: Optional[str] = None
    additional_info: Optional[dict] = None


def get_gcp_credentials():
    """
    Get GCP credentials from stored service account JSON or Application Default Credentials.

    Returns google.oauth2 Credentials object.
    """
    try:
        if _session_credentials:
            from google.oauth2 import service_account
            credentials = service_account.Credentials.from_service_account_info(
                _session_credentials
            )
            return credentials
        else:
            import google.auth
            credentials, project = google.auth.default()
            return credentials
    except Exception as e:
        logger.error("Failed to get GCP credentials: %s", str(e))
        raise


def get_gcp_project():
    """Get the GCP project ID from stored credentials or default."""
    if _session_credentials:
        return _session_credentials.get('project_id', '')
    try:
        import google.auth
        _, project = google.auth.default()
        return project or ''
    except Exception:
        return ''


def get_compute_client():
    """Get a GCP Compute Engine client."""
    from google.cloud import compute_v1
    credentials = get_gcp_credentials()
    return compute_v1.RegionsClient(credentials=credentials)


@router.post("/credentials/set")
async def set_credentials(credentials: GCPCredentials):
    """
    Set GCP credentials from a service account JSON.

    Stores credentials in memory for subsequent API calls.
    """
    global _session_credentials

    # Store as dict (service account JSON format)
    _session_credentials = credentials.model_dump()

    # Validate by trying to list regions
    try:
        from google.cloud import compute_v1
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_info(
            _session_credentials
        )
        client = compute_v1.RegionsClient(credentials=creds)
        # Try listing regions as a connectivity test
        request = compute_v1.ListRegionsRequest(project=credentials.project_id)
        regions = list(client.list(request=request))

        logger.info(
            "GCP credentials set successfully for project %s (%d regions available)",
            credentials.project_id, len(regions)
        )
        return {
            "valid": True,
            "project_id": credentials.project_id,
            "client_email": credentials.client_email,
            "message": "GCP credentials set successfully"
        }
    except Exception as e:
        _session_credentials.clear()
        logger.error("Invalid GCP credentials: %s", str(e))
        raise HTTPException(status_code=400, detail=f"Invalid credentials: {str(e)}")


@router.delete("/credentials/clear")
async def clear_credentials():
    """
    Clear stored GCP credentials.

    After clearing, the API will fall back to Application Default Credentials.
    """
    global _session_credentials
    _session_credentials.clear()
    logger.info("GCP credentials cleared")
    return {"message": "GCP credentials cleared"}


@router.get("/credentials/status")
async def check_credentials_status():
    """
    Check if GCP credentials are valid.

    Returns status of current GCP credentials.
    """
    try:
        credentials = get_gcp_credentials()
        project = get_gcp_project()

        # Try a lightweight API call to validate
        from google.cloud import compute_v1
        client = compute_v1.RegionsClient(credentials=credentials)
        if not project:
            return {
                "valid": False,
                "message": "No GCP project configured"
            }

        request = compute_v1.ListRegionsRequest(project=project)
        # Just try the call - if credentials are invalid, it will throw
        next(iter(client.list(request=request)), None)

        source = "service_account" if _session_credentials else "application_default"

        return {
            "valid": True,
            "project_id": project,
            "source": source,
            "message": "GCP credentials are valid"
        }
    except Exception as e:
        logger.warning("GCP credentials check failed: %s", str(e))
        return {
            "valid": False,
            "message": f"GCP credentials not available: {str(e)}"
        }


@router.get("/projects")
async def list_projects():
    """
    List accessible GCP projects.

    Returns a list of projects the credentials have access to.
    """
    try:
        from google.cloud import resourcemanager_v3

        credentials = get_gcp_credentials()
        client = resourcemanager_v3.ProjectsClient(credentials=credentials)

        projects = []
        for project in client.search_projects():
            projects.append({
                "project_id": project.project_id,
                "name": project.display_name,
                "state": project.state.name
            })

        projects.sort(key=lambda x: x["project_id"])
        logger.info("Retrieved %d GCP projects", len(projects))
        return projects

    except ImportError:
        # Fall back if resourcemanager is not available
        project = get_gcp_project()
        if project:
            return [{"project_id": project, "name": project, "state": "ACTIVE"}]
        raise HTTPException(
            status_code=500,
            detail="google-cloud-resource-manager not installed and no default project"
        )
    except Exception as e:
        logger.error("Error listing GCP projects: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/regions", response_model=List[GCPRegion])
async def list_regions(
    project: str = Query(..., description="GCP project ID")
):
    """
    List all available GCP regions.

    Args:
        project: GCP project ID

    Returns a list of GCP regions.
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        client = compute_v1.RegionsClient(credentials=credentials)

        request = compute_v1.ListRegionsRequest(project=project)
        regions = []
        for region in client.list(request=request):
            if region.status == "UP":
                regions.append(GCPRegion(
                    name=region.name,
                    display_name=f"{region.name} - {region.description or ''}"
                ))

        regions.sort(key=lambda x: x.name)
        logger.info("Retrieved %d GCP regions for project %s", len(regions), project)
        return regions

    except Exception as e:
        logger.error("Error listing GCP regions: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/zones", response_model=List[GCPZone])
async def list_zones(
    project: str = Query(..., description="GCP project ID"),
    region: str = Query(..., description="GCP region name")
):
    """
    List zones in a specific GCP region.

    Args:
        project: GCP project ID
        region: GCP region name (e.g., 'us-central1')

    Returns a list of zones in the specified region.
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        client = compute_v1.ZonesClient(credentials=credentials)

        request = compute_v1.ListZonesRequest(project=project)
        zones = []
        for zone in client.list(request=request):
            # Filter to zones in the specified region
            if zone.name.startswith(region + "-") and zone.status == "UP":
                zones.append(GCPZone(
                    name=zone.name,
                    region=region,
                    status=zone.status
                ))

        zones.sort(key=lambda x: x.name)
        logger.info("Retrieved %d zones for region %s", len(zones), region)
        return zones

    except Exception as e:
        logger.error("Error listing GCP zones: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/networks", response_model=List[GCPNetwork])
async def list_networks(
    project: str = Query(..., description="GCP project ID")
):
    """
    List VPC networks in a GCP project.

    Args:
        project: GCP project ID

    Returns a list of VPC networks.
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        client = compute_v1.NetworksClient(credentials=credentials)

        request = compute_v1.ListNetworksRequest(project=project)
        networks = []
        for network in client.list(request=request):
            networks.append(GCPNetwork(
                name=network.name,
                self_link=network.self_link,
                auto_create_subnetworks=network.auto_create_subnetworks or False
            ))

        networks.sort(key=lambda x: x.name)
        logger.info("Retrieved %d VPC networks for project %s", len(networks), project)
        return networks

    except Exception as e:
        logger.error("Error listing GCP networks: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/subnetworks", response_model=List[GCPSubnetwork])
async def list_subnetworks(
    project: str = Query(..., description="GCP project ID"),
    region: str = Query(..., description="GCP region name")
):
    """
    List subnetworks in a GCP project/region.

    Args:
        project: GCP project ID
        region: GCP region name

    Returns a list of subnetworks.
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        client = compute_v1.SubnetworksClient(credentials=credentials)

        request = compute_v1.ListSubnetworksRequest(
            project=project,
            region=region
        )
        subnetworks = []
        for subnet in client.list(request=request):
            # Extract network name from self_link
            network_name = subnet.network.split("/")[-1] if subnet.network else ""
            subnetworks.append(GCPSubnetwork(
                name=subnet.name,
                ip_cidr_range=subnet.ip_cidr_range,
                region=region,
                network=network_name
            ))

        subnetworks.sort(key=lambda x: x.name)
        logger.info("Retrieved %d subnetworks for %s/%s", len(subnetworks), project, region)
        return subnetworks

    except Exception as e:
        logger.error("Error listing GCP subnetworks: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/resources/by-label", response_model=Optional[LabeledResource])
async def discover_resource_by_label(
    request: LabelDiscoveryRequest,
    project: str = Query(..., description="GCP project ID")
):
    """
    Discover a GCP resource by its label (parallel to AWS tag discovery).

    GCP uses labels (key-value pairs) similar to AWS tags.

    Args:
        request: Label discovery request with label_key, label_value, resource_type
        project: GCP project ID

    Returns:
        LabeledResource if found, None if not found
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        # Sanitize label key for GCP (must be lowercase, hyphens to underscores)
        gcp_label_key = request.label_key.lower().replace("-", "_")
        gcp_label_value = request.label_value.lower().replace("-", "_")
        filter_str = f"labels.{gcp_label_key}={gcp_label_value}"

        if request.resource_type == "vpc-network":
            client = compute_v1.NetworksClient(credentials=credentials)
            req = compute_v1.ListNetworksRequest(
                project=project,
                filter=filter_str
            )
            for network in client.list(request=req):
                return LabeledResource(
                    resource_id=network.name,
                    resource_type="vpc-network",
                    label_value=request.label_value,
                    name=network.name,
                    additional_info={"self_link": network.self_link}
                )

        elif request.resource_type == "subnetwork":
            client = compute_v1.SubnetworksClient(credentials=credentials)
            req = compute_v1.AggregatedListSubnetworksRequest(
                project=project,
                filter=filter_str
            )
            for region_key, scoped_list in client.aggregated_list(request=req):
                for subnet in (scoped_list.subnetworks or []):
                    return LabeledResource(
                        resource_id=subnet.name,
                        resource_type="subnetwork",
                        label_value=request.label_value,
                        name=subnet.name,
                        additional_info={
                            "ip_cidr_range": subnet.ip_cidr_range,
                            "region": subnet.region.split("/")[-1] if subnet.region else "",
                            "network": subnet.network.split("/")[-1] if subnet.network else ""
                        }
                    )

        elif request.resource_type == "instance":
            client = compute_v1.InstancesClient(credentials=credentials)
            req = compute_v1.AggregatedListInstancesRequest(
                project=project,
                filter=filter_str
            )
            for zone_key, scoped_list in client.aggregated_list(request=req):
                for instance in (scoped_list.instances or []):
                    return LabeledResource(
                        resource_id=instance.name,
                        resource_type="instance",
                        label_value=request.label_value,
                        name=instance.name,
                        additional_info={
                            "zone": instance.zone.split("/")[-1] if instance.zone else "",
                            "status": instance.status
                        }
                    )

        elif request.resource_type == "firewall":
            client = compute_v1.FirewallsClient(credentials=credentials)
            req = compute_v1.ListFirewallsRequest(
                project=project,
                filter=filter_str
            )
            for fw in client.list(request=req):
                return LabeledResource(
                    resource_id=fw.name,
                    resource_type="firewall",
                    label_value=request.label_value,
                    name=fw.name,
                    additional_info={"network": fw.network.split("/")[-1] if fw.network else ""}
                )

        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported GCP resource type: {request.resource_type}"
            )

        # Resource not found
        return None

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error discovering GCP resource by label: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/resources/by-fortinet-role")
async def discover_fortinet_resources(
    project: str = Query(..., description="GCP project ID"),
    cp: str = Query(..., description="Customer prefix (e.g., 'acme')"),
    env: str = Query(..., description="Environment (e.g., 'test')")
):
    """
    Discover all GCP resources labeled with fortinet-role for a given cp/env.

    GCP labels use underscores instead of hyphens, so the label key is
    'fortinet_role' and values have underscores replacing hyphens.

    Args:
        project: GCP project ID
        cp: Customer prefix
        env: Environment name

    Returns:
        Dictionary of discovered resources by type
    """
    try:
        from google.cloud import compute_v1

        credentials = get_gcp_credentials()
        prefix = f"{cp}_{env}".lower()

        discovered = {
            "networks": [],
            "subnetworks": [],
            "instances": [],
            "firewalls": []
        }

        # Discover VPC Networks with fortinet_role label
        try:
            net_client = compute_v1.NetworksClient(credentials=credentials)
            filter_str = f"labels.fortinet_role:{prefix}_*"
            req = compute_v1.ListNetworksRequest(project=project, filter=filter_str)
            for network in net_client.list(request=req):
                labels = dict(network.labels) if network.labels else {}
                fortinet_role = labels.get("fortinet_role", "")
                discovered["networks"].append({
                    "name": network.name,
                    "fortinet_role": fortinet_role,
                    "self_link": network.self_link
                })
        except Exception as e:
            logger.warning("Error discovering GCP networks: %s", str(e))

        # Discover Subnetworks
        try:
            sub_client = compute_v1.SubnetworksClient(credentials=credentials)
            filter_str = f"labels.fortinet_role:{prefix}_*"
            req = compute_v1.AggregatedListSubnetworksRequest(
                project=project, filter=filter_str
            )
            for region_key, scoped_list in sub_client.aggregated_list(request=req):
                for subnet in (scoped_list.subnetworks or []):
                    labels = dict(subnet.labels) if subnet.labels else {}
                    fortinet_role = labels.get("fortinet_role", "")
                    discovered["subnetworks"].append({
                        "name": subnet.name,
                        "fortinet_role": fortinet_role,
                        "ip_cidr_range": subnet.ip_cidr_range,
                        "region": subnet.region.split("/")[-1] if subnet.region else "",
                        "network": subnet.network.split("/")[-1] if subnet.network else ""
                    })
        except Exception as e:
            logger.warning("Error discovering GCP subnetworks: %s", str(e))

        # Discover Instances
        try:
            inst_client = compute_v1.InstancesClient(credentials=credentials)
            filter_str = f"labels.fortinet_role:{prefix}_*"
            req = compute_v1.AggregatedListInstancesRequest(
                project=project, filter=filter_str
            )
            for zone_key, scoped_list in inst_client.aggregated_list(request=req):
                for instance in (scoped_list.instances or []):
                    labels = dict(instance.labels) if instance.labels else {}
                    fortinet_role = labels.get("fortinet_role", "")
                    discovered["instances"].append({
                        "name": instance.name,
                        "fortinet_role": fortinet_role,
                        "zone": instance.zone.split("/")[-1] if instance.zone else "",
                        "status": instance.status
                    })
        except Exception as e:
            logger.warning("Error discovering GCP instances: %s", str(e))

        # Discover Firewall Rules
        try:
            fw_client = compute_v1.FirewallsClient(credentials=credentials)
            filter_str = f"labels.fortinet_role:{prefix}_*"
            req = compute_v1.ListFirewallsRequest(project=project, filter=filter_str)
            for fw in fw_client.list(request=req):
                labels = dict(fw.labels) if fw.labels else {}
                fortinet_role = labels.get("fortinet_role", "")
                discovered["firewalls"].append({
                    "name": fw.name,
                    "fortinet_role": fortinet_role,
                    "network": fw.network.split("/")[-1] if fw.network else ""
                })
        except Exception as e:
            logger.warning("Error discovering GCP firewalls: %s", str(e))

        total = sum(len(v) for v in discovered.values())
        logger.info("Discovered %d Fortinet-Role labeled GCP resources for %s", total, prefix)

        return {
            "prefix": f"{cp}-{env}",
            "project": project,
            "total_resources": total,
            "resources": discovered
        }

    except Exception as e:
        logger.error("Error discovering GCP Fortinet resources: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))
