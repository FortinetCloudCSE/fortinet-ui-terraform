---
title: "Deployment Guide"
menuTitle: "Deployment"
weight: 2
---

## Deployment Workflow

### Step 1: Deploy existing_vpc_resources

```bash
cd terraform/existing_vpc_resources

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars

# IMPORTANT: Set deployment mode to HA Pair
# edit terraform.tfvars:
enable_autoscale_deployment = false
enable_ha_pair_deployment = true

# Deploy
terraform init
terraform plan
terraform apply

# Save outputs
terraform output
```

**Key Outputs to Note:**
- `ha_sync_subnet_az1_id` - HA sync subnet in AZ1
- `ha_sync_subnet_az2_id` - HA sync subnet in AZ2
- `attach_to_tgw_name` - Transit Gateway name
- `fortimanager_private_ip` - FortiManager IP (if enabled)
- `fortianalyzer_private_ip` - FortiAnalyzer IP (if enabled)

---

### Step 2: Configure ha_pair Template

```bash
cd terraform/ha_pair

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
# REQUIRED: Match these values with existing_vpc_resources
aws_region          = "us-west-2"  # MUST MATCH
availability_zone_1 = "a"          # MUST MATCH
availability_zone_2 = "c"          # MUST MATCH
cp                  = "acme"       # MUST MATCH
env                 = "test"       # MUST MATCH

# Configure FortiGate
keypair                   = "my-keypair"
fortigate_admin_password  = "SecureP@ssw0rd!"
ha_password               = "HASecretPass!"
ha_group_name             = "ha-cluster"

# Choose licensing mode
license_type = "payg"  # or "byol" or "fortiflex"

# Optional: FortiManager integration
enable_fortimanager = true
fortimanager_ip     = "10.3.0.10"  # From existing_vpc_resources output

# Optional: Management EIP
enable_management_eip = true
```

---

### Step 3: Deploy HA Pair

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy
terraform apply

# Save outputs
terraform output > ha_pair_outputs.txt
```

**Deployment Time:** ~15-20 minutes

---

### Step 4: Verify Deployment

#### Access FortiGate Management

Primary FortiGate:
```bash
# Get management URL from outputs
terraform output fortigate_primary_management_url

# Access via browser
# Username: admin
# Password: <fortigate_admin_password>
```

Secondary FortiGate:
```bash
terraform output fortigate_secondary_management_url
```

#### Verify HA Status

SSH to primary FortiGate:
```bash
ssh admin@<primary-management-ip>

# Check HA status
get system ha status

# Expected output:
# HA Health Status: OK
# Model: FortiGate-VM64-AWS
# Mode: HA A-P
# Group: <ha_group_name>
# Priority: 255  (primary)
# Override: Disabled
# State: Primary
# Slave:
#   Serial: <secondary-serial>
#   Priority: 1
#   State: Standby
```

#### Test AWS API Access

```bash
# On FortiGate CLI
diag test app awsd 4

# Should show successful AWS API connectivity
```

#### Verify Transit Gateway Routing

```bash
# Check TGW route tables
aws ec2 describe-transit-gateway-route-tables \
  --filters "Name=tag:Name,Values=*east*" \
  --query 'TransitGatewayRouteTables[*].TransitGatewayRouteTableId' \
  --output text | \
  xargs -I {} aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id {} \
  --filters "Name=type,Values=static"

# Verify default route (0.0.0.0/0) points to inspection VPC attachment
```

---
