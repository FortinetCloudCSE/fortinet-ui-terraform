---
title: "Configuring ha_pair"
menuTitle: "ha_pair"
weight: 3
---

## Overview

This guide walks you through configuring the `ha_pair` template using the Web UI. This template deploys a FortiGate Active-Passive HA pair using FGCP (FortiGate Clustering Protocol).

{{% notice warning %}}
**Prerequisites:**
1. Deploy [existing_vpc_resources](../2_1_existing_vpc_resources/) first with **HA Pair Deployment mode enabled**
2. Record the `cp`, `env`, and `tgw_name` values from existing_vpc_resources outputs
{{% /notice %}}

---

## Step 1: Select Template

1. Open the UI at http://localhost:3000
2. In the **Template** dropdown at the top, select **ha_pair**
3. The form will load with inherited values from existing_vpc_resources

{{%/* notice note */%}}
**TODO: Add diagram - template-dropdown-ha**

Show dropdown with "ha_pair" selected
{{%/* /notice */%}}

{{% notice info %}}
**Configuration Inheritance**

The UI automatically inherits `cp`, `env`, `aws_region`, and other base settings from existing_vpc_resources. These fields will be pre-filled and shown as "Inherited from existing_vpc_resources".
{{% /notice %}}

---

## Step 2: Verify Inherited Values

Review the inherited values (shown with gray background):

- **Customer Prefix (cp)** - Should match existing_vpc_resources
- **Environment (env)** - Should match existing_vpc_resources
- **AWS Region** - Should match existing_vpc_resources
- **Availability Zones** - Should match existing_vpc_resources

{{% notice warning %}}
**Do Not Change Inherited Values**

These values must match existing_vpc_resources for proper resource discovery. If they're incorrect, fix them in existing_vpc_resources first.
{{% /notice %}}

{{%/* notice note */%}}
**TODO: Add diagram - inherited-fields-ha**

Show form fields with gray background indicating inherited values:
- cp: "acme" (inherited)
- env: "test" (inherited)
- aws_region: "us-west-2" (inherited)
- availability_zone_1: "a" (inherited)
- availability_zone_2: "c" (inherited)
{{%/* /notice */%}}

---

## Step 3: FortiGate Configuration

### Instance Type

1. Select **FortiGate Instance Type** from dropdown:
   - c5n.xlarge - 4 vCPU / 10.5GB RAM (minimum)
   - c5n.2xlarge - 8 vCPU / 21GB RAM
   - c5n.4xlarge - 16 vCPU / 42GB RAM
   - c5n.9xlarge - 36 vCPU / 96GB RAM

{{% notice tip %}}
**HA Pair Sizing**

For HA pairs, both instances are always running. Size for peak load, not average load.
{{% /notice %}}

### FortiOS Version

2. Enter **FortiOS Version** (e.g., `7.4.5` or `7.6`)

### Admin Password

3. Enter **FortiGate Admin Password**
   - Minimum 8 characters
   - Used to login to both FortiGate instances

{{%/* notice note */%}}
**TODO: Add diagram - fortigate-config-ha**

Show:
- Instance Type dropdown: "c5n.xlarge" selected
- FortiOS Version field: "7.4.5"
- Admin Password field: [password masked]
{{%/* /notice */%}}

---

## Step 4: HA Configuration

### HA Group Name

1. Enter **HA Group Name**
   - Cluster identifier
   - Example: `ha-cluster` or `acme-test-ha`

### HA Password

2. Enter **HA Password**
   - Minimum 8 characters
   - Secures heartbeat communication between FortiGates
   - Keep this secure - compromised HA password allows cluster takeover

{{%/* notice note */%}}
**TODO: Add diagram - ha-config**

Show:
- HA Group Name field: "ha-cluster"
- HA Password field: [password masked]
- Help text: "Used for secure heartbeat communication"
{{%/* /notice */%}}

{{% notice warning %}}
**HA Password Security**

The HA password protects cluster communication. Use a strong password different from the admin password.
{{% /notice %}}

---

## Step 5: Licensing Configuration

Choose ONE licensing mode:

### PAYG (Pay-As-You-Go)

1. Select **License Type**: `payg`
2. No additional fields required
3. AWS Marketplace billing applies to both instances

### BYOL (Bring Your Own License)

1. Select **License Type**: `byol`
2. Enter **Primary License File Path**
   - Example: `./licenses/primary.lic`
3. Enter **Secondary License File Path**
   - Example: `./licenses/secondary.lic`
4. Place license files in the specified paths

### FortiFlex

1. Select **License Type**: `fortiflex`
2. Enter **FortiFlex Token**
3. Both instances retrieve licenses using the same token

{{%/* notice note */%}}
**TODO: Add diagram - licensing-ha**

Show:
- License Type dropdown with three options: payg, byol, fortiflex
- Primary License File field (visible when byol selected)
- Secondary License File field (visible when byol selected)
- FortiFlex Token field (visible when fortiflex selected)
{{%/* /notice */%}}

---

## Step 6: Transit Gateway Integration (Optional)

If you enabled Transit Gateway in existing_vpc_resources:

### Enable TGW Attachment

1. Check **Enable Transit Gateway Attachment**
2. Enter **Transit Gateway Name** from existing_vpc_resources outputs
   - Example: `acme-test-tgw`
   - Find with: `terraform output tgw_name`

### Update TGW Routes

3. Check **Update TGW Routes** (recommended)
   - Automatically updates spoke VPC route tables
   - Points default routes to inspection VPC
   - Enables traffic inspection through HA pair

{{%/* notice note */%}}
**TODO: Add diagram - tgw-integration-ha**

Show:
- Enable Transit Gateway Attachment checkbox [✓]
- Transit Gateway Name field: "acme-test-tgw"
- Update TGW Routes checkbox [✓]
- Help text explaining route updates
{{%/* /notice */%}}

{{% notice info %}}
**Automatic Route Updates**

When enabled, the template:
- Deletes old default routes pointing to management VPC
- Creates new default routes pointing to inspection VPC
- Traffic flows: Spoke VPC → TGW → Primary FortiGate → Internet
{{% /notice %}}

---

## Step 7: Internet Access Mode

Choose how FortiGates access the internet:

### EIP Mode (Default)

1. Select **Access Internet Mode**: `eip`
2. Each FortiGate gets Elastic IPs on port1
3. Cluster EIP moves to active instance on failover

### NAT Gateway Mode

1. Select **Access Internet Mode**: `nat_gw`
2. Centralized egress through NAT Gateways
3. Requires NAT Gateways in inspection VPC
4. More predictable source IPs

{{%/* notice note */%}}
**TODO: Add diagram - internet-access-ha**

Show dropdown with options:
- eip - Elastic IP per instance
- nat_gw - NAT Gateway (centralized)
{{%/* /notice */%}}

---

## Step 8: Management Configuration

### Management EIP

1. Check **Enable Management EIP** to assign public IPs to management interfaces
   - Allows direct internet access to FortiGate management
   - Uncheck if accessing via management VPC or VPN

{{%/* notice note */%}}
**TODO: Add diagram - management-eip**

Show:
- Enable Management EIP checkbox
- Help text: "Public IP for port3 (or port4) management access"
{{%/* /notice */%}}

{{% notice tip %}}
**Management Access Considerations**

- **With EIP**: Direct HTTPS/SSH access from internet (requires `management_cidr` security group)
- **Without EIP**: Access via jump box in management VPC or VPN connection
{{% /notice %}}

---

## Step 9: FortiManager Integration (Optional)

If you deployed FortiManager in existing_vpc_resources:

1. Check **Enable FortiManager**
2. Enter **FortiManager IP** from existing_vpc_resources outputs
   - Example: `10.3.0.10`
   - Find with: `terraform output fortimanager_private_ip`

{{%/* notice note */%}}
**TODO: Add diagram - fortimanager-integration-ha**

Show:
- Enable FortiManager checkbox [✓]
- FortiManager IP field: "10.3.0.10"
{{%/* /notice */%}}

{{% notice info %}}
**HA Pair and FortiManager**

Both FortiGates register with FortiManager independently. After deployment:
1. Login to FortiManager
2. Device Manager > Device & Groups
3. Right-click each FortiGate > Authorize
4. FortiManager will recognize HA pair relationship
{{% /notice %}}

---

## Step 10: FortiAnalyzer Integration (Optional)

If you deployed FortiAnalyzer in existing_vpc_resources:

1. Check **Enable FortiAnalyzer**
2. Enter **FortiAnalyzer IP** from existing_vpc_resources outputs
   - Example: `10.3.0.11`
   - Find with: `terraform output fortianalyzer_private_ip`

{{%/* notice note */%}}
**TODO: Add diagram - fortianalyzer-integration-ha**

Show:
- Enable FortiAnalyzer checkbox [✓]
- FortiAnalyzer IP field: "10.3.0.11"
{{%/* /notice */%}}

---

## Step 11: Security Configuration

### EC2 Key Pair

1. Select **Key Pair** from dropdown (should match existing_vpc_resources)

### Management CIDR

2. **Management CIDR** list is inherited from existing_vpc_resources
   - Shows list of allowed IP ranges for SSH/HTTPS access
   - Controls access to management interfaces
   - Cannot be modified here (inherited)

{{%/* notice note */%}}
**TODO: Add diagram - security-config-ha**

Show:
- Key Pair dropdown: "my-keypair" (inherited)
- Management CIDR list field: ["203.0.113.10/32"] (inherited, read-only)
{{%/* /notice */%}}

---

## Step 12: Save Configuration

1. Click the **Save Configuration** button
2. Confirmation: "Configuration saved successfully!"

{{%/* notice note */%}}
**TODO: Add diagram - save-ha**

Show Save Configuration button with success message
{{%/* /notice */%}}

---

## Step 13: Generate terraform.tfvars

1. Click **Generate terraform.tfvars**
2. Review the generated configuration in preview window
3. Verify all settings are correct

{{%/* notice note */%}}
**TODO: Add diagram - generated-preview-ha**

Show preview window with generated terraform.tfvars content
{{%/* /notice */%}}

---

## Step 14: Download or Save to Template

### Option A: Download

1. Click **Download**
2. File saves as `ha_pair.tfvars`
3. Copy to terraform directory:
   ```bash
   cp ~/Downloads/ha_pair.tfvars \
     terraform/ha_pair/terraform.tfvars
   ```

### Option B: Save Directly

1. Click **Save to Template**
2. Confirmation: "terraform.tfvars saved to: terraform/ha_pair/terraform.tfvars"

---

## Step 15: Deploy with Terraform

```bash
cd terraform/ha_pair

# Initialize Terraform
terraform init

# Review execution plan
terraform plan

# Deploy infrastructure
terraform apply
```

Type `yes` when prompted.

**Expected deployment time:** 15-20 minutes

---

## Step 16: Verify HA Status

After deployment completes:

### Access Primary FortiGate

```bash
# Get management IPs from outputs
terraform output fortigate_primary_management_url

# SSH to primary
ssh admin@<primary-management-ip>
```

### Check HA Status

```bash
# On FortiGate CLI
get system ha status

# Expected output:
# HA Health Status: OK
# Mode: HA A-P
# Group: ha-cluster
# Priority: 255 (primary)
# State: Primary
# Slave:
#   Serial: <secondary-serial>
#   Priority: 1
#   State: Standby
```

{{%/* notice note */%}}
**TODO: Add diagram - ha-status-output**

Show example output of 'get system ha status' command
{{%/* /notice */%}}

---

## Common Configuration Patterns

### Pattern 1: Simple HA Pair with TGW

```
License Type: payg
✓ Enable Transit Gateway Attachment
✓ Update TGW Routes
✓ Enable Management EIP
✗ Enable FortiManager
Access Internet Mode: eip
```

**Use case:** Basic HA pair with centralized inspection via TGW

---

### Pattern 2: HA Pair with Centralized Management

```
License Type: byol
✓ Enable Transit Gateway Attachment
✓ Update TGW Routes
✗ Enable Management EIP (access via management VPC)
✓ Enable FortiManager
✓ Enable FortiAnalyzer
Access Internet Mode: eip
```

**Use case:** Production-like HA pair with FortiManager/FortiAnalyzer integration

---

### Pattern 3: HA Pair with NAT Gateway

```
License Type: payg
✓ Enable Transit Gateway Attachment
✓ Update TGW Routes
✓ Enable Management EIP
✗ Enable FortiManager
Access Internet Mode: nat_gw
```

**Use case:** HA pair with predictable egress IPs through NAT Gateway

---

## Validation and Errors

The UI validates:

- FortiGate admin password minimum length (8 characters)
- HA password minimum length (8 characters)
- HA group name format
- FortiManager IP format
- Transit Gateway name format
- License file paths (for BYOL)
- All required fields filled

{{%/* notice note */%}}
**TODO: Add diagram - validation-errors-ha**

Show form with validation errors highlighted
{{%/* /notice */%}}

---

## Testing Failover

After successful deployment, test HA failover:

### Manual Failover Test

1. SSH to primary FortiGate
2. Trigger failover:
   ```bash
   execute ha manage 1 admin
   ```
3. Secondary becomes active
4. Verify:
   - Cluster EIP moves to secondary
   - Route tables update to secondary ENIs
   - Traffic continues flowing
   - Sessions maintained (stateful failover)

**Failover time:** Typically 30-60 seconds

{{%/* notice note */%}}
**TODO: Add diagram - failover-test**

Show:
- Command to trigger failover
- Expected HA status after failover
- Diagram showing EIP movement
{{%/* /notice */%}}

---

## Troubleshooting

### HA Pair Not Forming

**Symptoms:** FortiGates don't see each other

**Check:**
- HA sync subnets were created by existing_vpc_resources
- Security groups allow all traffic between HA sync IPs
- HA password matches on both instances
- Verify connectivity: `execute ping <peer-port3-ip>`

---

### AWS API Calls Failing

**Symptoms:** Failover doesn't update EIPs or routes

**Check:**
- VPC endpoint exists in HA sync subnets
- IAM role has required permissions (AssociateAddress, ReplaceRoute)
- Private DNS enabled on VPC endpoint
- Test: `diag test app awsd 4`

---

### Session Synchronization Not Working

**Symptoms:** Active sessions drop during failover

**Check:**
```bash
# Verify session pickup enabled
show system ha | grep session-pickup

# Enable if needed
config system ha
    set session-pickup enable
    set session-pickup-connectionless enable
end
```

---

### TGW Routes Not Updating

**Symptoms:** Spoke VPC traffic not reaching FortiGates

**Check:**
- `update_tgw_routes` is enabled in configuration
- TGW route tables show inspection VPC attachment
- Run: `terraform apply` to update routes manually

---

## Next Steps

After deploying ha_pair:

1. **Configure firewall policies**:
   - Login to primary FortiGate
   - Policy & Objects > Firewall Policy
   - Create policies for your traffic flows

2. **Test connectivity**:
   - From spoke VPC instances, test internet access
   - Verify traffic appears in FortiGate logs
   - Test east-west traffic between spoke VPCs

3. **Test failover**:
   - Trigger manual failover
   - Verify EIP and route updates
   - Check session synchronization

4. **Monitor HA status**:
   - Check HA health regularly: `get system ha status`
   - Monitor CloudWatch logs
   - Review FortiGate system events
