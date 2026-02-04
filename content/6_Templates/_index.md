---
title: "Template Reference"
chapter: true
menuTitle: "Templates"
weight: 60
---

# Terraform Template Reference

This section provides detailed documentation for advanced users who prefer working directly with Terraform configuration files instead of the Web UI.

{{% notice tip %}}
**Recommended: Use the Web UI**

For most deployments, the [Getting Started](../2_getting_started/) guide with the Web UI is faster and easier. The UI automatically handles variable coordination, validates inputs, and generates correct `terraform.tfvars` files.

Use this section if you:
- Prefer command-line workflows
- Need to automate deployments via CI/CD
- Want to understand the underlying Terraform structure
- Need to customize beyond what the UI supports
{{% /notice %}}

---

## Available Templates

### [Templates Overview](5_1_overview/)
Understand the template architecture, deployment patterns, and how templates work together.

### [existing_vpc_resources Template](5_2_existing_vpc_resources/) (Deploy First)
Create supporting infrastructure for lab and test environments including management VPC, Transit Gateway, spoke VPCs, and deployment mode configuration (AutoScale or HA Pair).

### [autoscale_template](5_3_autoscale_template/) (Choose One)
Deploy FortiGate AutoScale group with Gateway Load Balancer for elastic scaling and distributed traffic inspection.

### [ha_pair Template](5_4_ha_pair/) (Choose One)
Deploy FortiGate Active-Passive HA Pair with FGCP for fixed-capacity deployment with stateful failover.

### [Annotation Reference](5_5_annotations/)
Learn how to add UI support to any Terraform template using `terraform.tfvars.example` annotations.

---

## Manual Deployment Workflow

### Step 1: Clone Repository

```bash
git clone https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git
cd fortinet-ui-terraform
```

### Step 2: Configure existing_vpc_resources

```bash
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Step 3: Deploy Base Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### Step 4: Configure FortiGate Template

Choose **one** of:

**For AutoScale:**
```bash
cd ../autoscale_template
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - ensure cp and env match existing_vpc_resources
```

**For HA Pair:**
```bash
cd ../ha_pair
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars - ensure cp and env match existing_vpc_resources
```

### Step 5: Deploy FortiGate

```bash
terraform init
terraform plan
terraform apply
```

---

## Template Coordination

When using templates together, these variables **must match exactly**:

| Variable | Description |
|----------|-------------|
| `aws_region` | AWS region (e.g., `us-west-2`) |
| `availability_zone_1` | First AZ suffix (e.g., `a`) |
| `availability_zone_2` | Second AZ suffix (e.g., `c`) |
| `cp` | Customer prefix (e.g., `acme`) |
| `env` | Environment name (e.g., `test`) |

{{% notice warning %}}
**Critical**: If `cp` and `env` don't match between templates, resource discovery will fail and deployment will break.
{{% /notice %}}

---

## What's Next?

- **New to FortiGate AWS deployment?** Use the [Getting Started](../2_getting_started/) guide instead
- **Need architecture details?** See [Architecture Reference](../5_architecture/)
- **Ready for manual deployment?** Continue to [Templates Overview](5_1_overview/)
