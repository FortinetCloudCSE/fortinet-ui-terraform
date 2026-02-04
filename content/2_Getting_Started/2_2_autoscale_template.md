---
title: "Configuring autoscale_template"
menuTitle: "autoscale_template"
weight: 2
---

## Overview

This guide walks you through configuring the `autoscale_template` using the Web UI. This template deploys FortiGate autoscale groups with Gateway Load Balancer for elastic scaling.

{{% notice warning %}}
**Prerequisites:**
1. Deploy [existing_vpc_resources](../2_1_existing_vpc_resources/) first with **AutoScale Deployment mode enabled**
2. Record the `cp`, `env`, and `tgw_name` values from existing_vpc_resources outputs
{{% /notice %}}

---

## Step 1: Select Template

1. Open the UI at http://localhost:3000
2. In the **Template** dropdown at the top, select **autoscale_template**
3. The form will load with inherited values from existing_vpc_resources

{{%/* notice note */%}}
**TODO: Add diagram - template-dropdown-autoscale**

Show dropdown with "autoscale_template" selected
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
**TODO: Add diagram - inherited-fields**

Show form fields with gray background indicating inherited values:
- cp: "acme" (inherited)
- env: "test" (inherited)
- aws_region: "us-west-2" (inherited)
- Note explaining these are read-only
{{%/* /notice */%}}

---

## Step 3: Firewall Policy Mode

Choose how FortiGate processes traffic:

### 1-Arm Mode (Hairpin)
- Traffic enters and exits same interface
- Simplest configuration
- Single data plane interface

### 2-Arm Mode (Traditional)
- Separate untrusted and trusted interfaces
- Traditional firewall model
- Better performance for high throughput

**Select:** `1-arm` or `2-arm` from dropdown

{{%/* notice note */%}}
**TODO: Add diagram - firewall-policy-mode**

Show dropdown with options:
- 1-arm - Single interface (hairpin)
- 2-arm - Separate untrusted/trusted interfaces
{{%/* /notice */%}}

---

## Step 4: FortiGate Configuration

### Instance Type

1. Select **FortiGate Instance Type** from dropdown:
   - c5n.xlarge - 4 vCPU / 10.5GB RAM (minimum)
   - c5n.2xlarge - 8 vCPU / 21GB RAM
   - c5n.4xlarge - 16 vCPU / 42GB RAM
   - c5n.9xlarge - 36 vCPU / 96GB RAM

### FortiOS Version

2. Enter **FortiOS Version** (e.g., `7.4.5` or `7.6`)

### Admin Password

3. Enter **FortiGate Admin Password**
   - Minimum 8 characters
   - Used to login to FortiGate instances

{{%/* notice note */%}}
**TODO: Add diagram - fortigate-config**

Show:
- Instance Type dropdown: "c5n.xlarge" selected
- FortiOS Version field: "7.4.5"
- Admin Password field: [password masked]
{{%/* /notice */%}}

---

## Step 5: Autoscale Group Settings

### Desired Capacity

1. Enter **Desired Capacity** - Number of FortiGates to maintain (default: 2)

### Minimum Size

2. Enter **Minimum Size** - Minimum FortiGates in group (default: 2)

### Maximum Size

3. Enter **Maximum Size** - Maximum FortiGates in group (default: 6)

### Scale-In Protection

4. Check **Enable Scale-In Protection** to prevent automatic instance termination

{{%/* notice note */%}}
**TODO: Add diagram - autoscale-settings**

Show:
- Desired Capacity: 2
- Minimum Size: 2
- Maximum Size: 6
- Scale-In Protection checkbox
{{%/* /notice */%}}

{{% notice tip %}}
**Autoscaling Recommendations**

- Start with desired capacity = 2 for testing
- Set maximum based on expected peak load
- Enable scale-in protection during initial testing
{{% /notice %}}

---

## Step 6: Licensing Configuration

Choose ONE licensing mode:

### PAYG (Pay-As-You-Go)

1. Select **License Type**: `payg`
2. No additional fields required
3. AWS Marketplace billing applies

### BYOL (Bring Your Own License)

1. Select **License Type**: `byol`
2. Upload license files to `terraform/autoscale_template/asg_license/`:
   ```bash
   cp license1.lic terraform/autoscale_template/asg_license/
   cp license2.lic terraform/autoscale_template/asg_license/
   # Add as many licenses as your maximum ASG size
   ```
3. Lambda will apply licenses automatically on instance launch

### FortiFlex

1. Select **License Type**: `fortiflex`
2. Enter **FortiFlex Token**
3. Lambda retrieves licenses from FortiFlex automatically

{{%/* notice note */%}}
**TODO: Add diagram - licensing**

Show:
- License Type dropdown with three options: payg, byol, fortiflex
- FortiFlex Token field (visible when fortiflex selected)
- Help text explaining each licensing mode
{{%/* /notice */%}}

---

## Step 7: Transit Gateway Integration (Optional)

If you enabled Transit Gateway in existing_vpc_resources:

### Enable TGW Attachment

1. Check **Enable Transit Gateway Attachment**
2. Enter **Transit Gateway Name** from existing_vpc_resources outputs
   - Example: `acme-test-tgw`
   - Find with: `terraform output tgw_name`

{{%/* notice note */%}}
**TODO: Add diagram - tgw-integration**

Show:
- Enable TGW Attachment checkbox [✓]
- Transit Gateway Name field: "acme-test-tgw"
- Help text: "Use 'tgw_name' from existing_vpc_resources outputs"
{{%/* /notice */%}}

{{% notice info %}}
**TGW Routing**

When enabled, the template automatically:
- Creates TGW attachment for inspection VPC
- Updates spoke VPC route tables to point to inspection VPC
- Enables east-west and north-south traffic inspection
{{% /notice %}}

---

## Step 8: Distributed Inspection (Optional)

If you want GWLB endpoints in distributed spoke VPCs:

1. Check **Enable Distributed Inspection**
2. The template will discover VPCs tagged with your `cp` and `env` values
3. GWLB endpoints will be created in discovered VPCs

{{%/* notice note */%}}
**TODO: Add diagram - distributed-inspection**

Show:
- Enable Distributed Inspection checkbox
- Help text explaining bump-in-the-wire inspection
- Diagram: VPC → GWLBe → GWLB → GENEVE → FortiGate
{{%/* /notice */%}}

{{% notice info %}}
**Distributed vs Centralized**

- **Centralized** (TGW): Traffic flows through TGW to inspection VPC
- **Distributed**: GWLB endpoints placed directly in spoke VPCs
- Both can be enabled simultaneously
{{% /notice %}}

---

## Step 9: Internet Access Mode

Choose how FortiGates access the internet:

### EIP Mode (Default)

1. Select **Access Internet Mode**: `eip`
2. Each FortiGate gets an Elastic IP
3. Distributed egress from each instance

### NAT Gateway Mode

1. Select **Access Internet Mode**: `nat_gw`
2. Centralized egress through NAT Gateways
3. Requires NAT Gateways in inspection VPC

{{%/* notice note */%}}
**TODO: Add diagram - internet-access**

Show dropdown with options:
- eip - Elastic IP per instance (distributed egress)
- nat_gw - NAT Gateway (centralized egress)
{{%/* /notice */%}}

---

## Step 10: Management Configuration

Choose management access mode:

### Standard Management (Default)

- Management via data plane interfaces
- No additional ENIs required
- Simplest configuration

### Dedicated Management ENI

1. Check **Enable Dedicated Management ENI**
2. Converts port2 to dedicated management interface (instead of data plane)
3. Better security isolation

### Dedicated Management VPC

1. Check **Enable Dedicated Management VPC**
2. Management interfaces in separate management VPC
3. Requires existing_vpc_resources with management VPC enabled
4. Maximum security isolation

{{%/* notice note */%}}
**TODO: Add diagram - management-config**

Show:
- Enable Dedicated Management ENI checkbox
- Enable Dedicated Management VPC checkbox
- Help text explaining security isolation
{{%/* /notice */%}}

---

## Step 11: FortiManager Integration (Optional)

If you deployed FortiManager in existing_vpc_resources:

1. Check **Enable FortiManager**
2. Enter **FortiManager IP** from existing_vpc_resources outputs
   - Example: `10.3.0.10`
   - Find with: `terraform output fortimanager_private_ip`
3. Enter **FortiManager Serial Number**
   - Login to FortiManager CLI: `get system status`

{{%/* notice note */%}}
**TODO: Add diagram - fortimanager-integration**

Show:
- Enable FortiManager checkbox [✓]
- FortiManager IP field: "10.3.0.10"
- Serial Number field
- Help text: "Get from existing_vpc_resources outputs"
{{%/* /notice */%}}

{{% notice info %}}
**FortiManager Registration**

When enabled:
- FortiGate instances automatically register with FortiManager on launch
- Lambda handles authorization
- ADOM configuration optional
{{% /notice %}}

---

## Step 12: FortiAnalyzer Integration (Optional)

If you deployed FortiAnalyzer in existing_vpc_resources:

1. Check **Enable FortiAnalyzer**
2. Enter **FortiAnalyzer IP** from existing_vpc_resources outputs
   - Example: `10.3.0.11`
   - Find with: `terraform output fortianalyzer_private_ip`

{{%/* notice note */%}}
**TODO: Add diagram - fortianalyzer-integration**

Show:
- Enable FortiAnalyzer checkbox [✓]
- FortiAnalyzer IP field: "10.3.0.11"
{{%/* /notice */%}}

---

## Step 13: Security Configuration

### EC2 Key Pair

1. Select **Key Pair** from dropdown (should match existing_vpc_resources)

### Management CIDR

2. **Management CIDR** list is inherited from existing_vpc_resources
   - Shows list of allowed IP ranges for SSH/HTTPS access
   - Cannot be modified here (inherited)

{{%/* notice note */%}}
**TODO: Add diagram - security-config-autoscale**

Show:
- Key Pair dropdown: "my-keypair" (inherited)
- Management CIDR list field: ["203.0.113.10/32"] (inherited, read-only)
{{%/* /notice */%}}

---

## Step 14: Save Configuration

1. Click the **Save Configuration** button
2. Confirmation: "Configuration saved successfully!"

{{%/* notice note */%}}
**TODO: Add diagram - save-autoscale**

Show Save Configuration button with success message
{{%/* /notice */%}}

---

## Step 15: Generate terraform.tfvars

1. Click **Generate terraform.tfvars**
2. Review the generated configuration in preview window
3. Verify all settings are correct

{{%/* notice note */%}}
**TODO: Add diagram - generated-preview-autoscale**

Show preview window with generated terraform.tfvars content
{{%/* /notice */%}}

---

## Step 16: Download or Save to Template

### Option A: Download

1. Click **Download**
2. File saves as `autoscale_template.tfvars`
3. Copy to terraform directory:
   ```bash
   cp ~/Downloads/autoscale_template.tfvars \
     terraform/autoscale_template/terraform.tfvars
   ```

### Option B: Save Directly

1. Click **Save to Template**
2. Confirmation: "terraform.tfvars saved to: terraform/autoscale_template/terraform.tfvars"

---

## Step 17: Deploy with Terraform

```bash
cd terraform/autoscale_template

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

## Common Configuration Patterns

### Pattern 1: Simple Autoscale with TGW

```
Firewall Policy Mode: 1-arm
License Type: payg
✓ Enable Transit Gateway Attachment
✗ Enable Distributed Inspection
✗ Enable Dedicated Management ENI
✗ Enable FortiManager
Desired Capacity: 2
Minimum Size: 2
Maximum Size: 4
```

**Use case:** Basic autoscaling with centralized inspection via TGW

---

### Pattern 2: Distributed Inspection

```
Firewall Policy Mode: 2-arm
License Type: byol
✗ Enable Transit Gateway Attachment
✓ Enable Distributed Inspection
✗ Enable Dedicated Management ENI
✗ Enable FortiManager
Desired Capacity: 2
Minimum Size: 2
Maximum Size: 6
```

**Use case:** Bump-in-the-wire inspection in distributed spoke VPCs

---

### Pattern 3: Full Management with FortiManager

```
Firewall Policy Mode: 2-arm
License Type: payg
✓ Enable Transit Gateway Attachment
✗ Enable Distributed Inspection
✓ Enable Dedicated Management VPC
✓ Enable FortiManager
✓ Enable FortiAnalyzer
Desired Capacity: 2
Minimum Size: 2
Maximum Size: 6
```

**Use case:** Production-like environment with centralized management

---

## Validation and Errors

The UI validates:

- FortiGate admin password minimum length (8 characters)
- Autoscale group sizes (min ≤ desired ≤ max)
- FortiManager IP format
- Transit Gateway name format
- All required fields filled

{{%/* notice note */%}}
**TODO: Add diagram - validation-errors-autoscale**

Show form with validation errors highlighted
{{%/* /notice */%}}

---

## Next Steps

After deploying autoscale_template:

1. **Verify deployment**:
   ```bash
   terraform output
   ```

2. **Access FortiGate**:
   - Get load balancer DNS from outputs
   - GUI: `https://<load-balancer-dns>`
   - Username: `admin`
   - Password: `<fortigate_asg_password>`

3. **Test traffic flow**:
   - From spoke VPC instances, test internet connectivity
   - Verify traffic appears in FortiGate logs
   - Test east-west traffic between spoke VPCs

4. **Monitor autoscaling**:
   - Check CloudWatch metrics
   - Review Lambda logs
   - Monitor ASG activity

---

## Troubleshooting

### FortiGates Not Joining FortiManager

**Check:**
- FortiManager IP is correct
- FortiManager serial number is correct
- Security groups allow traffic between inspection VPC and management VPC
- FortiManager has `fgfm-allow-vm enable` set

---

### License Application Failed

**Check:**
- License files are in `asg_license/` directory
- Sufficient licenses for maximum ASG size
- FortiFlex token is valid (if using FortiFlex)
- Lambda logs for error messages

---

### No Traffic Flowing Through FortiGates

**Check:**
- TGW route tables point to inspection VPC attachment
- Security groups allow traffic on FortiGate interfaces
- FortiGate firewall policies exist and allow traffic
- Gateway Load Balancer health checks passing
