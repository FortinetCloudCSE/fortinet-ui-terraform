# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**IMPORTANT:** When adding new files, directories, or significant architectural changes to this repository, update this CLAUDE.md file to reflect those changes. This ensures future Claude Code instances have accurate context about the codebase structure.

## Developer Preferences

**Git Workflow:**
- **DO NOT** create git commits automatically
- **WAIT** for explicit user instruction before committing changes
- Make code changes and let the user review before committing
- User will decide when to commit (saves tokens and provides control)

## Session Reminders

**Remind the user at the start of each session:**
- The `verify_all.sh` script now automatically generates network diagram files (`logs/network_diagram.svg` and `logs/network_diagram.md`) at the end of the verification process
- Run `./verify_scripts/verify_all.sh --verify all` from `terraform/existing_vpc_resources/` to verify infrastructure AND generate updated network diagrams
- The `generate_network_diagram.sh` script can also be run standalone to regenerate diagrams without running full verification

## Project Overview

This repository contains the **FortiGate Autoscale Simplified Template** - a Terraform-based solution that simplifies the deployment of FortiGate autoscale groups in AWS. It serves as a wrapper around Fortinet's enterprise-grade [terraform-aws-cloud-modules](https://github.com/fortinetdev/terraform-aws-cloud-modules) to reduce deployment complexity while maintaining architectural flexibility.

The project includes:
- Terraform templates for deploying FortiGate autoscale groups with AWS Gateway Load Balancer (GWLB)
- Supporting infrastructure templates for testing and lab environments
- Hugo-based documentation workshop hosted at https://fortinetcloudcse.github.io/fortinet-ui-terraform/

## Repository Structure

### Terraform Templates

Three main Terraform template directories exist under `terraform/`:

1. **`terraform/autoscale_template/`** - Core FortiGate autoscale deployment
   - Wraps the upstream `terraform-aws-cloud-modules` module
   - Main entry point: `autoscale_group.tf` (module invocation)
   - Configuration abstraction: `easy_autoscale.tf` (data sources and locals)
   - NAT Gateway logic: `nat_gw.tf`
   - Transit Gateway route updates: Updates east/west TGW route tables to point default routes to inspection VPC
   - FortiGate configuration templates: `*-arm-*-fgt-conf.cfg` files (1-arm/2-arm modes)
   - License directory: `asg_license/` for BYOL license files

2. **`terraform/ha_pair/`** - FortiGate HA Pair deployment (Active-Passive FGCP)
   - Deploys a fixed Active-Passive FortiGate HA pair without GWLB
   - Main files:
     - `main.tf` - Provider configuration
     - `variables.tf` - Input variables
     - `data_sources.tf` - Discovers existing resources from existing_vpc_resources
     - `vpc_resources.tf` - VPC endpoint for EC2 API (Private DNS enabled)
     - `security_groups.tf` - Security groups for FortiGate interfaces
     - `iam.tf` - IAM role with permissions for EIP/route reassignment
     - `fortigate_instances.tf` - Network interfaces and EC2 instances
     - `eips.tf` - Elastic IPs and associations
     - `userdata.tf` - Template data sources for FortiGate configs
     - `tgw_routes.tf` - Transit Gateway route table updates
     - `outputs.tf` - Output values
   - Configuration templates in `config_templates/`:
     - `primary-fortigate-userdata.tpl` - Primary FortiGate bootstrap config (priority 255)
     - `secondary-fortigate-userdata.tpl` - Secondary FortiGate bootstrap config (priority 1)
   - **Prerequisites**: Deploy `existing_vpc_resources` first with HA Pair deployment mode enabled
   - **Key Features**:
     - FGCP (FortiGate Clustering Protocol) with unicast heartbeat
     - Session synchronization for stateful failover
     - VPC endpoint for private AWS API access
     - Automatic EIP/ENI reassignment on failover
     - Transit Gateway routing updates (removes management VPC routes, adds inspection VPC routes)

3. **`terraform/existing_vpc_resources/`** - Supporting infrastructure for testing and deployment
   - Creates management VPCs, Transit Gateway, spoke VPCs, inspection VPC, distributed VPCs, and test instances
   - **Deployment Mode Selection**: Two mutually exclusive options
     - `enable_autoscale_deployment` (default: true) - Creates GWLB subnets for autoscale template
     - `enable_ha_pair_deployment` (default: false) - Creates HA sync subnets for ha_pair template
   - Split across multiple files:
     - `vpc_management.tf` - Management VPC for jump box, FortiManager, FortiAnalyzer
     - `vpc_inspection.tf` - Inspection VPC with public/private subnets and conditional HA sync subnets
     - `vpc_east.tf` - East spoke VPC
     - `vpc_west.tf` - West spoke VPC
     - `vpc_distributed.tf` - Distributed VPCs (not attached to TGW, use GWLB endpoints for inspection)
     - `tgw.tf` - Transit Gateway and attachments, TGW route tables
     - `ec2.tf` - FortiManager, FortiAnalyzer, jump box, spoke instances
     - `outputs.tf` - Comprehensive outputs for resource discovery
   - User-data templates in `config_templates/`:
     - `fmgr-userdata.tftpl` - FortiManager instance initialization
     - `faz-userdata.tftpl` - FortiAnalyzer instance initialization
     - `jump-box-userdata.tpl` - Management VPC jump box/bastion host (basic tooling, no NAT forwarding)
     - `spoke-instance-userdata.tpl` - East/West spoke VPC test instances (web server, FTP, traffic generation tools)
     - `web-userdata.tpl` - Legacy template (deprecated, replaced by spoke-instance-userdata.tpl)
   - Verification scripts in `verify_scripts/`:
     - `verify_all.sh` - Master script to run all verification scripts
     - `verify_management_vpc.sh` - Verify Management VPC resources
     - `verify_inspection_vpc.sh` - Verify Inspection VPC resources
     - `verify_east_vpc.sh` - Verify East spoke VPC resources
     - `verify_west_vpc.sh` - Verify West spoke VPC resources
     - `verify_distributed_vpcs.sh` - Verify Distributed VPC resources
     - `verify_connectivity.sh` - Test ping connectivity to public IPs
     - `verify_summary.sh` - Display infrastructure resource summary
     - `common_functions.sh` - Shared functions for verification scripts
     - `generate_verification_data.sh` - Generate Terraform output data for faster verification
   - **HA Sync Subnets**: Created in inspection VPC (indices 10 & 11) when `enable_ha_pair_deployment = true`
     - Subnet AZ1: `${cp}-${env}-ha-sync-az1-subnet`
     - Subnet AZ2: `${cp}-${env}-ha-sync-az2-subnet`
     - Route tables with IGW routes for AWS API access
     - Used by ha_pair template for FortiGate heartbeat and session sync
   - **Distributed VPCs**: Created when `enable_distributed_egress_vpcs = true`
     - Up to 3 VPCs (controlled by `distributed_egress_vpc_count`)
     - NOT attached to Transit Gateway
     - 3-tier subnet pattern per AZ: public, private, GWLBE
     - GWLBE subnets for Gateway Load Balancer Endpoints (traffic hairpins through FortiGates)
     - Linux test instances with public IPs (required for access since no TGW connectivity)
     - Tagged with `purpose=distributed_egress` for discovery by autoscale_template

### Web UI Application

Located in `ui/` directory:
- **Backend**: Python FastAPI application (`ui/backend/`)
  - `app/api/terraform.py` - Terraform configuration generation and validation
  - `app/api/aws.py` - AWS resource discovery (regions, AZs, keypairs, etc.)
  - Supports three templates: `existing_vpc_resources`, `autoscale_template`, `ha_pair`
  - Config inheritance: Both `autoscale_template` and `ha_pair` inherit base settings from `existing_vpc_resources`
- **Frontend**: React application (`ui/frontend/`)
  - `src/components/TerraformConfig.jsx` - Main configuration UI component
  - Template dropdown includes all three templates
  - Form groups with field validation and conditional visibility

### AWS Credentials for UI

The UI backend requires AWS credentials to discover resources. Two authentication methods are supported:

**Method 1: Environment Variables (Local Development)**
```bash
# Use the aws_login.sh script which sets local env vars AND posts to UI backend
source ~/.local/bin/aws_login.sh [profile] [backend_url]

# Examples:
source ~/.local/bin/aws_login.sh                              # Default profile, local backend
source ~/.local/bin/aws_login.sh 40netse                      # Specific profile
source ~/.local/bin/aws_login.sh 40netse http://remote:8000   # Remote backend
```

**Method 2: Session Credentials API (Remote/Container Deployments)**

When the UI runs in a container (FortiManager, SASE environment), credentials can be posted via API:

```bash
# POST credentials to backend
curl -X POST http://backend:8000/api/aws/credentials/set \
  -H "Content-Type: application/json" \
  -d '{"access_key": "AKIA...", "secret_key": "...", "session_token": "..."}'

# Check credential status
curl http://backend:8000/api/aws/credentials/status

# Clear credentials (fall back to env vars)
curl -X DELETE http://backend:8000/api/aws/credentials/clear
```

The `aws_login.sh` script automatically handles both methods - it exports credentials locally for CLI use and POSTs them to the backend for UI use.

### Documentation

The `content/` directory contains Hugo-formatted markdown for the workshop documentation:
- `1_Introduction/` - Overview and prerequisites
- `2_Overview/` - Architecture and key benefits
- `3_Licensing/` - BYOL, PAYG, and FortiFlex licensing models
- `4_Solution_Components/` - In-depth architectural explanations
- `5_Templates/` - Deployment procedures and configuration examples

## Key Architectural Concepts

### Deployment Modes

**Firewall Policy Mode:**
- `1-arm`: Single interface for data plane (hairpin traffic pattern)
- `2-arm`: Separate trusted/untrusted interfaces (traditional firewall model)

**Internet Access Mode:**
- `eip`: Elastic IP per FortiGate instance (distributed egress)
- `nat_gw`: NAT Gateway for centralized egress (requires additional configuration)

**Management Options:**
- Standard: Management via data plane interfaces
- `enable_dedicated_management_eni`: Dedicated management ENI in inspection VPC
- `enable_dedicated_management_vpc`: Management in separate VPC (requires existing_vpc_resources)

### Resource Naming Convention

Resources use the pattern: `{cp}-{env}-{resource_name}`
- `cp` (Customer Prefix): Company/project identifier (e.g., "acme")
- `env` (Environment): Environment name (e.g., "test", "prod")
- Example: "acme-test-inspection-vpc"

**Critical:** The `cp` and `env` values MUST match between templates for resource discovery via AWS tags.

### Transit Gateway Routing Behavior

Both `autoscale_template` and `ha_pair` implement a two-stage routing approach:

**Stage 1: After existing_vpc_resources deployment**
- East/West spoke VPC default routes point to Management VPC attachment
- Allows spoke instances to bootstrap via Management VPC jump box NAT
- Spoke instances can successfully run cloud-init and pull packages

**Stage 2: After autoscale_template or ha_pair deployment**
- Template automatically deletes old default routes from east/west TGW route tables
- Creates new default routes pointing to Inspection VPC attachment
- Traffic from spoke VPCs now flows through FortiGate instances
- Management VPC specific routes remain for ongoing management access

This two-stage approach ensures spoke instances can bootstrap before FortiGates are ready to forward traffic. The route updates are handled automatically by `easy_autoscale.tf` (autoscale) or `tgw_routes.tf` (ha_pair).

### Network Diagram Layout Conventions

When creating or updating network diagrams (SVG format) for this infrastructure, use the following layout:

**Data Sources:**
- Read `terraform/existing_vpc_resources/terraform.tfvars` for VPC CIDRs, subnet_bits, host IPs, region, AZs
- Read `terraform/autoscale_template/terraform.tfvars` for firewall_policy_mode, enable_dedicated_management_vpc settings
- Calculate subnet CIDRs using Terraform's cidrsubnet() logic
- Calculate host IPs using cidrhost() logic
- If user provides instance IP information (e.g., from AWS CLI or terraform output), include it in the diagram
- FortiGate ASG instance IPs can be obtained post-deployment via:
  - AWS CLI: `aws ec2 describe-instances --filters "Name=tag:Name,Values=*fortigate*" --query 'Reservations[].Instances[].[PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]'`
  - User providing the information directly when requesting the diagram

**Overall Layout (top to bottom):**
1. **Top Row**: Management VPC (left), Inspection VPC (right)
2. **Middle**: Transit Gateway
3. **Below TGW**: Spoke VPCs (East on left, West on right)
4. **Bottom**: Distributed VPCs (with gap/space separating from Spoke VPCs)

**Internet Gateway Placement:**
- IGWs are positioned **outside and above** their respective VPCs
- Draw connector lines from IGW to the VPC
- Apply to: Management VPC, Inspection VPC, and Distributed VPCs

**Management VPC Layout:**
- Public subnets (AZ1, AZ2)
- Jump Box instance in AZ1 with private IP and public IP (if available)

**Inspection VPC Subnet Layout (2x3 grid):**
```
+------------------+------------------+
| NAT GW Subnets   | Public Subnets   |  <- Row 1
| (AZ1, AZ2)       | (AZ1, AZ2)       |
+------------------+------------------+
| TGW Subnets      | GWLB Subnets     |  <- Row 2
| (AZ1, AZ2)       | (AZ1, AZ2)       |
+------------------+------------------+
|                  | Private Subnets  |  <- Row 3
|                  | (AZ1, AZ2)       |
+------------------+------------------+
```
- FortiGate Auto Scaling Group box on the right side showing:
  - Deployment mode (1-arm or 2-arm)
  - Port assignments based on configuration:
    - **2-arm mode without dedicated mgmt**: port1=Public, port2=GWLB
    - **2-arm mode with dedicated mgmt VPC**: port1=Public, port2=GWLB, port3=Mgmt VPC (VRF 1)
    - **1-arm mode**: port1=GWLB (single interface)
  - If ASG is deployed and user provides IP info: show primary instance private/public IPs in green

**Spoke VPC Layout (East and West):**
```
+---------------------------+---------------------------+
| Public AZ1                | Public AZ2                |
| (Linux instance + IPs)    | (Linux instance + IPs)    |
+---------------------------+---------------------------+
| TGW AZ1                   | TGW AZ2                   |
+---------------------------+---------------------------+
```

**Distributed VPC Subnet Layout (stacked vertically):**
```
+---------------------------+
| Public Subnets (AZ1, AZ2) |  <- Top
+---------------------------+
| GWLBE Subnets (AZ1, AZ2)  |  <- Middle
+---------------------------+
| Private Subnets (AZ1, AZ2)|  <- Bottom
| (with Linux instances)    |
+---------------------------+
```

**Color Coding (using gradients defined in SVG defs):**
- Public subnets: Green gradient (`#1B660F`)
- Private subnets: Blue gradient (`#147EBA`)
- TGW subnets: Purple gradient (`#8C4FFF`)
- GWLB/GWLBE subnets: Orange gradient (`#ED7100`)
- NAT GW subnets: Blue (same as private)
- Transit Gateway: Purple gradient
- FortiGate ASG: Red (`#EE3124`)
- EC2 instances: Dark background (`#232F3E`) with orange border (`#FF9900`)
- Public IPs: Bright green (`#00FF00`)
- VPC borders: Blue (`#3B48CC`)

**IP Information Display:**
- Show subnet CIDRs with index numbers where applicable
- Show private IPs for instances in white/orange
- Show public IPs in bright green (`#00FF00`) when available
- Include IP summary table in the legend section

**Legend Section:**
- Color key for all subnet types
- Host IP assignments summary with both private and public IPs
- Note which instances have public IPs vs TGW-routed (no public IP)

**Reference Diagram:**
See `network-diagram.svg` in the repository root for the canonical layout example (note: this file is in .gitignore as it changes per deployment).

### Module Integration

The autoscale template invokes the upstream module from:
```
git::https://github.com/fortinetdev/terraform-aws-cloud-modules.git//examples/spk_tgw_gwlb_asg_fgt_igw
```

The simplified template (`easy_autoscale.tf`) uses data sources to discover existing resources by tag names and constructs the complex nested map structures required by the upstream module.

## Terraform Workflow

**Important:** Deploy `existing_vpc_resources` FIRST, then deploy either `autoscale_template` OR `ha_pair`.

### Deployment Order

1. **First: existing_vpc_resources** - Creates base infrastructure
2. **Second: Choose ONE of:**
   - `autoscale_template` - For AutoScale deployment with GWLB
   - `ha_pair` - For HA Pair deployment with FGCP

### For existing_vpc_resources

```bash
cd terraform/existing_vpc_resources

terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
# Set enable_autoscale_deployment = true OR enable_ha_pair_deployment = true
terraform plan
terraform apply
```

**Key Variables:**
- `enable_autoscale_deployment = true` - Creates GWLB subnets for autoscale_template
- `enable_ha_pair_deployment = true` - Creates HA sync subnets for ha_pair template
- These are **mutually exclusive** - only one should be enabled

### For autoscale_template

```bash
cd terraform/autoscale_template

terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
# cp and env must match existing_vpc_resources
terraform plan
terraform apply
```

**Prerequisites:**
- `existing_vpc_resources` deployed with `enable_autoscale_deployment = true`
- `cp` and `env` values must match

### For ha_pair

```bash
cd terraform/ha_pair

terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
# cp and env must match existing_vpc_resources
terraform plan
terraform apply
```

**Prerequisites:**
- `existing_vpc_resources` deployed with `enable_ha_pair_deployment = true`
- `cp` and `env` values must match
- HA sync subnets will be discovered automatically

### Cleanup

```bash
# Destroy in reverse order
cd terraform/autoscale_template  # OR cd terraform/ha_pair
terraform destroy

cd terraform/existing_vpc_resources
terraform destroy
```

## Configuration File Locations

### Primary Configuration Files

- `terraform/existing_vpc_resources/terraform.tfvars.example` - Base infrastructure configuration
- `terraform/autoscale_template/terraform.tfvars.example` - AutoScale configuration template
- `terraform/ha_pair/terraform.tfvars.example` - HA Pair configuration template
- All `.example` files should be copied to `terraform.tfvars` and customized

### FortiGate Configuration Templates

**AutoScale Templates** - Located in `terraform/autoscale_template/`:
- `1-arm-fgt-conf.cfg` - Single interface mode
- `2-arm-fgt-conf.cfg` - Dual interface mode
- `1-arm-wdm-fgt-conf.cfg` - Single interface with dedicated management VPC
- `2-arm-wdm-eni-fgt-conf.cfg` - Dual interface with dedicated management ENI
- etc.

The correct template is selected automatically based on `firewall_policy_mode`, `enable_dedicated_management_vpc`, and `enable_dedicated_management_eni` variables.

**HA Pair Templates** - Located in `terraform/ha_pair/config_templates/`:
- `primary-fortigate-userdata.tpl` - Primary FortiGate (priority 255, HA group master)
- `secondary-fortigate-userdata.tpl` - Secondary FortiGate (priority 1, HA group slave)

Both templates configure:
- FGCP HA mode (Active-Passive)
- Unicast heartbeat over port3
- Session synchronization
- FortiManager/FortiAnalyzer integration (if enabled)
- AWS SDN connector for failover operations

### Linux Instance User-Data Templates

Located in `terraform/existing_vpc_resources/config_templates/`:

- **`jump-box-userdata.tpl`** - Management VPC jump box/bastion host
  - Basic system tools (sysstat, net-tools, awscli, apache2)
  - Terraform tooling (tfenv with version 1.7.5)
  - AWS credential configuration
  - **Does NOT include** NAT forwarding or iptables configuration
  - Used by: Management VPC jump box instance

- **`spoke-instance-userdata.tpl`** - Spoke VPC test instances (East/West)
  - All tools from jump-box template plus:
  - iperf3 for network performance testing
  - vsftpd for FTP testing
  - Sample FortiGate configuration examples
  - **Does NOT include** NAT forwarding or iptables configuration (removed to prevent instances acting as routers)
  - Used by: East and West spoke VPC Linux instances

- **`fmgr-userdata.tftpl`** - FortiManager initialization template
  - License injection
  - Admin password configuration
  - Hostname customization

- **`faz-userdata.tftpl`** - FortiAnalyzer initialization template
  - License injection
  - Admin password configuration
  - Hostname customization

**Note:** The original `web-userdata.tpl` included NAT forwarding configuration that allowed instances to forward traffic. This has been removed in the new spoke-instance templates to prevent security issues and unintended routing behavior.

## Important Variables

### Critical Matching Values

These must match between templates:
- `cp` - Customer prefix (e.g., "acme")
- `env` - Environment name (e.g., "test", "prod")
- `attach_to_tgw_name` - Transit Gateway name (if using TGW)
- `vpc_cidr_management` - Management VPC CIDR

**IMPORTANT:**
- Both `autoscale_template` and `ha_pair` inherit `cp`, `env`, and other base settings from `existing_vpc_resources`
- The Web UI automatically handles this inheritance
- Manual deployments must ensure these values match exactly

### Security Variables

- `keypair` - Existing EC2 key pair name (must exist in region)
- `management_cidr_sg` - IP/CIDR allowlist for security group access (was `my_ip`)
- `fortigate_asg_password` - FortiGate admin password (autoscale_template)
- `fortigate_admin_password` - FortiGate admin password (ha_pair)
- `ha_password` - HA heartbeat password (ha_pair only)
- `fortimanager_admin_password` - FortiManager admin password (if enabled)
- `fortianalyzer_admin_password` - FortiAnalyzer admin password (if enabled)

## License Management

### FortiGate Licenses

**AutoScale Template:**
Place BYOL license files in `terraform/autoscale_template/asg_license/`:
- BYOL licenses: `license1.lic`, `license2.lic`, etc.
- FortiFlex: Lambda function generates tokens (no files needed)
- PAYG: Uses AWS Marketplace licensing (no files needed)

**HA Pair Template:**
Three licensing modes supported:
- **PAYG**: AWS Marketplace hourly billing (no license files needed)
- **BYOL**: Specify paths in `fgt_primary_license_file` and `fgt_secondary_license_file`
- **FortiFlex**: Provide token in `fortiflex_token` variable

### FortiManager/FortiAnalyzer Licenses

Place in separate directory (NOT in `asg_license/`):
- Specify path in `fortimanager_license_file` variable
- Specify path in `fortianalyzer_license_file` variable
- Leave empty ("") for PAYG instances

## Documentation Development

### Building Documentation Locally

The documentation uses Hugo and runs in Docker:

```bash
# Build documentation site
npm run hugo

# Output goes to docs/ directory
```

This runs a Docker container with the Hugo static site generator. The documentation is published to GitHub Pages from the `docs/` directory.

### Documentation Configuration

- `config.toml` - Hugo site configuration
- `content/` - Markdown content files
- `layouts/` - Custom Hugo templates (if present)
- `docs/` - Generated static site (git-tracked for GitHub Pages)

## Git Workflow

Current branch: `add_ha`
Main branch: `main`

The repository uses feature branches for development. Current work involves adding HA (High Availability) capabilities to the templates.

## Troubleshooting

### Terraform Debug Logging

Enable detailed logging:
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform_debug.log
terraform apply
```

### Common Issues

1. **Resource not found errors**: Verify `cp` and `env` values match between templates
2. **License application failures**: Ensure license files are in correct directory and Lambda has S3 permissions
3. **FortiManager connection failures**: Check `fortimanager_ip` is reachable from FortiGate management interfaces
4. **CIDR overlap errors**: Ensure all VPC CIDRs are non-overlapping

### Validation Scripts

The `terraform/existing_vpc_resources/verify_scripts/` directory contains scripts for validating deployments:

```bash
# Run all verification scripts
./verify_scripts/verify_all.sh --verify all

# Verify specific components
./verify_scripts/verify_all.sh --verify management
./verify_scripts/verify_all.sh --verify inspection
./verify_scripts/verify_all.sh --verify east
./verify_scripts/verify_all.sh --verify west
./verify_scripts/verify_all.sh --verify distributed
./verify_scripts/verify_all.sh --verify spoke        # Both east and west
./verify_scripts/verify_all.sh --verify connectivity # Ping tests

# Generate Terraform output data for faster verification
./verify_scripts/generate_verification_data.sh
```

**Distributed VPC Verification** (`verify_distributed_vpcs.sh`) checks:
- VPC existence and CIDR blocks
- Internet Gateway attached
- Subnets in both AZs (public, private, GWLBE)
- Route tables with correct default routes (all point to IGW)
- EC2 instances (if enabled) with public IPs
- Security groups
- VPC tags (`purpose=distributed_egress`)

## AWS Requirements

### Required AWS Resources

- EC2 key pair (must exist before deployment)
- S3 bucket (for BYOL licenses)
- Sufficient EC2 instance limits for autoscale group size

### AWS Permissions Needed

Terraform requires IAM permissions for:
- VPC, subnet, route table, IGW operations
- EC2 instance, security group, ENI operations
- Gateway Load Balancer and endpoints
- Transit Gateway and attachments
- Lambda function deployment
- IAM role/policy creation
- CloudWatch logs and alarms

## Cost Considerations

Estimated monthly costs for full lab deployment:

**Base Infrastructure (existing_vpc_resources):**
- FortiManager m5.xlarge: ~$73/month (if enabled)
- FortiAnalyzer m5.xlarge: ~$73/month (if enabled)
- Transit Gateway: ~$36/month + data processing
- NAT Gateways: $0.045/hour per AZ + data processing (if enabled)
- VPC resources: Minimal (subnets, route tables, IGW are free)

**AutoScale Deployment:**
- FortiGate instances: Varies by instance type, count, and licensing
- Gateway Load Balancer: ~$22/month + data processing
- Lambda functions: Minimal cost

**HA Pair Deployment:**
- FortiGate instances (2): Varies by instance type and licensing (typically c5n.xlarge or larger)
- Elastic IPs (4-6): $0.005/hour per EIP (~$3.60/month each)
- VPC Interface Endpoint (EC2 API): ~$7.20/month + data processing
- No GWLB costs

Always `terraform destroy` test environments when not in use to minimize costs.

## Future Work / TODO

### Container Deployment Path Resolution

**Status:** Not yet implemented

The UI backend (`ui/backend/app/api/terraform.py`) currently locates terraform templates using a path relative to the code location:

```python
def get_terraform_dir() -> Path:
    return Path(__file__).parent.parent.parent.parent.parent / "terraform"
```

This works for local development but **will break in container deployments** (SASE environment, FortiManager container) where the terraform templates may be mounted at a different location.

**Required fix:** Update `get_terraform_dir()` to support an environment variable with fallback:

```python
import os
from pathlib import Path

def get_terraform_dir() -> Path:
    """Get path to terraform directory."""
    # Check for environment variable first (for container deployments)
    if terraform_path := os.environ.get("TERRAFORM_TEMPLATES_DIR"):
        return Path(terraform_path)

    # Fall back to relative path for local development
    return Path(__file__).parent.parent.parent.parent.parent / "terraform"
```

**Container deployment:** Set `TERRAFORM_TEMPLATES_DIR=/path/to/templates` in the container environment.

## External References

- Upstream module: https://github.com/fortinetdev/terraform-aws-cloud-modules
- FortiGate documentation: https://docs.fortinet.com/
- Workshop site: https://fortinetcloudcse.github.io/fortinet-ui-terraform/
