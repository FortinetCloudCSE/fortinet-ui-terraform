---
title: "Licensing Options"
chapter: false
menuTitle: "Licensing Options"
weight: 44
---

## Overview

The FortiGate autoscale solution supports three distinct licensing models, each optimized for different use cases, cost structures, and operational requirements. You can use a single licensing model or combine them in hybrid configurations for optimal cost efficiency.

---

## Licensing Model Comparison

| Factor | BYOL | FortiFlex | PAYG |
|--------|------|-----------|------|
| **Total Cost (12 months)** | Lowest | Medium | Highest |
| **Upfront Investment** | High | Medium | None |
| **License Management** | Manual (files) | API-driven | None |
| **Flexibility** | Low | High | Highest |
| **Capacity Constraints** | Yes (license pool) | Soft (point balance) | None |
| **Best For** | Long-term, predictable | Variable, flexible | Short-term, simple |
| **Setup Complexity** | Medium | High | Lowest |

---

## Option 1: BYOL (Bring Your Own License)

### Overview

BYOL uses traditional FortiGate-VM license files that you purchase from Fortinet or resellers. The template automates license distribution through S3 bucket storage and Lambda-based assignment.

![License Directory Structure](../license-directory.png)

### Configuration
```hcl
asg_license_directory = "asg_license"
asg_byol_asg_min_size = 2
asg_byol_asg_max_size = 4
```

### Directory Structure Requirements

Place BYOL license files in the directory specified by `asg_license_directory`:

```
terraform/autoscale_template/
├── terraform.tfvars
├── asg_license/
│   ├── FGVM01-001.lic
│   ├── FGVM01-002.lic
│   ├── FGVM01-003.lic
│   └── FGVM01-004.lic
```

### Automated License Assignment

1. Terraform uploads `.lic` files to S3 during `terraform apply`
2. Lambda retrieves available licenses when instances launch
3. DynamoDB tracks assignments to prevent duplicates
4. Lambda injects license via user-data script
5. Licenses return to pool when instances terminate

### Critical Capacity Planning

{{% notice warning %}}
**License Pool Exhaustion**

Ensure your license directory contains **at minimum** licenses equal to `asg_byol_asg_max_size`.

**What happens if licenses are exhausted**:
- New BYOL instances launch but remain unlicensed
- Unlicensed instances operate at 1 Mbps throughput
- FortiGuard services will not activate
- If PAYG ASG is configured, scaling continues using on-demand instances

**Recommended**: Provision 20% more licenses than `max_size`
{{% /notice %}}

### Characteristics
- ✅ **Lowest total cost**: Best value for long-term (12+ months)
- ✅ **Predictable costs**: Fixed licensing regardless of usage
- ⚠️ **License management**: Requires managing physical files
- ⚠️ **Upfront investment**: Must purchase licenses in advance

### When to Use
- Long-term production (12+ months)
- Predictable, steady-state workloads
- Existing FortiGate BYOL licenses
- Cost-conscious deployments

---

## Option 2: FortiFlex (Usage-Based Licensing)

### Overview

FortiFlex provides consumption-based, API-driven licensing. Points are consumed daily based on configuration, offering flexibility and cost optimization compared to PAYG.

### Prerequisites

1. Register FortiFlex Program via FortiCare
2. Purchase Point Packs
3. Create Configurations in FortiFlex portal
4. Generate API Credentials via IAM

For detailed setup, see [Licensing Section](../../3_licensing/).

### Configuration

```hcl
fortiflex_username      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
fortiflex_password      = "xxxxxxxxxxxxxxxxxxxxx"
fortiflex_sn_list       = ["FGVMELTMxxxxxxxx"]
fortiflex_configid_list = ["My_4CPU_Config"]
```

{{% notice warning %}}
**FortiFlex Serial Number List - Optional**

- **If defined**: Use entitlements from specific programs only
- **If omitted**: Use any available entitlements with matching configurations

**Important**: Entitlements must be created manually in FortiFlex portal before deployment.
{{% /notice %}}

### Obtaining Required Values

**1. API Username and Password**:
- Navigate to **Services > IAM** in FortiCare
- Create permission profile with FortiFlex Read/Write access
- Create API user and download credentials
- Username is UUID in credentials file

**2. Serial Number List**:
- Navigate to **Services > Assets & Accounts > FortiFlex**
- View your FortiFlex programs
- Note serial numbers from program details

**3. Configuration ID List**:
- In FortiFlex portal, go to **Configurations**
- Configuration ID is the **Name** field you assigned

**Match CPU counts**:
```hcl
fgt_instance_type = "c6i.xlarge"  # 4 vCPUs
fortiflex_configid_list = ["My_4CPU_Config"]  # Must match
```

{{% notice warning %}}
**Security Best Practice**

Never commit FortiFlex credentials to version control. Use:
- Terraform Cloud sensitive variables
- AWS Secrets Manager
- Environment variables: `TF_VAR_fortiflex_username`
- HashiCorp Vault
{{% /notice %}}

### Lambda Integration Behavior

**At instance launch**:
1. Lambda authenticates to FortiFlex API
2. Creates new entitlement under specified configuration
3. Receives and injects license token
4. Instance activates, point consumption begins

**At instance termination**:
1. Lambda calls API to STOP entitlement
2. Point consumption halts immediately
3. Entitlement preserved for reactivation

### Troubleshooting

**Problem**: Instances don't activate license
- Check Lambda CloudWatch logs for API errors
- Verify FortiFlex portal for failed entitlements
- Confirm network connectivity to FortiFlex API

**Problem**: "Insufficient points" error
- Check point balance in FortiFlex portal
- Purchase additional point packs
- Verify configurations use expected CPU counts

### Characteristics
- ✅ **Flexible consumption**: Pay only for what you use
- ✅ **No license file management**: API-driven automation
- ✅ **Lower cost than PAYG**: Typically 20-40% less
- ⚠️ **Point-based**: Requires monitoring consumption
- ⚠️ **API credentials**: Additional security considerations

### When to Use
- Variable workloads with unpredictable scaling
- Development and testing
- Short to medium-term (3-12 months)
- Burst capacity in hybrid architectures

---

## Option 3: PAYG (Pay-As-You-Go)

### Overview

PAYG uses AWS Marketplace on-demand instances with licensing included in hourly EC2 charge.

### Configuration
```hcl
asg_ondemand_asg_min_size = 0
asg_ondemand_asg_max_size = 4
asg_ondemand_asg_desired_size = 0
```

### How It Works

1. Accept FortiGate-VM AWS Marketplace terms
2. Lambda launches instances using Marketplace AMI
3. FortiGate activates automatically via AWS
4. Hourly licensing cost added to EC2 charge

### Characteristics
- ✅ **Simplest option**: Zero license management
- ✅ **No upfront commitment**: Pay per running hour
- ✅ **Instant availability**: No license pool constraints
- ⚠️ **Highest hourly cost**: Premium pricing for convenience

### When to Use
- Proof-of-concept and evaluation
- Very short-term (< 3 months)
- Burst capacity in hybrid architectures
- Zero license administration requirement

---

## Cost Comparison Example

**Scenario**: 2 FortiGate-VM instances (c6i.xlarge, 4 vCPU, UTP) running 24/7

| Duration | BYOL | FortiFlex | PAYG | Winner |
|----------|------|-----------|------|--------|
| 1 month | $2,730 | $1,030 | $1,460 | FortiFlex |
| 3 months | $4,190 | $3,090 | $4,380 | FortiFlex |
| 12 months | $10,760 | $12,360 | $17,520 | BYOL |
| 24 months | $19,520 | $24,720 | $35,040 | BYOL |

*Note: Illustrative costs. Actual pricing varies by term and bundle.*

---

## Hybrid Licensing Strategies

### Strategy 1: BYOL Baseline + PAYG Burst (Recommended)

```hcl
# BYOL for baseline
asg_license_directory = "asg_license"
asg_byol_asg_min_size = 2
asg_byol_asg_max_size = 4

# PAYG for burst
asg_ondemand_asg_max_size = 4
```

**Best for**: Production with occasional spikes

### Strategy 2: FortiFlex Baseline + PAYG Burst

```hcl
# FortiFlex for flexible baseline
fortiflex_configid_list = ["My_4CPU_Config"]
asg_byol_asg_max_size = 4

# PAYG for burst
asg_ondemand_asg_max_size = 4
```

**Best for**: Variable workloads with unpredictable spikes

### Strategy 3: All BYOL (Cost-Optimized)

```hcl
asg_license_directory = "asg_license"
asg_byol_asg_min_size = 2
asg_byol_asg_max_size = 6
asg_ondemand_asg_max_size = 0
```

**Best for**: Stable, predictable workloads

### Strategy 4: All PAYG (Simplest)

```hcl
asg_byol_asg_max_size = 0
asg_ondemand_asg_min_size = 2
asg_ondemand_asg_max_size = 8
```

**Best for**: POC, short-term, extreme variability

---

## Decision Tree

```
1. Expected deployment duration?
   ├─ < 3 months → PAYG
   ├─ 3-12 months → FortiFlex or evaluate costs
   └─ > 12 months → BYOL + PAYG burst

2. Workload predictable?
   ├─ Yes, stable → BYOL
   └─ No, variable → FortiFlex or Hybrid

3. Want to manage license files?
   ├─ No → FortiFlex or PAYG
   └─ Yes, for cost savings → BYOL

4. Tolerance for complexity?
   ├─ Low → PAYG
   ├─ Medium → FortiFlex
   └─ High (cost focus) → BYOL
```

---

## Best Practices

1. **Calculate TCO**: Use comparison matrix for your scenario
2. **Start simple**: Begin with PAYG for POC, optimize for production
3. **Monitor costs**: Track consumption via CloudWatch and FortiFlex reports
4. **Provision buffer**: 20% more licenses/entitlements than max_size
5. **Secure credentials**: Never commit FortiFlex credentials to git
6. **Test assignment**: Verify Lambda logs show successful injection
7. **Plan exhaustion**: Configure PAYG burst as safety net
8. **Document strategy**: Ensure ops team understands hybrid configs

---

## Next Steps

After configuring licensing, proceed to [FortiManager Integration](../4_5_fortimanager_integration/) for centralized management.
