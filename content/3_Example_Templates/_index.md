---
title: "Example Templates"
chapter: false
menuTitle: "Overview"
weight: 48
---

## Introduction

The FortiGate Autoscale Simplified Template consists of three complementary Terraform templates that work together to deploy FortiGate architectures in AWS:

1. **[existing_vpc_resources](./3_1_existing_vpc_resources/)** (Deploy First): Creates supporting infrastructure including management VPC, Transit Gateway, spoke VPCs, and deployment mode configuration
2. **[autoscale_template](./3_2_autoscale_template/)** (Choose One): Deploys FortiGate AutoScale group with Gateway Load Balancer for elastic scaling
3. **[ha_pair](./3_3_ha_pair/)** (Choose One): Deploys FortiGate Active-Passive HA Pair with FGCP for fixed-capacity deployment

This modular approach allows you to:
- Choose between AutoScale (elastic scaling) or HA Pair (fixed Active-Passive) deployment modes
- Deploy only the inspection VPC to integrate with existing production environments
- Create a complete lab environment including management VPC, Transit Gateway, and spoke VPCs with traffic generators
- Mix and match components based on your specific requirements

---

## Template Architecture

### Component Relationships

**DIAGRAM PLACEHOLDER: "template-architecture-overview"**
```
Show three-tier architecture:
1. Top: existing_vpc_resources (Management VPC, TGW, Spoke VPCs)
2. Middle: Decision point - AutoScale OR HA Pair
3. Bottom Left: autoscale_template (ASG, GWLB, Lambda)
3. Bottom Right: ha_pair (2x FortiGates, VPC Endpoint, EIPs)

Use arrows to show:
- existing_vpc_resources connects to TGW
- TGW connects to both autoscale_template AND ha_pair (mutually exclusive)
- Both deployment modes integrate with Management VPC
```

### Deployment Mode Decision

When deploying `existing_vpc_resources`, you must choose ONE deployment mode:

**AutoScale Deployment Mode:**
- Creates GWLB subnets in inspection VPC
- Use for elastic scaling requirements
- Deploy `autoscale_template` next

**HA Pair Deployment Mode:**
- Creates HA sync subnets in inspection VPC
- Use for fixed-capacity Active-Passive deployment
- Deploy `ha_pair` template next

---

## Quick Decision Tree

Use this decision tree to determine which template(s) you need:

```
1. Do you need elastic scaling or fixed-capacity deployment?
   |--- ELASTIC SCALING --> Choose AutoScale deployment mode
   |   |                 Deploy existing_vpc_resources (AutoScale mode)
   |   |                 Then deploy autoscale_template
   |   \--------------------> Best for: Variable workloads, cost optimization
   |
   \--- FIXED CAPACITY --> Choose HA Pair deployment mode
       |                Deploy existing_vpc_resources (HA Pair mode)
       |                Then deploy ha_pair template
       \--------------------> Best for: Predictable workloads, stateful failover

2. Do you have existing AWS infrastructure (VPCs, Transit Gateway)?
   |--- YES --> Deploy existing_vpc_resources with appropriate mode
   |         Integrate with existing TGW and VPCs
   |         See: Production Integration Pattern
   |
   \--- NO --> Deploy existing_vpc_resources with appropriate mode
           Creates complete environment including TGW
           See: Lab Environment Pattern

3. Do you need centralized management (FortiManager/FortiAnalyzer)?
   |--- YES --> Enable FortiManager/FortiAnalyzer in existing_vpc_resources
   |         Configure integration in autoscale_template or ha_pair
   |         See: Management VPC Pattern
   |
   \--- NO --> Skip FortiManager/FortiAnalyzer components
           Deploy minimal configuration
```

---

## Template Comparison

| Aspect | existing_vpc_resources | autoscale_template | ha_pair |
|--------|----------------------|-------------------|---------|
| **Required?** | Deploy First | Choose One | Choose One |
| **Purpose** | Supporting infrastructure | Elastic scaling | Fixed Active-Passive |
| **Best For** | All deployments | Variable workloads | Predictable workloads |
| **Components** | Management VPC, TGW, Spoke VPCs, Mode Config | FortiGate ASG, GWLB, Lambda | 2x FortiGates, VPC Endpoint, EIPs |
| **Scaling** | N/A | Auto scales 2-10+ instances | Fixed 2 instances |
| **Failover** | N/A | GWLB distributes traffic | Active-Passive with session sync |
| **Cost** | Medium-High (FortiManager/FortiAnalyzer) | Medium-High (GWLB + instances) | Medium (2 instances + VPC endpoint) |
| **Complexity** | Medium | High (Lambda, GWLB) | Low (Native FortiOS HA) |
| **Production Use** | Common for testing | Common for elastic needs | Common for predictable needs |

---

## Common Integration Patterns

### Pattern 1: Complete Lab Environment

**Use case**: Full-featured testing environment with management and traffic generation

**Templates needed**:
1. existing_vpc_resources (with all components enabled)
2. autoscale_template (connects to created TGW)

**What you get**:
- Management VPC with FortiManager, FortiAnalyzer, and Jump Box
- Transit Gateway with spoke VPCs
- Linux instances for traffic generation
- FortiGate autoscale group with GWLB
- Complete end-to-end testing environment

**Estimated cost**: ~$300-400/month for complete lab

**Deployment time**: ~25-30 minutes

**Next steps**: [Lab Environment Workflow](#lab-environment-workflow)

---

### Pattern 2: Production Integration

**Use case**: Deploy FortiGate inspection to existing production infrastructure

**Templates needed**:
1. existing_vpc_resources (skip entirely)
2. autoscale_template (connects to existing infrastructure)

**Prerequisites**:
- Existing inspection VPC (or create new)
- Optional: Existing Transit Gateway (for centralized inspection)
- Optional: Existing spoke VPCs with GWLBE subnets (for distributed inspection)

**What you get**:
- FortiGate autoscale group with GWLB
- **Centralized inspection**: Integration with Transit Gateway for spoke VPCs (traffic routed through inspection VPC)
- **Distributed inspection**: GWLB endpoints in spoke VPCs (traffic hairpinned through autoscale group)
- **Both architectures simultaneously**: Same FortiGate autoscale group can serve both centralized (TGW-attached) and distributed (direct GWLB) spoke VPCs

**Estimated cost**: ~$150-250/month (FortiGates only, excludes existing infrastructure)

**Deployment time**: ~15-20 minutes

**Next steps**: [Production Integration Workflow](#production-integration-workflow)

---

### Pattern 3: Management VPC Only

**Use case**: Testing FortiManager/FortiAnalyzer integration without spoke VPCs

**Templates needed**:
1. existing_vpc_resources (management VPC components only)
2. autoscale_template (with FortiManager integration enabled)

**What you get**:
- Dedicated management VPC with FortiManager and FortiAnalyzer
- FortiGate autoscale group managed by FortiManager
- No Transit Gateway or spoke VPCs

**Estimated cost**: ~$300/month

**Deployment time**: ~20-25 minutes

**Next steps**: [Management VPC Workflow](#management-vpc-workflow)

---

### Pattern 4: Distributed Inspection (No TGW)

**Use case**: Bump-in-the-wire inspection for distributed spoke VPCs

**Templates needed**:
1. existing_vpc_resources (with `distributed_vpc_cidrs` configured)
2. autoscale_template (with `enable_distributed_inspection = true`)

**Prerequisites**:
- None - templates create everything needed

**What you get**:
- FortiGate autoscale group with GWLB in inspection VPC
- Distributed spoke VPCs with public, private, and GWLBE subnets
- GWLB endpoints automatically created in distributed spoke VPCs
- Bump-in-the-wire routing configured automatically
- Test instances in distributed VPCs for validation

**Estimated cost**: ~$200-250/month (includes distributed VPC resources)

**Deployment time**: ~20 minutes

**Next steps**: [Distributed Inspection Workflow](#distributed-inspection-workflow)

---

## Deployment Workflows

### Lab Environment Workflow

**Objective**: Create complete testing environment from scratch

```bash
# Step 1: Deploy existing_vpc_resources
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars
# Edit: Enable all components (FortiManager, FortiAnalyzer, TGW, Spoke VPCs)
terraform init && terraform apply

# Step 2: Note outputs
terraform output  # Save TGW name and FortiManager IP

# Step 3: Deploy autoscale_template  
cd ../autoscale_template
cp terraform.tfvars.example terraform.tfvars
# Edit: Set attach_to_tgw_name from Step 2 output
#       Use same cp and env values
#       Configure FortiManager integration
terraform init && terraform apply

# Step 4: Verify
ssh -i ~/.ssh/keypair.pem ec2-user@<jump-box-ip>
curl http://<linux-instance-ip>  # Test connectivity
```

**Time to complete**: 30-40 minutes

**See detailed guide**: [existing_vpc_resources Template](3_1_existing_vpc_resources/)

---

### Production Integration Workflow

**Objective**: Deploy inspection VPC to existing production Transit Gateway

```bash
# Step 1: Identify existing resources
aws ec2 describe-transit-gateways --query 'TransitGateways[*].[Tags[?Key==`Name`].Value|[0],TransitGatewayId]'
# Note your production TGW name

# Step 2: Deploy autoscale_template
cd terraform/autoscale_template
cp terraform.tfvars.example terraform.tfvars
# Edit: Set attach_to_tgw_name to production TGW
#       Configure production-appropriate capacity
#       Use BYOL or FortiFlex for cost optimization
terraform init && terraform apply

# Step 3: Update TGW route tables
# Route spoke VPC traffic (0.0.0.0/0) to inspection VPC attachment
# via AWS Console or CLI

# Step 4: Test and validate
# Verify traffic flows through FortiGate
# Check FortiGate logs and CloudWatch metrics
```

**Time to complete**: 20-30 minutes (plus TGW routing configuration)

**See detailed guide**: [autoscale_template](3_2_autoscale_template/)

---

### Management VPC Workflow

**Objective**: Deploy management infrastructure with FortiManager/FortiAnalyzer

```bash
# Step 1: Deploy existing_vpc_resources (management only)
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars
# Edit: enable_build_management_vpc = true
#       enable_fortimanager = true
#       enable_fortianalyzer = true
#       enable_build_existing_subnets = false
terraform init && terraform apply

# Step 2: Configure FortiManager
# Access FortiManager GUI: https://<fmgr-ip>
# Enable VM device recognition if FMG 7.6.3+
config system global
    set fgfm-allow-vm enable
end

# Step 3: Deploy autoscale_template
cd ../autoscale_template
cp terraform.tfvars.example terraform.tfvars
# Edit: enable_fortimanager_integration = true
#       fortimanager_ip = <from Step 1 output>
#       enable_dedicated_management_vpc = true
terraform init && terraform apply

# Step 4: Authorize devices on FortiManager
# Device Manager > Device & Groups
# Right-click unauthorized device > Authorize
```

**Time to complete**: 25-35 minutes

---

### Distributed Inspection Workflow

**Objective**: Deploy FortiGate with distributed spoke VPCs (no Transit Gateway)

```bash
# Step 1: Deploy existing_vpc_resources with distributed VPCs
cd terraform/existing_vpc_resources
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
#   enable_autoscale_deployment = true
#   distributed_vpc_cidrs = ["10.50.0.0/16", "10.51.0.0/16"]  # Add your distributed VPCs
#   distributed_subnet_bits = 8

terraform init && terraform apply

# Step 2: Note outputs
terraform output distributed_vpc_ids
terraform output distributed_gwlbe_subnet_ids

# Step 3: Deploy autoscale_template with distributed inspection
cd ../autoscale_template
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
#   cp = "your-prefix"           # Must match existing_vpc_resources
#   env = "your-env"             # Must match existing_vpc_resources
#   enable_distributed_inspection = true
#   firewall_policy_mode = "1-arm"  # Recommended for distributed

terraform init && terraform apply

# Step 4: Verify GWLB endpoints created
terraform output  # Check for distributed VPC GWLB endpoints

# Step 5: Test traffic flow from distributed VPC instances
# SSH to test instances (private IPs shown in existing_vpc_resources outputs)
# From distributed instance: curl https://ifconfig.me
# Verify traffic flows through FortiGate (check FortiGate logs)
```

**What happens automatically**:
- Module discovers distributed VPCs by tag pattern (`{cp}-{env}-distributed-*-vpc`)
- Creates GWLB endpoints in each distributed VPC's GWLBE subnets
- Configures bump-in-the-wire routing (private --> GWLBE --> FortiGate --> GWLBE --> IGW)
- All distributed VPCs share same firewall policy (single VDOM mode)

**Time to complete**: 25-30 minutes

---

## When to Use Each Template

### Use existing_vpc_resources When:

**Creating a lab or test environment from scratch**
- Need complete isolated environment
- Want to test all features including FortiManager/FortiAnalyzer
- Require traffic generation for load testing

**Demonstrating FortiGate autoscale capabilities**
- Sales Engineering demonstrations
- Proof-of-concept deployments
- Training and enablement sessions

**Need centralized management infrastructure**
- First-time FortiManager deployment
- Want persistent management VPC separate from inspection VPC
- Require FortiAnalyzer for logging/reporting

### Skip existing_vpc_resources When:

**Deploying to production**
- Existing Transit Gateway and VPCs available
- Integration with established workloads required
- Management infrastructure already exists

**Cost-sensitive testing**
- FortiManager/FortiAnalyzer not needed for specific tests
- Minimal viable deployment preferred
- Short-term testing (< 1 week)

**Distributed inspection architecture**
- Use existing_vpc_resources with `distributed_vpc_cidrs` to create distributed spoke VPCs
- Templates automatically create GWLBE subnets and configure bump-in-the-wire routing
- No Transit Gateway needed for distributed VPCs

---

## Template Variable Coordination

When using both templates together, **certain variables must match** for proper integration:

### Must Match Between Templates

| Variable | Purpose | Impact if Mismatched |
|----------|---------|---------------------|
| `aws_region` | AWS region | Resources created in wrong region |
| `availability_zone_1` | First AZ | Subnets in different AZs |
| `availability_zone_2` | Second AZ | Subnets in different AZs |
| `cp` (customer prefix) | Resource naming | Tag-based discovery fails |
| `env` (environment) | Resource naming | Tag-based discovery fails |
| `vpc_cidr_management` | Management VPC CIDR | Routing conflicts |
| `vpc_cidr_spoke` | Spoke VPC supernet | Routing conflicts |

### Example Coordinated Configuration

**existing_vpc_resources/terraform.tfvars**:
```hcl
aws_region          = "us-west-2"
availability_zone_1 = "a"
availability_zone_2 = "c"
cp                  = "acme"
env                 = "test"
vpc_cidr_management = "10.3.0.0/16"
```

**autoscale_template/terraform.tfvars**:
```hcl
aws_region          = "us-west-2"  # MUST MATCH
availability_zone_1 = "a"          # MUST MATCH
availability_zone_2 = "c"          # MUST MATCH
cp                  = "acme"       # MUST MATCH
env                 = "test"       # MUST MATCH
vpc_cidr_management = "10.3.0.0/16"  # MUST MATCH

attach_to_tgw_name = "acme-test-tgw"  # Matches cp-env naming
```

---

## Next Steps

Choose your deployment pattern and proceed to the appropriate template guide:

1. **Lab/Test Environment**: Start with [existing_vpc_resources Template](3_1_existing_vpc_resources/)
2. **Production Deployment**: Go directly to [autoscale_template](3_2_autoscale_template/)
3. **Need to review components?**: See [Autoscale Reference](../../3_example_templates/3_2_autoscale_template/autoscale_reference/)
4. **Need licensing guidance?**: See [Licensing Options](../../3_example_templates/3_2_autoscale_template/autoscale_reference/4_4_licensing_options/)

---

## Summary

The FortiGate Autoscale Simplified Template provides flexible deployment options through two complementary templates:

| Template | Required? | Best For | Deploy When |
|----------|-----------|----------|-------------|
| existing_vpc_resources | Optional | Lab/test environments | Creating complete test environment or need management VPC |
| autoscale_template | Required | All deployments | Every deployment - integrates with existing or created resources |

**Key Principle**: Start with the simplest deployment that meets your requirements. You can always add complexity later.

**Recommended Starting Point**: 
- First-time users: Deploy both templates for complete lab environment
- Production deployments: Skip to autoscale_template with existing infrastructure
- Cost-conscious testing: Deploy autoscale_template only with minimal capacity
