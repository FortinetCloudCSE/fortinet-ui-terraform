"""AWS resource validation endpoints."""
import logging
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import requests

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/aws", tags=["aws"])

# In-memory credential storage for remote/container deployments
# These take precedence over environment variables when set
_session_credentials: dict = {}


class AWSCredentials(BaseModel):
    """AWS credentials for remote authentication."""
    access_key: str
    secret_key: str
    session_token: Optional[str] = None


def get_boto3_client(service: str, region_name: str = 'us-east-1'):
    """
    Get a boto3 client, using session credentials if available.

    Falls back to default credential chain (env vars, instance profile, etc.)
    if no session credentials are set.
    """
    if _session_credentials:
        session = boto3.Session(
            aws_access_key_id=_session_credentials.get('access_key'),
            aws_secret_access_key=_session_credentials.get('secret_key'),
            aws_session_token=_session_credentials.get('session_token'),
            region_name=region_name
        )
        return session.client(service)
    return boto3.client(service, region_name=region_name)


class AWSRegion(BaseModel):
    """AWS Region model."""
    name: str
    display_name: str


class AvailabilityZone(BaseModel):
    """Availability Zone model."""
    zone_id: str
    zone_name: str
    region: str
    state: str


class KeyPair(BaseModel):
    """EC2 KeyPair model."""
    name: str
    key_pair_id: str
    fingerprint: str


class VPC(BaseModel):
    """VPC model."""
    vpc_id: str
    name: str | None
    cidr_block: str
    is_default: bool
    state: str


@router.post("/credentials/set")
async def set_credentials(credentials: AWSCredentials):
    """
    Set AWS credentials for remote/container deployments.

    Accepts credentials via POST and stores them in memory for use by
    subsequent API calls. Useful when the UI runs in a container and
    can't access local AWS CLI credentials.

    The aws_login.sh script can POST credentials here after SSO login.
    """
    global _session_credentials

    # Store credentials
    _session_credentials = {
        'access_key': credentials.access_key,
        'secret_key': credentials.secret_key,
        'session_token': credentials.session_token
    }

    # Validate immediately
    try:
        sts = get_boto3_client('sts')
        identity = sts.get_caller_identity()

        logger.info("AWS credentials set successfully for account %s", identity['Account'])
        return {
            "valid": True,
            "account": identity['Account'],
            "arn": identity['Arn'],
            "message": "AWS credentials set successfully"
        }
    except Exception as e:
        # Clear invalid credentials
        _session_credentials.clear()
        logger.error("Invalid AWS credentials provided: %s", str(e))
        raise HTTPException(status_code=400, detail=f"Invalid credentials: {str(e)}")


@router.delete("/credentials/clear")
async def clear_credentials():
    """
    Clear stored AWS credentials.

    After clearing, the API will fall back to default credential chain
    (environment variables, instance profile, etc.)
    """
    global _session_credentials
    _session_credentials.clear()
    logger.info("AWS credentials cleared")
    return {"message": "AWS credentials cleared"}


@router.get("/credentials/status")
async def check_credentials_status():
    """
    Check if AWS credentials are valid and not expired.

    Returns status of current AWS credentials.
    """
    try:
        # Try to get caller identity to validate credentials
        sts = get_boto3_client('sts')
        identity = sts.get_caller_identity()

        # Indicate source of credentials
        source = "session" if _session_credentials else "environment/default"

        return {
            "valid": True,
            "account": identity['Account'],
            "arn": identity['Arn'],
            "user_id": identity['UserId'],
            "source": source,
            "message": "AWS credentials are valid"
        }
    except NoCredentialsError:
        return {
            "valid": False,
            "message": "No AWS credentials found. Please run aws_login.sh"
        }
    except ClientError as e:
        if e.response['Error']['Code'] == 'ExpiredToken':
            return {
                "valid": False,
                "message": "AWS credentials have expired. Please run aws_login.sh"
            }
        return {
            "valid": False,
            "message": f"AWS credentials error: {str(e)}"
        }
    except Exception as e:
        logger.error("Error checking AWS credentials: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/regions", response_model=List[AWSRegion])
async def list_regions():
    """
    List all available AWS regions.

    Returns a list of AWS regions with display names.
    """
    try:
        ec2 = get_boto3_client('ec2', region_name='us-east-1')
        response = ec2.describe_regions(AllRegions=False)

        regions = [
            AWSRegion(
                name=region['RegionName'],
                display_name=f"{region['RegionName']} - {region.get('OptInStatus', 'opt-in-not-required')}"
            )
            for region in response['Regions']
        ]

        # Sort by region name
        regions.sort(key=lambda x: x.name)

        logger.info("Successfully retrieved %d AWS regions", len(regions))
        return regions

    except NoCredentialsError:
        raise HTTPException(
            status_code=401,
            detail="No AWS credentials found. Please run aws_login.sh"
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'ExpiredToken':
            raise HTTPException(
                status_code=401,
                detail="AWS credentials expired. Please run aws_login.sh"
            )
        logger.error("AWS ClientError: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.error("Error listing regions: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/availability-zones", response_model=List[AvailabilityZone])
async def list_availability_zones(region: str = Query(..., description="AWS region name")):
    """
    List availability zones for a specific region.

    Args:
        region: AWS region name (e.g., 'us-west-1')

    Returns a list of availability zones in the specified region.
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)
        response = ec2.describe_availability_zones(
            Filters=[{'Name': 'state', 'Values': ['available']}]
        )

        azs = [
            AvailabilityZone(
                zone_id=az['ZoneId'],
                zone_name=az['ZoneName'],
                region=az['RegionName'],
                state=az['State']
            )
            for az in response['AvailabilityZones']
        ]

        logger.info("Retrieved %d availability zones for region %s", len(azs), region)
        return azs

    except ClientError as e:
        logger.error("AWS ClientError for region %s: %s", region, str(e))
        raise HTTPException(status_code=400, detail=f"Invalid region or AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error listing AZs for region %s: %s", region, str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/keypairs", response_model=List[KeyPair])
async def list_keypairs(region: str = Query(..., description="AWS region name")):
    """
    List EC2 key pairs in a specific region.

    Args:
        region: AWS region name (e.g., 'us-west-1')

    Returns a list of EC2 key pairs in the specified region.
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)
        response = ec2.describe_key_pairs()

        keypairs = [
            KeyPair(
                name=kp['KeyName'],
                key_pair_id=kp['KeyPairId'],
                fingerprint=kp['KeyFingerprint']
            )
            for kp in response['KeyPairs']
        ]

        # Sort by name
        keypairs.sort(key=lambda x: x.name)

        logger.info("Retrieved %d key pairs for region %s", len(keypairs), region)
        return keypairs

    except ClientError as e:
        logger.error("AWS ClientError for region %s: %s", region, str(e))
        raise HTTPException(status_code=400, detail=f"Invalid region or AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error listing keypairs for region %s: %s", region, str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/vpcs", response_model=List[VPC])
async def list_vpcs(region: str = Query(..., description="AWS region name")):
    """
    List VPCs in a specific region.

    Args:
        region: AWS region name (e.g., 'us-west-1')

    Returns a list of VPCs in the specified region.
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)
        response = ec2.describe_vpcs()

        vpcs = []
        for vpc in response['Vpcs']:
            # Extract name from tags
            name = None
            if 'Tags' in vpc:
                for tag in vpc['Tags']:
                    if tag['Key'] == 'Name':
                        name = tag['Value']
                        break

            vpcs.append(VPC(
                vpc_id=vpc['VpcId'],
                name=name,
                cidr_block=vpc['CidrBlock'],
                is_default=vpc.get('IsDefault', False),
                state=vpc['State']
            ))

        # Sort by name (put unnamed VPCs at the end)
        vpcs.sort(key=lambda x: (x.name is None, x.name))

        logger.info("Retrieved %d VPCs for region %s", len(vpcs), region)
        return vpcs

    except ClientError as e:
        logger.error("AWS ClientError for region %s: %s", region, str(e))
        raise HTTPException(status_code=400, detail=f"Invalid region or AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error listing VPCs for region %s: %s", region, str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/transit-gateways")
async def list_transit_gateways(region: str = Query(..., description="AWS region name")):
    """
    List Transit Gateways in a specific region.

    Args:
        region: AWS region name (e.g., 'us-west-1')

    Returns a list of Transit Gateways in the specified region.
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)
        response = ec2.describe_transit_gateways()

        tgws = []
        for tgw in response['TransitGateways']:
            # Extract name from tags
            name = None
            if 'Tags' in tgw:
                for tag in tgw['Tags']:
                    if tag['Key'] == 'Name':
                        name = tag['Value']
                        break

            tgws.append({
                "id": tgw['TransitGatewayId'],
                "name": name,
                "state": tgw['State'],
                "amazon_side_asn": tgw.get('Options', {}).get('AmazonSideAsn')
            })

        # Sort by name (put unnamed TGWs at the end)
        tgws.sort(key=lambda x: (x['name'] is None, x['name']))

        logger.info("Retrieved %d Transit Gateways for region %s", len(tgws), region)
        return tgws

    except ClientError as e:
        logger.error("AWS ClientError for region %s: %s", region, str(e))
        raise HTTPException(status_code=400, detail=f"Invalid region or AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error listing Transit Gateways for region %s: %s", region, str(e))
        raise HTTPException(status_code=500, detail=str(e))


# ================================================================================
# TAG-BASED RESOURCE DISCOVERY ENDPOINTS
# ================================================================================
# These endpoints discover AWS resources using Fortinet-Role tags.
# Tag format: {cp}-{env}-{resource-type}-{details}
# Example: acme-test-inspection-vpc, acme-test-inspection-public-az1
#


class TaggedResource(BaseModel):
    """Model for a resource discovered by tag."""
    resource_id: str
    resource_type: str
    tag_value: str
    name: Optional[str] = None
    additional_info: Optional[dict] = None


class TagDiscoveryRequest(BaseModel):
    """Request model for tag-based resource discovery."""
    tag_key: str = "Fortinet-Role"
    tag_value: str  # e.g., "acme-test-inspection-vpc"
    resource_type: str  # e.g., "vpc", "subnet", "igw", "tgw", "tgw-attachment", "tgw-rtb"


@router.post("/resources/by-tag", response_model=Optional[TaggedResource])
async def discover_resource_by_tag(
    request: TagDiscoveryRequest,
    region: str = Query(..., description="AWS region name")
):
    """
    Discover an AWS resource by its Fortinet-Role tag.

    This endpoint is used by the UI to discover existing VPC resources
    created by existing_vpc_resources template.

    Args:
        request: Tag discovery request with tag_key, tag_value, and resource_type
        region: AWS region name

    Returns:
        TaggedResource if found, None if not found
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)

        if request.resource_type == "vpc":
            response = ec2.describe_vpcs(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            if response['Vpcs']:
                vpc = response['Vpcs'][0]
                name = None
                if 'Tags' in vpc:
                    for tag in vpc['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                return TaggedResource(
                    resource_id=vpc['VpcId'],
                    resource_type="vpc",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={"cidr_block": vpc['CidrBlock']}
                )

        elif request.resource_type == "subnet":
            response = ec2.describe_subnets(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            if response['Subnets']:
                subnet = response['Subnets'][0]
                name = None
                if 'Tags' in subnet:
                    for tag in subnet['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                return TaggedResource(
                    resource_id=subnet['SubnetId'],
                    resource_type="subnet",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={
                        "cidr_block": subnet['CidrBlock'],
                        "availability_zone": subnet['AvailabilityZone'],
                        "vpc_id": subnet['VpcId']
                    }
                )

        elif request.resource_type == "igw":
            response = ec2.describe_internet_gateways(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]}
                ]
            )
            if response['InternetGateways']:
                igw = response['InternetGateways'][0]
                name = None
                if 'Tags' in igw:
                    for tag in igw['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                vpc_id = None
                if igw.get('Attachments'):
                    vpc_id = igw['Attachments'][0].get('VpcId')
                return TaggedResource(
                    resource_id=igw['InternetGatewayId'],
                    resource_type="igw",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={"vpc_id": vpc_id}
                )

        elif request.resource_type == "tgw":
            response = ec2.describe_transit_gateways(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            if response['TransitGateways']:
                tgw = response['TransitGateways'][0]
                name = None
                if 'Tags' in tgw:
                    for tag in tgw['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                return TaggedResource(
                    resource_id=tgw['TransitGatewayId'],
                    resource_type="tgw",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={
                        "amazon_side_asn": tgw.get('Options', {}).get('AmazonSideAsn')
                    }
                )

        elif request.resource_type == "tgw-attachment":
            response = ec2.describe_transit_gateway_vpc_attachments(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            if response['TransitGatewayVpcAttachments']:
                attachment = response['TransitGatewayVpcAttachments'][0]
                name = None
                if 'Tags' in attachment:
                    for tag in attachment['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                return TaggedResource(
                    resource_id=attachment['TransitGatewayAttachmentId'],
                    resource_type="tgw-attachment",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={
                        "transit_gateway_id": attachment['TransitGatewayId'],
                        "vpc_id": attachment['VpcId']
                    }
                )

        elif request.resource_type == "tgw-rtb":
            response = ec2.describe_transit_gateway_route_tables(
                Filters=[
                    {'Name': f'tag:{request.tag_key}', 'Values': [request.tag_value]},
                    {'Name': 'state', 'Values': ['available']}
                ]
            )
            if response['TransitGatewayRouteTables']:
                rtb = response['TransitGatewayRouteTables'][0]
                name = None
                if 'Tags' in rtb:
                    for tag in rtb['Tags']:
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                return TaggedResource(
                    resource_id=rtb['TransitGatewayRouteTableId'],
                    resource_type="tgw-rtb",
                    tag_value=request.tag_value,
                    name=name,
                    additional_info={
                        "transit_gateway_id": rtb['TransitGatewayId']
                    }
                )

        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported resource type: {request.resource_type}"
            )

        # Resource not found
        return None

    except ClientError as e:
        logger.error("AWS ClientError for tag discovery: %s", str(e))
        raise HTTPException(status_code=400, detail=f"AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error discovering resource by tag: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/resources/by-fortinet-role")
async def discover_fortinet_resources(
    region: str = Query(..., description="AWS region name"),
    cp: str = Query(..., description="Customer prefix (e.g., 'acme')"),
    env: str = Query(..., description="Environment (e.g., 'test')")
):
    """
    Discover all VPC resources tagged with Fortinet-Role for a given cp/env.

    This endpoint discovers all resources that would be created by the
    existing_vpc_resources template, useful for validating that infrastructure
    exists before deploying autoscale_template or ha_pair.

    Args:
        region: AWS region name
        cp: Customer prefix
        env: Environment name

    Returns:
        Dictionary of discovered resources by type
    """
    try:
        ec2 = get_boto3_client('ec2', region_name=region)
        prefix = f"{cp}-{env}"

        discovered = {
            "vpcs": [],
            "subnets": [],
            "internet_gateways": [],
            "transit_gateways": [],
            "tgw_attachments": [],
            "tgw_route_tables": [],
            "route_tables": []
        }

        # Discover VPCs
        vpcs = ec2.describe_vpcs(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        for vpc in vpcs.get('Vpcs', []):
            fortinet_role = None
            name = None
            for tag in vpc.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["vpcs"].append({
                    "id": vpc['VpcId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "cidr_block": vpc['CidrBlock']
                })

        # Discover Subnets
        subnets = ec2.describe_subnets(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        for subnet in subnets.get('Subnets', []):
            fortinet_role = None
            name = None
            for tag in subnet.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["subnets"].append({
                    "id": subnet['SubnetId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "cidr_block": subnet['CidrBlock'],
                    "availability_zone": subnet['AvailabilityZone'],
                    "vpc_id": subnet['VpcId']
                })

        # Discover Internet Gateways
        igws = ec2.describe_internet_gateways(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]}
            ]
        )
        for igw in igws.get('InternetGateways', []):
            fortinet_role = None
            name = None
            for tag in igw.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                vpc_id = None
                if igw.get('Attachments'):
                    vpc_id = igw['Attachments'][0].get('VpcId')
                discovered["internet_gateways"].append({
                    "id": igw['InternetGatewayId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "vpc_id": vpc_id
                })

        # Discover Transit Gateways
        tgws = ec2.describe_transit_gateways(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        for tgw in tgws.get('TransitGateways', []):
            fortinet_role = None
            name = None
            for tag in tgw.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["transit_gateways"].append({
                    "id": tgw['TransitGatewayId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "amazon_side_asn": tgw.get('Options', {}).get('AmazonSideAsn')
                })

        # Discover TGW Attachments
        attachments = ec2.describe_transit_gateway_vpc_attachments(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        for attachment in attachments.get('TransitGatewayVpcAttachments', []):
            fortinet_role = None
            name = None
            for tag in attachment.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["tgw_attachments"].append({
                    "id": attachment['TransitGatewayAttachmentId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "transit_gateway_id": attachment['TransitGatewayId'],
                    "vpc_id": attachment['VpcId']
                })

        # Discover TGW Route Tables
        rtbs = ec2.describe_transit_gateway_route_tables(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        for rtb in rtbs.get('TransitGatewayRouteTables', []):
            fortinet_role = None
            name = None
            for tag in rtb.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["tgw_route_tables"].append({
                    "id": rtb['TransitGatewayRouteTableId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "transit_gateway_id": rtb['TransitGatewayId']
                })

        # Discover Route Tables
        route_tables = ec2.describe_route_tables(
            Filters=[
                {'Name': 'tag:Fortinet-Role', 'Values': [f"{prefix}-*"]}
            ]
        )
        for rt in route_tables.get('RouteTables', []):
            fortinet_role = None
            name = None
            for tag in rt.get('Tags', []):
                if tag['Key'] == 'Fortinet-Role':
                    fortinet_role = tag['Value']
                elif tag['Key'] == 'Name':
                    name = tag['Value']
            if fortinet_role:
                discovered["route_tables"].append({
                    "id": rt['RouteTableId'],
                    "fortinet_role": fortinet_role,
                    "name": name,
                    "vpc_id": rt['VpcId']
                })

        # Summary
        total = sum(len(v) for v in discovered.values())
        logger.info("Discovered %d Fortinet-Role tagged resources for %s", total, prefix)

        return {
            "prefix": prefix,
            "region": region,
            "total_resources": total,
            "resources": discovered
        }

    except ClientError as e:
        logger.error("AWS ClientError for Fortinet resource discovery: %s", str(e))
        raise HTTPException(status_code=400, detail=f"AWS error: {str(e)}")
    except Exception as e:
        logger.error("Error discovering Fortinet resources: %s", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/my-ip")
async def get_my_ip(request: Request):
    """
    Detect the user's public IP address from the request.

    Returns the client's public IP address in CIDR format (/32).
    """
    try:
        # Try to get IP from X-Forwarded-For header (if behind proxy)
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            # Take the first IP in the chain (client IP)
            client_ip = forwarded_for.split(",")[0].strip()
        else:
            # Fall back to direct client IP
            client_ip = request.client.host if request.client else None

        # If we got localhost/private IP, try to get public IP via external service
        if not client_ip or client_ip.startswith(("127.", "192.168.", "10.", "172.")):
            try:
                response = requests.get("https://api.ipify.org?format=text", timeout=5.0)
                if response.status_code == 200:
                    client_ip = response.text.strip()
            except Exception as e:
                logger.warning(f"Could not get public IP from ipify: {e}")

        if client_ip:
            # Return as CIDR /32
            cidr = f"{client_ip}/32"
            logger.info(f"Detected client IP: {cidr}")
            return {"ip": client_ip, "cidr": cidr}
        else:
            raise HTTPException(status_code=500, detail="Could not determine client IP address")

    except Exception as e:
        logger.error(f"Error detecting client IP: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
