"""Terraform configuration endpoints."""
import logging
import subprocess
import asyncio
from pathlib import Path
from typing import Dict, Any
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.parsers.tfvars_parser import parse_tfvars_file

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/terraform", tags=["terraform"])


class ConfigSchema(BaseModel):
    """Terraform configuration schema."""
    groups: list
    metadata: dict


class ConfigSaveRequest(BaseModel):
    """Request to save configuration."""
    template: str
    config: Dict[str, Any]


class SaveLogRequest(BaseModel):
    """Request to save build log."""
    template: str
    content: str
    mode: str  # 'append' or 'truncate'


class ConfigGenerateResponse(BaseModel):
    """Response with generated tfvars content."""
    content: str
    filename: str


# Get path to terraform templates directory
def get_terraform_dir() -> Path:
    """Get path to terraform directory."""
    # Navigate from backend/app/api -> backend -> ui -> parent -> terraform
    return Path(__file__).parent.parent.parent.parent.parent / "terraform"


@router.get("/schema", response_model=ConfigSchema)
async def get_config_schema(
    template: str = Query(..., description="Template name (e.g., 'existing_vpc_resources')")
):
    """
    Get configuration schema for a Terraform template.

    Parses the terraform.tfvars.example file and returns a JSON schema
    that describes all configuration fields, their types, validation rules,
    and UI metadata.

    Args:
        template: Template name (existing_vpc_resources or autoscale_template)

    Returns:
        Schema with groups and fields
    """
    try:
        # Validate template name
        valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
        if template not in valid_templates:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid template. Must be one of: {', '.join(valid_templates)}"
            )

        # Get path to tfvars.example file
        terraform_dir = get_terraform_dir()
        tfvars_path = terraform_dir / template / "terraform.tfvars.example"

        if not tfvars_path.exists():
            raise HTTPException(
                status_code=404,
                detail=f"Template not found: {tfvars_path}"
            )

        # Parse the file
        logger.info(f"Parsing tfvars file: {tfvars_path}")
        schema = parse_tfvars_file(tfvars_path)

        logger.info(
            f"Parsed schema: {schema['metadata']['total_groups']} groups, "
            f"{schema['metadata']['total_fields']} fields"
        )

        return schema

    except FileNotFoundError as e:
        logger.error(f"File not found: {str(e)}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error parsing schema: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/config/save")
async def save_configuration(request: ConfigSaveRequest):
    """
    Save configuration to JSON file.

    Args:
        request: Config save request with template name and configuration

    Returns:
        Success message
    """
    try:
        # Validate template name
        valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
        if request.template not in valid_templates:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid template. Must be one of: {', '.join(valid_templates)}"
            )

        # Save to JSON file in terraform directory
        terraform_dir = get_terraform_dir()
        config_file = terraform_dir / request.template / "ui_config.json"

        # Create directory if it doesn't exist
        config_file.parent.mkdir(parents=True, exist_ok=True)

        # Write configuration
        import json
        with open(config_file, 'w') as f:
            json.dump(request.config, f, indent=2)

        logger.info(f"Saved configuration to {config_file}")

        return {
            "success": True,
            "message": "Configuration saved successfully",
            "file": str(config_file)
        }

    except Exception as e:
        logger.error(f"Error saving configuration: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/config/load")
async def load_configuration(
    template: str = Query(..., description="Template name")
):
    """
    Load saved configuration from JSON file.

    Args:
        template: Template name

    Returns:
        Saved configuration
    """
    try:
        # Validate template name
        valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
        if template not in valid_templates:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid template. Must be one of: {', '.join(valid_templates)}"
            )

        # Load from JSON file
        terraform_dir = get_terraform_dir()
        config_file = terraform_dir / template / "ui_config.json"

        # Read configuration if it exists
        import json
        config = {}
        if config_file.exists():
            with open(config_file, 'r') as f:
                config = json.load(f)

        # If loading existing_vpc_resources, auto-populate management_cidr_sg with current public IP
        if template == "existing_vpc_resources":
            if "management_cidr_sg" not in config or not config["management_cidr_sg"] or config["management_cidr_sg"] == "x.x.x.x/32":
                try:
                    import requests
                    response = requests.get("https://api.ipify.org?format=text", timeout=3.0)
                    if response.status_code == 200:
                        user_ip = response.text.strip()
                        config["management_cidr_sg"] = f"{user_ip}/32"
                        logger.info(f"Auto-populated management_cidr_sg with current public IP: {config['management_cidr_sg']}")
                except Exception as e:
                    logger.warning(f"Could not auto-detect user IP for management_cidr_sg: {e}")

        # If loading autoscale_template or ha_pair, inherit values from existing_vpc_resources
        inherited_fields = []
        if template == "autoscale_template" or template == "ha_pair":
            existing_vpc_config_file = terraform_dir / "existing_vpc_resources" / "ui_config.json"
            if existing_vpc_config_file.exists():
                with open(existing_vpc_config_file, 'r') as f:
                    existing_config = json.load(f)

                # Fields to inherit from existing_vpc_resources (these become read-only)
                inherit_fields = [
                    "aws_region",
                    "availability_zone_1",
                    "availability_zone_2",
                    "cp",
                    "env",
                    "enable_build_management_vpc"  # Maps to enable_dedicated_management_vpc
                ]

                # Inherit values from existing_vpc_resources (overwrite autoscale config)
                for field in inherit_fields:
                    if field in existing_config:
                        # Special mapping for enable_build_management_vpc -> enable_dedicated_management_vpc
                        if field == "enable_build_management_vpc":
                            config["enable_dedicated_management_vpc"] = existing_config[field]
                            inherited_fields.append("enable_dedicated_management_vpc")
                        else:
                            config[field] = existing_config[field]
                            inherited_fields.append(field)

                logger.info(f"Inherited {len(inherited_fields)} fields from existing_vpc_resources")

                # Auto-populate fortigate_management_cidr based on management configuration
                default_cidrs = []

                # Start with existing user-provided CIDRs if any
                existing_cidrs = config.get("fortigate_management_cidr", "")
                if existing_cidrs:
                    # Split existing comma-separated CIDRs
                    default_cidrs = [cidr.strip() for cidr in existing_cidrs.split(",") if cidr.strip()]
                else:
                    # If empty, try to detect user's public IP as default
                    try:
                        import requests
                        response = requests.get("https://api.ipify.org?format=text", timeout=3.0)
                        if response.status_code == 200:
                            user_ip = response.text.strip()
                            default_cidrs.append(f"{user_ip}/32")
                            logger.info(f"Auto-detected user IP: {user_ip}/32")
                    except Exception as e:
                        logger.warning(f"Could not auto-detect user IP: {e}")

                # If dedicated management VPC is enabled, add management VPC CIDR
                if existing_config.get("enable_build_management_vpc"):
                    mgmt_cidr = existing_config.get("vpc_cidr_management")
                    if mgmt_cidr and mgmt_cidr not in default_cidrs:
                        default_cidrs.append(mgmt_cidr)

                # If dedicated management ENI + management subnets in inspection VPC
                elif config.get("enable_dedicated_management_eni") and existing_config.get("enable_build_management_subnets"):
                    # Get management subnet CIDRs from existing_vpc_resources
                    mgmt_subnet_az1 = existing_config.get("cidr_for_mgmt_subnet_in_inspection_vpc_az1")
                    mgmt_subnet_az2 = existing_config.get("cidr_for_mgmt_subnet_in_inspection_vpc_az2")

                    if mgmt_subnet_az1 and mgmt_subnet_az1 not in default_cidrs:
                        default_cidrs.append(mgmt_subnet_az1)
                    if mgmt_subnet_az2 and mgmt_subnet_az2 not in default_cidrs:
                        default_cidrs.append(mgmt_subnet_az2)

                if default_cidrs:
                    config["fortigate_management_cidr"] = ", ".join(default_cidrs)
                    logger.info(f"Merged fortigate_management_cidr with: {config['fortigate_management_cidr']}")

                # Auto-populate asg_module_prefix if not already set
                if "asg_module_prefix" not in config or not config["asg_module_prefix"]:
                    cp = config.get("cp", "")
                    env = config.get("env", "")
                    if cp and env:
                        config["asg_module_prefix"] = f"{cp}-{env}-asg"
                        logger.info(f"Auto-populated asg_module_prefix: {config['asg_module_prefix']}")

                # Auto-populate GWLB endpoint names if not already set
                cp = config.get("cp", "")
                env = config.get("env", "")
                if cp and env:
                    if "endpoint_name_az1" not in config or not config["endpoint_name_az1"]:
                        config["endpoint_name_az1"] = f"{cp}-{env}-asg-gwlbe_az1"
                        logger.info(f"Auto-populated endpoint_name_az1: {config['endpoint_name_az1']}")
                    if "endpoint_name_az2" not in config or not config["endpoint_name_az2"]:
                        config["endpoint_name_az2"] = f"{cp}-{env}-asg-gwlbe_az2"
                        logger.info(f"Auto-populated endpoint_name_az2: {config['endpoint_name_az2']}")

        # Return message based on whether config file existed
        if not config_file.exists():
            message = "No saved configuration found"
            if (template == "autoscale_template" or template == "ha_pair") and config:
                message += " (inherited defaults from existing_vpc_resources)"
            return {
                "success": False,
                "message": message,
                "config": config,
                "inherited_fields": inherited_fields if (template == "autoscale_template" or template == "ha_pair") else []
            }

        logger.info(f"Loaded configuration from {config_file}")

        return {
            "success": True,
            "message": "Configuration loaded successfully",
            "config": config,
            "inherited_fields": inherited_fields if (template == "autoscale_template" or template == "ha_pair") else []
        }

    except Exception as e:
        logger.error(f"Error loading configuration: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/config/delete")
async def delete_configuration(
    template: str = Query(..., description="Template name")
):
    """
    Delete saved configuration file and reset to defaults.

    Args:
        template: Template name

    Returns:
        Success message
    """
    try:
        # Validate template name
        valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
        if template not in valid_templates:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid template. Must be one of: {', '.join(valid_templates)}"
            )

        # Delete config file
        terraform_dir = get_terraform_dir()
        config_file = terraform_dir / template / "ui_config.json"

        if not config_file.exists():
            return {
                "success": False,
                "message": "No saved configuration found to delete"
            }

        # Delete the file
        config_file.unlink()
        logger.info(f"Deleted configuration file: {config_file}")

        return {
            "success": True,
            "message": "Configuration deleted successfully"
        }

    except Exception as e:
        logger.error(f"Error deleting configuration: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


class ConfigValidateResponse(BaseModel):
    """Response from configuration validation."""
    valid: bool
    errors: list
    warnings: list


def validate_autoscale_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """
    Validate autoscale_template configuration.

    Returns dict with 'errors' and 'warnings' lists.
    """
    errors = []
    warnings = []

    license_model = config.get("autoscale_license_model", "hybrid")

    # Validate BYOL capacity for hybrid mode
    if license_model == "hybrid":
        byol_min = config.get("asg_byol_asg_min_size", 1)
        byol_max = config.get("asg_byol_asg_max_size", 2)
        byol_desired = config.get("asg_byol_asg_desired_size", 1)

        # In hybrid mode, BYOL provides fixed baseline - min should equal desired
        if byol_min != byol_desired:
            errors.append(
                f"Hybrid mode requires BYOL min_size ({byol_min}) == desired_size ({byol_desired}) "
                "for fixed baseline capacity. The BYOL ASG provides steady-state capacity."
            )

        # Warning: max > min allows manual scale-out (need extra licenses)
        if byol_max > byol_min:
            warnings.append(
                f"BYOL max_size ({byol_max}) > min_size ({byol_min}) allows manual scale-out. "
                "Ensure you have sufficient licenses available before manually increasing capacity."
            )

    # Validate scale thresholds
    scale_out = config.get("asg_scale_out_threshold", 80)
    scale_in = config.get("asg_scale_in_threshold", 20)

    if scale_in >= scale_out:
        errors.append(
            f"Scale-in threshold ({scale_in}%) must be less than scale-out threshold ({scale_out}%). "
            "Otherwise, scaling oscillation will occur."
        )

    # Warn if thresholds are too close (< 30% gap)
    if (scale_out - scale_in) < 30 and scale_in < scale_out:
        warnings.append(
            f"Scale thresholds are close ({scale_out}% out, {scale_in}% in). "
            "Consider at least 30% gap to prevent scaling oscillation."
        )

    return {"errors": errors, "warnings": warnings}


@router.post("/config/validate", response_model=ConfigValidateResponse)
async def validate_configuration(request: ConfigSaveRequest):
    """
    Validate configuration for a Terraform template.

    Args:
        request: Config with template name and values

    Returns:
        Validation result with errors and warnings
    """
    try:
        errors = []
        warnings = []

        if request.template == "autoscale_template":
            result = validate_autoscale_config(request.config)
            errors.extend(result["errors"])
            warnings.extend(result["warnings"])

        return ConfigValidateResponse(
            valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    except Exception as e:
        logger.error(f"Error validating configuration: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/config/generate", response_model=ConfigGenerateResponse)
async def generate_tfvars(request: ConfigSaveRequest):
    """
    Generate terraform.tfvars file content from configuration.

    Args:
        request: Config with template name and values

    Returns:
        Generated tfvars content
    """
    try:
        # Load schema to get group structure
        terraform_dir = get_terraform_dir()
        tfvars_path = terraform_dir / request.template / "terraform.tfvars.example"
        schema = parse_tfvars_file(tfvars_path)

        # Generate tfvars content
        lines = []
        lines.append("# Generated by Terraform UI")
        lines.append("# Template: " + request.template)
        lines.append("")

        # Iterate through groups in order
        for group in schema['groups']:
            # Add group header
            lines.append("#" + "=" * 100)
            lines.append(f"# {group['name'].upper()}")
            lines.append("#" + "=" * 100)

            # Iterate through fields in this group
            for field in group['fields']:
                field_name = field['name']

                # Skip output fields (calculated/computed values that shouldn't be in tfvars)
                if field.get('type') == 'output':
                    continue

                # Skip UI-only fields that are converted to other variables
                if field_name == 'create_nat_gateway_subnets':
                    # This is converted to access_internet_mode in hidden fields
                    continue

                # Skip all FortiManager/FortiAnalyzer fields if resource is disabled
                if request.template == "existing_vpc_resources":
                    fortimanager_fields = [
                        "enable_fortimanager_public_ip", "fortimanager_instance_type",
                        "fortimanager_os_version", "fortimanager_host_ip",
                        "fortimanager_license_file", "fortimanager_vm_name",
                        "fortimanager_admin_password"
                    ]
                    if field_name in fortimanager_fields and not request.config.get("enable_fortimanager", False):
                        continue

                    fortianalyzer_fields = [
                        "enable_fortianalyzer_public_ip", "fortianalyzer_instance_type",
                        "fortianalyzer_os_version", "fortianalyzer_host_ip",
                        "fortianalyzer_license_file", "fortianalyzer_vm_name",
                        "fortianalyzer_admin_password"
                    ]
                    if field_name in fortianalyzer_fields and not request.config.get("enable_fortianalyzer", False):
                        continue

                    # Skip FortiTester common fields if neither FortiTester is enabled
                    fortitester_common_fields = [
                        "fortitester_instance_type", "fortitester_os_version",
                        "fortitester_host_ip", "fortitester_admin_password"
                    ]
                    any_fortitester = request.config.get("enable_fortitester_1", False) or request.config.get("enable_fortitester_2", False)
                    if field_name in fortitester_common_fields and not any_fortitester:
                        continue

                # Skip fields based on license model (autoscale_template)
                if request.template == "autoscale_template":
                    license_model = request.config.get("autoscale_license_model", "hybrid")

                    # BYOL fields - skip if using on_demand only
                    byol_fields = [
                        "asg_byol_asg_min_size", "asg_byol_asg_max_size", "asg_byol_asg_desired_size",
                        "asg_license_directory", "fortiflex_username", "fortiflex_password",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if license_model == "on_demand" and field_name in byol_fields:
                        continue

                    # On-demand fields - skip if using byol only
                    ondemand_fields = [
                        "asg_ondemand_asg_min_size", "asg_ondemand_asg_max_size", "asg_ondemand_asg_desired_size"
                    ]
                    if license_model == "byol" and field_name in ondemand_fields:
                        continue

                    # Skip FortiFlex fields if not using FortiFlex (empty username)
                    fortiflex_fields = [
                        "fortiflex_username", "fortiflex_password",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if field_name in fortiflex_fields and not request.config.get("fortiflex_username", ""):
                        continue

                # Skip if field not in config (e.g., computed output fields)
                if field_name not in request.config:
                    continue

                value = request.config[field_name]

                # Auto-generate attach_to_tgw_name if empty or using default value
                if field_name == "attach_to_tgw_name" and request.template == "existing_vpc_resources":
                    cp = request.config.get("cp", "")
                    env = request.config.get("env", "")
                    # If value is empty or still has default "acme-test-tgw", regenerate it
                    if cp and env and (not value or value == "acme-test-tgw" or value.startswith("acme-")):
                        value = f"{cp}-{env}-tgw"
                        logger.info(f"Auto-generated attach_to_tgw_name: {value}")

                # Format value based on type
                if isinstance(value, bool):
                    formatted_value = "true" if value else "false"
                elif isinstance(value, (int, float)):
                    formatted_value = str(value)
                elif isinstance(value, str):
                    # Fields that need to be converted from comma-separated strings to lists
                    list_fields = [
                        "management_cidr_sg", "fortigate_management_cidr",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if field_name in list_fields:
                        if value and "," in value:
                            # Split by comma and strip whitespace
                            items = [item.strip() for item in value.split(",") if item.strip()]
                            # Format as Terraform list
                            formatted_value = "[" + ", ".join(f'"{item}"' for item in items) + "]"
                        elif value:
                            # Single value, still convert to list
                            formatted_value = f'["{value}"]'
                        else:
                            # Empty string, output empty list
                            formatted_value = "[]"
                    else:
                        # Quote strings
                        formatted_value = f'"{value}"'
                elif isinstance(value, list):
                    formatted_value = str(value).replace("'", '"')
                else:
                    formatted_value = str(value)

                lines.append(f"{field_name} = {formatted_value}")

            lines.append("")  # Blank line between groups

        content = "\n".join(lines)

        # Add hidden/derived fields that aren't in the UI but required by Terraform
        hidden_fields = []
        if "vpc_cidr_inspection" in request.config:
            hidden_fields.append(f'vpc_cidr_ns_inspection = "{request.config["vpc_cidr_inspection"]}"')
        if "vpc_cidr_west" in request.config or "vpc_cidr_east" in request.config:
            hidden_fields.append('vpc_cidr_spoke = "192.168.0.0/16"')
        if "linux_host_ip" in request.config:
            hidden_fields.append('acl = "private"')

        # Template-specific hidden fields
        if request.template == "existing_vpc_resources":
            # Convert create_nat_gateway_subnets checkbox to access_internet_mode
            create_nat_gw = request.config.get("create_nat_gateway_subnets", False)
            access_mode = "nat_gw" if create_nat_gw else "eip"
            hidden_fields.append(f'access_internet_mode = "{access_mode}"')

        if request.template == "autoscale_template":
            # acl is required by autoscale_template but not shown in UI
            hidden_fields.append('acl = "private"')

        if request.template == "ha_pair":
            # acl is required by ha_pair but not shown in UI
            hidden_fields.append('acl = "private"')

        if hidden_fields:
            content += "\n\n# Hidden fields (required by Terraform, auto-generated)\n"
            content += "\n".join(hidden_fields)

        filename = f"{request.template}_terraform.tfvars"

        logger.info(f"Generated tfvars for {request.template}")

        return ConfigGenerateResponse(
            content=content,
            filename=filename
        )

    except Exception as e:
        logger.error(f"Error generating tfvars: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/config/save-to-template")
async def save_tfvars_to_template(request: ConfigSaveRequest):
    """
    Save generated terraform.tfvars directly to template directory.

    Args:
        request: Config with template name and values

    Returns:
        Success message with file path
    """
    try:
        # Generate tfvars content (reuse the generation logic)
        terraform_dir = get_terraform_dir()
        tfvars_path = terraform_dir / request.template / "terraform.tfvars.example"
        schema = parse_tfvars_file(tfvars_path)

        # Generate tfvars content
        lines = []
        lines.append("# Generated by Terraform UI")
        lines.append("# Template: " + request.template)
        lines.append("")

        # Iterate through groups in order
        for group in schema['groups']:
            # Add group header
            lines.append("#" + "=" * 100)
            lines.append(f"# {group['name'].upper()}")
            lines.append("#" + "=" * 100)

            # Iterate through fields in this group
            for field in group['fields']:
                field_name = field['name']

                # Skip output fields (calculated/computed values that shouldn't be in tfvars)
                if field.get('type') == 'output':
                    continue

                # Skip UI-only fields that are converted to other variables
                if field_name == 'create_nat_gateway_subnets':
                    # This is converted to access_internet_mode in hidden fields
                    continue

                # Skip all FortiManager/FortiAnalyzer fields if resource is disabled
                if request.template == "existing_vpc_resources":
                    fortimanager_fields = [
                        "enable_fortimanager_public_ip", "fortimanager_instance_type",
                        "fortimanager_os_version", "fortimanager_host_ip",
                        "fortimanager_license_file", "fortimanager_vm_name",
                        "fortimanager_admin_password"
                    ]
                    if field_name in fortimanager_fields and not request.config.get("enable_fortimanager", False):
                        continue

                    fortianalyzer_fields = [
                        "enable_fortianalyzer_public_ip", "fortianalyzer_instance_type",
                        "fortianalyzer_os_version", "fortianalyzer_host_ip",
                        "fortianalyzer_license_file", "fortianalyzer_vm_name",
                        "fortianalyzer_admin_password"
                    ]
                    if field_name in fortianalyzer_fields and not request.config.get("enable_fortianalyzer", False):
                        continue

                    # Skip FortiTester common fields if neither FortiTester is enabled
                    fortitester_common_fields = [
                        "fortitester_instance_type", "fortitester_os_version",
                        "fortitester_host_ip", "fortitester_admin_password"
                    ]
                    any_fortitester = request.config.get("enable_fortitester_1", False) or request.config.get("enable_fortitester_2", False)
                    if field_name in fortitester_common_fields and not any_fortitester:
                        continue

                # Skip fields based on license model (autoscale_template)
                if request.template == "autoscale_template":
                    license_model = request.config.get("autoscale_license_model", "hybrid")

                    # BYOL fields - skip if using on_demand only
                    byol_fields = [
                        "asg_byol_asg_min_size", "asg_byol_asg_max_size", "asg_byol_asg_desired_size",
                        "asg_license_directory", "fortiflex_username", "fortiflex_password",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if license_model == "on_demand" and field_name in byol_fields:
                        continue

                    # On-demand fields - skip if using byol only
                    ondemand_fields = [
                        "asg_ondemand_asg_min_size", "asg_ondemand_asg_max_size", "asg_ondemand_asg_desired_size"
                    ]
                    if license_model == "byol" and field_name in ondemand_fields:
                        continue

                    # Skip FortiFlex fields if not using FortiFlex (empty username)
                    fortiflex_fields = [
                        "fortiflex_username", "fortiflex_password",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if field_name in fortiflex_fields and not request.config.get("fortiflex_username", ""):
                        continue

                # Skip if field not in config (e.g., computed output fields)
                if field_name not in request.config:
                    continue

                value = request.config[field_name]

                # Auto-generate attach_to_tgw_name if empty or using default value
                if field_name == "attach_to_tgw_name" and request.template == "existing_vpc_resources":
                    cp = request.config.get("cp", "")
                    env = request.config.get("env", "")
                    # If value is empty or still has default "acme-test-tgw", regenerate it
                    if cp and env and (not value or value == "acme-test-tgw" or value.startswith("acme-")):
                        value = f"{cp}-{env}-tgw"
                        logger.info(f"Auto-generated attach_to_tgw_name: {value}")

                # Format value based on type
                if isinstance(value, bool):
                    formatted_value = "true" if value else "false"
                elif isinstance(value, (int, float)):
                    formatted_value = str(value)
                elif isinstance(value, str):
                    # Fields that need to be converted from comma-separated strings to lists
                    list_fields = [
                        "management_cidr_sg", "fortigate_management_cidr",
                        "fortiflex_sn_list", "fortiflex_configid_list"
                    ]
                    if field_name in list_fields:
                        if value and "," in value:
                            # Split by comma and strip whitespace
                            items = [item.strip() for item in value.split(",") if item.strip()]
                            # Format as Terraform list
                            formatted_value = "[" + ", ".join(f'"{item}"' for item in items) + "]"
                        elif value:
                            # Single value, still convert to list
                            formatted_value = f'["{value}"]'
                        else:
                            # Empty string, output empty list
                            formatted_value = "[]"
                    else:
                        # Quote strings
                        formatted_value = f'"{value}"'
                elif isinstance(value, list):
                    formatted_value = str(value).replace("'", '"')
                else:
                    formatted_value = str(value)

                lines.append(f"{field_name} = {formatted_value}")

            lines.append("")  # Blank line between groups

        content = "\n".join(lines)

        # Add hidden/derived fields that aren't in the UI but required by Terraform
        hidden_fields = []
        if "vpc_cidr_inspection" in request.config:
            hidden_fields.append(f'vpc_cidr_ns_inspection = "{request.config["vpc_cidr_inspection"]}"')
        if "vpc_cidr_west" in request.config or "vpc_cidr_east" in request.config:
            hidden_fields.append('vpc_cidr_spoke = "192.168.0.0/16"')
        if "linux_host_ip" in request.config:
            hidden_fields.append('acl = "private"')

        # Template-specific hidden fields
        if request.template == "existing_vpc_resources":
            # Convert create_nat_gateway_subnets checkbox to access_internet_mode
            create_nat_gw = request.config.get("create_nat_gateway_subnets", False)
            access_mode = "nat_gw" if create_nat_gw else "eip"
            hidden_fields.append(f'access_internet_mode = "{access_mode}"')

        if request.template == "autoscale_template":
            # acl is required by autoscale_template but not shown in UI
            hidden_fields.append('acl = "private"')

        if request.template == "ha_pair":
            # acl is required by ha_pair but not shown in UI
            hidden_fields.append('acl = "private"')

        if hidden_fields:
            content += "\n\n# Hidden fields (required by Terraform, auto-generated)\n"
            content += "\n".join(hidden_fields)

        # Write to terraform.tfvars in template directory
        output_file = terraform_dir / request.template / "terraform.tfvars"
        with open(output_file, 'w') as f:
            f.write(content)

        logger.info(f"Saved terraform.tfvars to {output_file}")

        return {
            "success": True,
            "message": "terraform.tfvars saved successfully",
            "file": str(output_file)
        }

    except Exception as e:
        logger.error(f"Error saving tfvars to template: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/license-files")
async def list_license_files(template: str = Query(...)):
    """
    List all .lic files in the template directory.

    Args:
        template: Template name (e.g., "existing_vpc_resources")

    Returns:
        List of license file paths relative to template directory
    """
    try:
        terraform_dir = get_terraform_dir()
        template_dir = terraform_dir / template

        if not template_dir.exists():
            raise HTTPException(status_code=404, detail=f"Template '{template}' not found")

        # Find all .lic files recursively
        license_files = []
        for lic_file in template_dir.rglob("*.lic"):
            # Get path relative to template directory
            rel_path = lic_file.relative_to(template_dir)
            license_files.append({
                "value": f"./{rel_path}",
                "label": str(rel_path)
            })

        # Sort by label
        license_files.sort(key=lambda x: x["label"])

        # Add empty option at the beginning for PAYG
        license_files.insert(0, {"value": "", "label": "(None - Use PAYG)"})

        logger.info(f"Found {len(license_files) - 1} license files in {template}")
        return license_files

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing license files: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


async def run_command_stream(command: list, cwd: Path):
    """
    Run a command and stream output line by line.

    Args:
        command: Command and arguments as list
        cwd: Working directory

    Yields:
        Tuple of (line, exit_code) where exit_code is None until process completes
    """
    try:
        # Start the process
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(cwd)
        )

        # Stream output line by line
        while True:
            line = await process.stdout.readline()
            if not line:
                break
            yield (line.decode('utf-8', errors='replace'), None)

        # Wait for process to complete
        await process.wait()

        # Yield exit code
        yield (f"\n[Exit code: {process.returncode}]\n", process.returncode)

    except Exception as e:
        yield (f"\n[Error: {str(e)}]\n", 1)


@router.get("/build/{template}")
async def build_infrastructure(template: str):
    """
    Run Terraform deployment process with real-time output streaming.

    Executes:
    1. terraform init
    2. terraform plan
    3. terraform apply -auto-approve
    4. generate_verification_data.sh
    5. verify_all.sh --verify all

    Args:
        template: Template name (e.g., "existing_vpc_resources")

    Returns:
        Streaming response with command output
    """
    async def generate():
        try:
            # Validate template
            valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
            if template not in valid_templates:
                yield f"Error: Invalid template. Must be one of: {', '.join(valid_templates)}\n"
                return

            # Get template directory
            terraform_dir = get_terraform_dir()
            template_dir = terraform_dir / template

            if not template_dir.exists():
                yield f"Error: Template directory not found: {template_dir}\n"
                return

            # Check if terraform.tfvars exists
            tfvars_file = template_dir / "terraform.tfvars"
            if not tfvars_file.exists():
                yield f"Error: terraform.tfvars not found. Please generate it first.\n"
                return

            yield f"=== Starting Terraform Deployment for {template} ===\n"
            yield f"Working directory: {template_dir}\n\n"

            # Step 1: terraform init
            yield "=" * 80 + "\n"
            yield "STEP 1: terraform init\n"
            yield "=" * 80 + "\n"
            init_failed = False
            async for line, exit_code in run_command_stream(['terraform', 'init'], template_dir):
                yield line
                if exit_code is not None and exit_code != 0:
                    init_failed = True

            if init_failed:
                yield "\n" + "!" * 80 + "\n"
                yield "ERROR: terraform init failed. Build stopped.\n"
                yield "Please fix the errors above and try again.\n"
                yield "!" * 80 + "\n"
                return

            # Step 2: terraform plan
            yield "\n" + "=" * 80 + "\n"
            yield "STEP 2: terraform plan\n"
            yield "=" * 80 + "\n"
            plan_failed = False
            async for line, exit_code in run_command_stream(['terraform', 'plan'], template_dir):
                yield line
                if exit_code is not None and exit_code != 0:
                    plan_failed = True

            if plan_failed:
                yield "\n" + "!" * 80 + "\n"
                yield "ERROR: terraform plan failed. Build stopped.\n"
                yield "Please fix the errors above and try again.\n"
                yield "!" * 80 + "\n"
                return

            # Step 3: terraform apply
            yield "\n" + "=" * 80 + "\n"
            yield "STEP 3: terraform apply -auto-approve\n"
            yield "=" * 80 + "\n"
            async for line, exit_code in run_command_stream(['terraform', 'apply', '-auto-approve'], template_dir):
                yield line

            # Steps 4 & 5: Verification scripts (only for existing_vpc_resources)
            if template == "existing_vpc_resources":
                verify_scripts_dir = template_dir / "verify_scripts"

                if verify_scripts_dir.exists():
                    # Step 4: generate_verification_data.sh
                    gen_script = verify_scripts_dir / "generate_verification_data.sh"
                    if gen_script.exists():
                        yield "\n" + "=" * 80 + "\n"
                        yield "STEP 4: generate_verification_data.sh\n"
                        yield "=" * 80 + "\n"
                        gen_failed = False
                        async for line, exit_code in run_command_stream(['./generate_verification_data.sh'], verify_scripts_dir):
                            yield line
                            if exit_code is not None and exit_code != 0:
                                gen_failed = True

                        if gen_failed:
                            yield "\n" + "!" * 80 + "\n"
                            yield "ERROR: generate_verification_data.sh failed. Build stopped.\n"
                            yield "Please fix the errors above and try again.\n"
                            yield "!" * 80 + "\n"
                            return

                    # Step 5: verify_all.sh
                    verify_script = verify_scripts_dir / "verify_all.sh"
                    if verify_script.exists():
                        yield "\n" + "=" * 80 + "\n"
                        yield "STEP 5: verify_all.sh --verify all\n"
                        yield "=" * 80 + "\n"
                        verify_failed = False
                        async for line, exit_code in run_command_stream(['./verify_all.sh', '--verify', 'all'], verify_scripts_dir):
                            yield line
                            if exit_code is not None and exit_code != 0:
                                verify_failed = True

                        if verify_failed:
                            yield "\n" + "!" * 80 + "\n"
                            yield "ERROR: verify_all.sh --verify all failed. Build stopped.\n"
                            yield "Please fix the errors above and try again.\n"
                            yield "!" * 80 + "\n"
                            return

            yield "\n" + "=" * 80 + "\n"
            yield "=== Deployment Complete ===\n"
            yield "=" * 80 + "\n"

        except Exception as e:
            logger.error(f"Error during build: {str(e)}")
            yield f"\nError during build: {str(e)}\n"

    return StreamingResponse(generate(), media_type="text/plain")


@router.get("/build/{template}/{step}")
async def build_step(template: str, step: str):
    """
    Run a single Terraform build step with real-time output streaming.

    Args:
        template: Template name (e.g., "existing_vpc_resources")
        step: Step to run (init, plan, apply, verify_data, verify_all)

    Returns:
        Streaming response with command output
    """
    async def generate():
        try:
            # Validate template
            valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
            if template not in valid_templates:
                yield f"Error: Invalid template. Must be one of: {', '.join(valid_templates)}\n"
                return

            # Get template directory
            terraform_dir = get_terraform_dir()
            template_dir = terraform_dir / template

            if not template_dir.exists():
                yield f"Error: Template directory not found: {template_dir}\n"
                return

            # Check if terraform.tfvars exists (except for init)
            if step != "init":
                tfvars_file = template_dir / "terraform.tfvars"
                if not tfvars_file.exists():
                    yield f"Error: terraform.tfvars not found. Please generate it first.\n"
                    return

            yield f"=== Running {step} for {template} ===\n"
            yield f"Working directory: {template_dir}\n\n"

            # Execute the requested step
            if step == "init":
                yield "=" * 80 + "\n"
                yield "terraform init\n"
                yield "=" * 80 + "\n"
                async for line, exit_code in run_command_stream(['terraform', 'init'], template_dir):
                    yield line

            elif step == "plan":
                yield "=" * 80 + "\n"
                yield "terraform plan\n"
                yield "=" * 80 + "\n"
                async for line, exit_code in run_command_stream(['terraform', 'plan'], template_dir):
                    yield line

            elif step == "apply":
                yield "=" * 80 + "\n"
                yield "terraform apply -auto-approve\n"
                yield "=" * 80 + "\n"
                async for line, exit_code in run_command_stream(['terraform', 'apply', '-auto-approve'], template_dir):
                    yield line

            elif step == "destroy":
                yield "=" * 80 + "\n"
                yield "terraform destroy -auto-approve\n"
                yield "=" * 80 + "\n"
                async for line, exit_code in run_command_stream(['terraform', 'destroy', '-auto-approve'], template_dir):
                    yield line

            elif step == "verify_data":
                if template == "existing_vpc_resources":
                    verify_scripts_dir = template_dir / "verify_scripts"
                    gen_script = verify_scripts_dir / "generate_verification_data.sh"
                    if gen_script.exists():
                        yield "=" * 80 + "\n"
                        yield "generate_verification_data.sh\n"
                        yield "=" * 80 + "\n"
                        async for line, exit_code in run_command_stream(['./generate_verification_data.sh'], verify_scripts_dir):
                            yield line
                    else:
                        yield "Error: generate_verification_data.sh not found\n"
                else:
                    yield "Error: Verification scripts only available for existing_vpc_resources\n"

            elif step == "verify_all":
                if template == "existing_vpc_resources":
                    verify_scripts_dir = template_dir / "verify_scripts"
                    verify_script = verify_scripts_dir / "verify_all.sh"
                    if verify_script.exists():
                        yield "=" * 80 + "\n"
                        yield "verify_all.sh --verify all\n"
                        yield "=" * 80 + "\n"
                        async for line, exit_code in run_command_stream(['./verify_all.sh', '--verify', 'all'], verify_scripts_dir):
                            yield line
                    else:
                        yield "Error: verify_all.sh not found\n"
                else:
                    yield "Error: Verification scripts only available for existing_vpc_resources\n"

            else:
                yield f"Error: Invalid step '{step}'. Valid steps: init, plan, apply, destroy, verify_data, verify_all\n"
                return

            yield "\n" + "=" * 80 + "\n"
            yield f"=== Step '{step}' Complete ===\n"
            yield "=" * 80 + "\n"

        except Exception as e:
            logger.error(f"Error during build step {step}: {str(e)}")
            yield f"\nError during {step}: {str(e)}\n"

    return StreamingResponse(generate(), media_type="text/plain")


def convert_to_markdown(content: str) -> str:
    """
    Convert verify_all output to markdown format with sections reordered.
    Verification Summary first (with failure details if any), then Public IPs, Default Routes, etc.
    """
    import re

    # Strip ANSI escape codes
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_content = ansi_escape.sub('', content)

    # Check for failures and extract failure details
    has_failures = 'SOME VERIFICATIONS FAILED' in clean_content or 'Scripts Failed:' in clean_content

    # Extract individual failure details
    failure_details = []
    if has_failures:
        # Look for lines containing [FAILED] and capture the full context
        # e.g., "Testing FortiAnalyzer (35.84.51.193)... [FAILED] UNREACHABLE"
        fail_pattern = r'^.*\[FAILED\].*$'
        fails = re.findall(fail_pattern, clean_content, re.MULTILINE)
        failure_details = list(set(fails))  # Remove duplicates

    # Define section patterns and their markdown headers
    sections = {
        'verification_summary': {
            'pattern': r'={10,}\s*\nOVERALL VERIFICATION SUMMARY\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Verification Summary',
            'order': 1
        },
        'public_ips': {
            'pattern': r'={10,}\s*\nALL PUBLIC IP ADDRESSES\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Public IP Addresses',
            'order': 2
        },
        'default_routes': {
            'pattern': r'={10,}\s*\nALL DEFAULT ROUTES \(0\.0\.0\.0/0\)\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Default Routes (0.0.0.0/0)',
            'order': 3
        },
        'transit_gateway': {
            'pattern': r'={10,}\s*\nTRANSIT GATEWAY\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Transit Gateway',
            'order': 4
        },
        'management_vpc': {
            'pattern': r'={10,}\s*\nMANAGEMENT VPC\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Management VPC',
            'order': 5
        },
        'inspection_vpc': {
            'pattern': r'={10,}\s*\nINSPECTION VPC\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## Inspection VPC',
            'order': 6
        },
        'east_vpc': {
            'pattern': r'={10,}\s*\nEAST SPOKE VPC\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## East Spoke VPC',
            'order': 7
        },
        'west_vpc': {
            'pattern': r'={10,}\s*\nWEST SPOKE VPC\s*\n={10,}\s*\n(.*?)(?=\n={10,}|\Z)',
            'header': '## West Spoke VPC',
            'order': 8
        },
    }

    # Extract sections
    extracted = []
    for key, section in sections.items():
        match = re.search(section['pattern'], clean_content, re.DOTALL | re.IGNORECASE)
        if match:
            content_text = match.group(1).strip()
            if content_text:
                # Convert table-like output to markdown tables where appropriate
                lines = content_text.split('\n')
                formatted_lines = []

                # Check if this looks like a table (has header line with dashes)
                is_table = False
                for i, line in enumerate(lines):
                    if re.match(r'^[-\s]+$', line) and i > 0:
                        is_table = True
                        break

                if is_table and key in ['public_ips', 'default_routes']:
                    # Format as markdown table
                    # For default_routes, split by looking for ID patterns to handle overflow
                    for i, line in enumerate(lines):
                        if i == 0:
                            # Header row
                            cols = re.split(r'\s{2,}', line.strip())
                            if key == 'default_routes':
                                cols.append('VPC')
                            formatted_lines.append('| ' + ' | '.join(cols) + ' |')
                        elif re.match(r'^[-\s]+$', line):
                            # Separator row - count columns from header
                            header_cols = re.split(r'\s{2,}', lines[0].strip())
                            num_cols = len(header_cols) + (1 if key == 'default_routes' else 0)
                            formatted_lines.append('| ' + ' | '.join(['---'] * num_cols) + ' |')
                        else:
                            # Data row
                            if key == 'default_routes':
                                # Parse by finding AWS resource ID patterns
                                # Pattern: NAME ... (rtb-xxx|tgw-rtb-xxx) ... (tgw-attach-xxx|igw-xxx|No default route)
                                match = re.match(
                                    r'^(.+?)\s{2,}((?:rtb|tgw-rtb)-[a-z0-9]+)\s+(.+)$',
                                    line.strip()
                                )
                                if match:
                                    cols = [match.group(1).strip(), match.group(2).strip(), match.group(3).strip()]
                                else:
                                    # Fall back to whitespace splitting
                                    cols = re.split(r'\s{2,}', line.strip())

                                # Add VPC column - only populate if target is a tgw-attach
                                # Look up which VPC the target attachment belongs to
                                vpc_letter = ''
                                target = cols[2] if len(cols) > 2 else ''
                                if 'tgw-attach-' in target:
                                    # Extract the attachment ID from target
                                    attach_match = re.search(r'(tgw-attach-[a-z0-9]+)', target)
                                    if attach_match:
                                        attach_id = attach_match.group(1)
                                        # Search the full content for this attachment to find its VPC
                                        # Pattern: {prefix}-{vpc}-tgw-attachment: tgw-attach-xxx
                                        attach_pattern = rf'(\w+)-tgw-attachment:\s*{attach_id}'
                                        vpc_match = re.search(attach_pattern, clean_content, re.IGNORECASE)
                                        if vpc_match:
                                            vpc_name = vpc_match.group(1).lower()
                                            # Get the last part (vpc name) from prefix-env-vpcname
                                            if 'inspection' in vpc_name:
                                                vpc_letter = 'I'
                                            elif 'management' in vpc_name:
                                                vpc_letter = 'M'
                                            elif 'east' in vpc_name:
                                                vpc_letter = 'E'
                                            elif 'west' in vpc_name:
                                                vpc_letter = 'W'
                                cols.append(vpc_letter)
                            else:
                                # Split by 2+ whitespace for other tables
                                cols = re.split(r'\s{2,}', line.strip())
                            if cols and cols[0]:
                                formatted_lines.append('| ' + ' | '.join(cols) + ' |')
                    content_text = '\n'.join(formatted_lines)
                else:
                    # Wrap in code block for other sections
                    content_text = '```\n' + content_text + '\n```'

                # Add failure details after verification summary if there are failures
                if key == 'verification_summary' and has_failures and failure_details:
                    content_text += '\n\n### Failure Details\n\n'
                    for detail in failure_details:
                        content_text += f'- {detail}\n'

                extracted.append({
                    'order': section['order'],
                    'header': section['header'],
                    'content': content_text
                })

    # Sort by order
    extracted.sort(key=lambda x: x['order'])

    # Build markdown output
    md_lines = []
    for section in extracted:
        md_lines.append(section['header'])
        md_lines.append('')
        md_lines.append(section['content'])
        md_lines.append('')

    return '\n'.join(md_lines)


@router.post("/save-log")
async def save_log(request: SaveLogRequest):
    """
    Save build output to verify_all.md file in logs directory.

    Args:
        request: SaveLogRequest with template, content, and mode (append/truncate)

    Returns:
        Success message with file path
    """
    import re
    from datetime import datetime

    try:
        # Validate template
        valid_templates = ['existing_vpc_resources', 'autoscale_template', 'ha_pair']
        if request.template not in valid_templates:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid template. Must be one of: {', '.join(valid_templates)}"
            )

        # Validate mode
        if request.mode not in ['append', 'truncate']:
            raise HTTPException(
                status_code=400,
                detail="Mode must be 'append' or 'truncate'"
            )

        # Get logs directory in root
        terraform_dir = get_terraform_dir()
        logs_dir = terraform_dir.parent / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        log_file = logs_dir / "verify_all.md"

        # Convert to markdown format
        markdown_content = convert_to_markdown(request.content)

        # Add timestamp header
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header = f"# Verification Log - {timestamp}\n\n"
        header += f"**Template:** `{request.template}`\n\n---\n\n"

        # Write to file
        if request.mode == 'append':
            with open(log_file, 'a') as f:
                f.write('\n\n' + header + markdown_content)
        else:
            with open(log_file, 'w') as f:
                f.write(header + markdown_content)

        logger.info(f"Saved log to {log_file} (mode: {request.mode})")

        return {
            "success": True,
            "message": f"Log saved successfully ({request.mode})",
            "file": str(log_file)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving log: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
