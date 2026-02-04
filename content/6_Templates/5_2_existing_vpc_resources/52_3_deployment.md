---
title: "Step-by-Step Deployment"
menuTitle: "Deployment Guide"
weight: 3
---

## Step-by-Step Deployment

### Prerequisites

- AWS account with appropriate permissions
- Terraform 1.0 or later installed
- AWS CLI configured with credentials
- Git installed
- SSH keypair created in target AWS region

### Step 1: Clone the Repository

Clone the repository containing both templates:

```bash
git clone https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git
cd fortinet-ui-terraform/terraform/existing_vpc_resources
```

![Clone Repository](../clone-repository.png)

### Step 2: Create terraform.tfvars

Copy the example file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

### Step 3: Configure Core Variables

#### Region and Availability Zones

![Region and AZ](../region-az.png)

```hcl
aws_region         = "us-west-2"
availability_zone_1 = "a"
availability_zone_2 = "c"
```

{{% notice tip %}}
**Availability Zone Selection**

Choose AZs that:
- Support your desired instance types
- Have sufficient capacity
- Match your production environment (if testing for production)

Verify AZ availability:
```bash
aws ec2 describe-availability-zones --region us-west-2
```
{{% /notice %}}

#### Customer Prefix and Environment

![Customer Prefix and Environment](../cp-env.png)

These values are prepended to all resources for identification:

```hcl
cp  = "acme"    # Customer prefix
env = "test"    # Environment: prod, test, dev
```

**Result**: Resources named like `acme-test-management-vpc`, `acme-test-tgw`, etc.

![Customer Prefix Example](../cp-env-example.png)

{{% notice warning %}}
**Critical: Variable Coordination**

These `cp` and `env` values **must match** between `existing_vpc_resources` and `autoscale_template` for proper resource discovery via tags.
{{% /notice %}}

### Step 4: Select Deployment Mode (REQUIRED)

**This is a critical decision** - you must choose ONE deployment mode:

![Deployment Mode Selection](../deployment-mode-selection.png)

#### Option A: AutoScale Deployment

**Choose this if** you plan to deploy [autoscale_template](../5_3_autoscale_template/) for elastic scaling:

```hcl
enable_autoscale_deployment = true
enable_ha_pair_deployment   = false
```

This creates GWLB subnets (indices 4 & 5) for Gateway Load Balancer endpoints.

#### Option B: HA Pair Deployment

**Choose this if** you plan to deploy [ha_pair template](../5_4_ha_pair/) for fixed Active-Passive deployment:

```hcl
enable_autoscale_deployment = false
enable_ha_pair_deployment   = true
```

This creates HA sync subnets (indices 10 & 11) for FGCP cluster synchronization and VPC Endpoint.

{{% notice warning %}}
**Deployment Mode Cannot Be Changed**

Once deployed, changing deployment modes requires destroying and recreating the infrastructure. Choose carefully based on your deployment architecture requirements.
{{% /notice %}}

### Step 5: Configure Component Flags

#### Management VPC

![Build Management VPC](../build-management-vpc.png)

```hcl
enable_build_management_vpc = true
```

#### Spoke VPCs and Transit Gateway

![Build Existing Subnets](../build-existing-subnets.png)

```hcl
enable_build_existing_subnets = true
```

### Step 6: Configure Optional Components

#### FortiManager and FortiAnalyzer

![FortiManager and FortiAnalyzer Options](../faz-fmgr-options.png)

```hcl
enable_fortimanager  = true
fortimanager_instance_type = "m5.large"
fortimanager_os_version = "7.4.5"
fortimanager_host_ip = "10"  # .3.0.10 within management VPC CIDR

enable_fortianalyzer = true
fortianalyzer_instance_type = "m5.large"
fortianalyzer_os_version = "7.4.5"
fortianalyzer_host_ip = "11"  # .3.0.11 within management VPC CIDR
```

{{% notice info %}}
**Instance Sizing Recommendations**

For testing/lab environments:
- FortiManager: m5.large (minimum)
- FortiAnalyzer: m5.large (minimum)

For heavier workloads or production evaluation:
- FortiManager: m5.xlarge or m5.2xlarge
- FortiAnalyzer: m5.xlarge or larger (depends on log volume)
{{% /notice %}}

#### Management VPC Transit Gateway Attachment

![Management VPC TGW Attachment](../mgmt-attach-tgw.png)

```hcl
enable_mgmt_vpc_tgw_attachment = true
```

This allows jump box and management instances to reach spoke VPC Linux instances for testing.

#### Linux Traffic Generators

![Linux Instances](../linux-instances.png)

```hcl
enable_jump_box = true
jump_box_instance_type = "t3.micro"

enable_east_linux_instances = true
east_linux_instance_type = "t3.micro"

enable_west_linux_instances = true
west_linux_instance_type = "t3.micro"
```

#### Debug TGW Attachment

```hcl
enable_debug_tgw_attachment = true
```

Enables bypass path for connectivity testing without FortiGate inspection.

### Step 7: Configure Network CIDRs

![Management and Spoke CIDRs](../mgmt-spoke-cidrs.png)

```hcl
vpc_cidr_management = "10.3.0.0/16"
vpc_cidr_east       = "192.168.0.0/24"
vpc_cidr_west       = "192.168.1.0/24"
vpc_cidr_spoke      = "192.168.0.0/16"  # Supernet for all spoke VPCs
```

{{% notice warning %}}
**CIDR Planning**

Ensure CIDRs:
- Don't overlap with existing networks
- Match between `existing_vpc_resources` and either `autoscale_template` or `ha_pair`
- Have sufficient address space for growth
- Align with corporate IP addressing standards
{{% /notice %}}

### Step 8: Configure Security Variables

```hcl
keypair = "my-aws-keypair"  # Must exist in target region
my_ip   = "203.0.113.10/32" # Your public IP for SSH access
```

{{% notice tip %}}
**Security Group Source IP**

The `my_ip` variable restricts SSH and HTTPS access to management interfaces.

For dynamic IPs, consider:
- Using a CIDR range: `"203.0.113.0/24"`
- VPN endpoint IP if accessing via corporate VPN
- Multiple IPs: Configure directly in security groups after deployment
{{% /notice %}}

### Step 9: Deploy the Template

Initialize Terraform:
```bash
terraform init
```

Review the execution plan:
```bash
terraform plan
```

Expected output will show resources to be created based on enabled flags.

Deploy the infrastructure:
```bash
terraform apply
```

Type `yes` when prompted to confirm.

**Expected deployment time**: 10-15 minutes

**Deployment progress**:
```
Apply complete! Resources: 47 added, 0 changed, 0 destroyed.

Outputs:

deployment_mode = "autoscale"  # or "ha_pair" based on selection
east_linux_instance_ip = "192.168.0.50"
fortianalyzer_public_ip = "52.10.20.30"
fortimanager_public_ip = "52.10.20.40"
jump_box_public_ip = "52.10.20.50"
management_vpc_id = "vpc-0123456789abcdef0"
tgw_id = "tgw-0123456789abcdef0"
tgw_name = "acme-test-tgw"
west_linux_instance_ip = "192.168.1.50"
```

### Step 10: Verify Deployment

#### Verify Management VPC

```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=acme-test-management-vpc"
```

Expected: VPC ID and CIDR information

#### Access FortiManager (if enabled)

```bash
# Get public IP from outputs
terraform output fortimanager_public_ip

# Access GUI
open https://<FortiManager-Public-IP>

# Or SSH
ssh admin@<FortiManager-Public-IP>
# Default password: <instance-id>
```

**First-time FortiManager setup**:
1. Login with admin / instance-id
2. Change password when prompted
3. Complete initial setup wizard
4. Navigate to Device Manager > Device & Groups

**Enable VM device recognition** (FortiManager 7.6.3+):
```
config system global
    set fgfm-allow-vm enable
end
```

#### Access FortiAnalyzer (if enabled)

```bash
# Get public IP from outputs
terraform output fortianalyzer_public_ip

# Access GUI
open https://<FortiAnalyzer-Public-IP>

# Or SSH
ssh admin@<FortiAnalyzer-Public-IP>
```

#### Verify Transit Gateway (if enabled)

```bash
aws ec2 describe-transit-gateways --filters "Name=tag:Name,Values=acme-test-tgw"
```

Expected: Transit Gateway in "available" state

#### Test Linux Instances (if enabled)

```bash
# Get instance IPs from outputs
terraform output east_linux_instance_ip
terraform output west_linux_instance_ip

# Test HTTP connectivity (if jump box enabled)
ssh -i ~/.ssh/keypair.pem ec2-user@<jump-box-ip>
curl http://<east-linux-ip>
# Expected: "Hello from ip-192-168-0-50"
```

### Step 11: Save Outputs for Next Template

Save key outputs for use in your chosen deployment template:

**For AutoScale Deployment:**
```bash
# Save all outputs
terraform output > ../outputs.txt

# Or save specific values
echo "tgw_name: $(terraform output -raw tgw_name)" >> ../autoscale_template/terraform.tfvars
echo "fortimanager_ip: $(terraform output -raw fortimanager_private_ip)" >> ../autoscale_template/terraform.tfvars
```

**For HA Pair Deployment:**
```bash
# Save all outputs
terraform output > ../outputs.txt

# Or save specific values for ha_pair template
echo "tgw_name: $(terraform output -raw tgw_name)" >> ../ha_pair/terraform.tfvars
echo "fortimanager_ip: $(terraform output -raw fortimanager_private_ip)" >> ../ha_pair/terraform.tfvars
```

---

## Outputs Reference

The template provides these outputs for use by your chosen deployment template:

| Output | Description | Used By autoscale_template/ha_pair |
|--------|-------------|-------------------------------------|
| `deployment_mode` | Selected deployment mode (autoscale/ha_pair) | Verification |
| `management_vpc_id` | ID of management VPC | VPC peering or TGW routing |
| `management_vpc_cidr` | CIDR of management VPC | Route table configuration |
| `tgw_id` | Transit Gateway ID | TGW attachment |
| `tgw_name` | Transit Gateway name tag | `attach_to_tgw_name` variable |
| `fortimanager_private_ip` | FortiManager private IP | `fortimanager_ip` variable |
| `fortimanager_public_ip` | FortiManager public IP | GUI/SSH access |
| `fortianalyzer_private_ip` | FortiAnalyzer private IP | FortiGate syslog configuration |
| `fortianalyzer_public_ip` | FortiAnalyzer public IP | GUI/SSH access |
| `jump_box_public_ip` | Jump box public IP | SSH bastion access |
| `east_linux_instance_ip` | East spoke instance IP | Connectivity testing |
| `west_linux_instance_ip` | West spoke instance IP | Connectivity testing |

---
