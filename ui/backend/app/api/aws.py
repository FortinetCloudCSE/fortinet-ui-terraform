"""AWS resource validation endpoints."""
import logging
from typing import List
from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
import requests

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/aws", tags=["aws"])


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


@router.get("/credentials/status")
async def check_credentials_status():
    """
    Check if AWS credentials are valid and not expired.

    Returns status of current AWS credentials.
    """
    try:
        # Try to get caller identity to validate credentials
        sts = boto3.client('sts')
        identity = sts.get_caller_identity()

        return {
            "valid": True,
            "account": identity['Account'],
            "arn": identity['Arn'],
            "user_id": identity['UserId'],
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
        ec2 = boto3.client('ec2', region_name='us-east-1')
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
        ec2 = boto3.client('ec2', region_name=region)
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
        ec2 = boto3.client('ec2', region_name=region)
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
        ec2 = boto3.client('ec2', region_name=region)
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
        ec2 = boto3.client('ec2', region_name=region)
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
