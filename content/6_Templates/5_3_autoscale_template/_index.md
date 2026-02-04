---
title: "autoscale_template"
chapter: false
menuTitle: "autoscale_template"
weight: 53
---

## Overview

The `autoscale_template` is the **required** Terraform template that deploys the core FortiGate autoscale infrastructure. This template is used for **all deployments** and can operate independently or integrate with resources created by the [existing_vpc_resources](../5_2_existing_vpc_resources/) template.

{{% notice info %}}
**This template is required for all deployments**. It creates the inspection VPC, FortiGate autoscale group, Gateway Load Balancer, and all components necessary for traffic inspection.
{{% /notice %}}

---

## Documentation Structure

This template documentation is organized into focused sections:

1. **[Deployment Guide](53_1_deployment/)** - Step-by-step deployment instructions
2. **[Post-Deployment Configuration](53_2_configuration/)** - Configure TGW routes, FortiGate policies, and FortiManager
3. **[Operations & Troubleshooting](53_3_operations/)** - Monitoring, troubleshooting, best practices, and cleanup
4. **[Reference](53_4_reference/)** - Outputs and variable reference

---

## What It Creates

The autoscale_template deploys a complete FortiGate autoscale solution including:

### Core Components

| Component | Purpose | Always Created |
|-----------|---------|----------------|
| **Inspection VPC** | Dedicated VPC for FortiGate instances and GWLB | Yes |
| **FortiGate Autoscale Groups** | BYOL and/or on-demand instance groups | Yes |
| **Gateway Load Balancer** | Distributes traffic across FortiGate instances | Yes |
| **GWLB Endpoints** | Connection points in each AZ | Yes |
| **Lambda Functions** | Lifecycle management and licensing automation | Yes |
| **DynamoDB Table** | License tracking and state management | Yes (if BYOL) |
| **S3 Bucket** | License file storage and Lambda code | Yes (if BYOL) |
| **IAM Roles** | Permissions for Lambda and EC2 instances | Yes |
| **Security Groups** | Network access control | Yes |
| **CloudWatch Alarms** | Autoscaling triggers | Yes |

### Optional Components

| Component | Purpose | Enabled By |
|-----------|---------|-----------|
| **Transit Gateway Attachment** | Connection to TGW for centralized architecture | `enable_tgw_attachment` |
| **Dedicated Management ENI** | Isolated management interface | `enable_dedicated_management_eni` |
| **Dedicated Management VPC Connection** | Management in separate VPC | `enable_dedicated_management_vpc` |
| **FortiManager Integration** | Centralized policy management | `enable_fortimanager_integration` |
| **East-West Inspection** | Inter-spoke traffic inspection | `enable_east_west_inspection` |

---

## Architecture Patterns

The autoscale_template supports multiple deployment patterns:

### Pattern 1: Centralized Architecture with TGW

**Configuration**:
```hcl
enable_tgw_attachment = true
attach_to_tgw_name = "production-tgw"
```

**Traffic flow**:
```
Spoke VPCs --> TGW --> Inspection VPC --> FortiGate --> GWLB --> Internet
```

**Use cases**:
- Production centralized egress
- Multi-VPC environments
- East-west traffic inspection

---

### Pattern 2: Distributed Inspection Architecture

**Configuration**:
```hcl
enable_distributed_inspection = true
```

**Traffic flow**:
```
VPC --> GWLBe --> GWLB --> GENEVE tunnel --> FortiGate --> GENEVE tunnel --> GWLB --> GWLBe --> VPC
```

**Use cases**:
- Distributed security architecture with local GWLB endpoints
- Per-VPC inspection without Transit Gateway
- Bump-in-the-wire deployments (traffic hairpinned through same GWLB endpoint)

**Key points**:
- Independent of Transit Gateway (can coexist with TGW-attached centralized spokes)
- Requires distributed VPCs created with GWLBE subnets
- Module automatically discovers and configures VPCs by tag pattern

---

### Pattern 3: Hybrid with Management VPC

**Configuration**:
```hcl
enable_tgw_attachment = true
enable_dedicated_management_vpc = true
enable_fortimanager_integration = true
```

**Traffic flow**:
```
Data: Spoke VPCs --> TGW --> FortiGate --> Internet
Management: FortiGate --> Management VPC --> FortiManager
```

**Use cases**:
- Enterprise deployments
- Centralized management requirements
- Compliance-driven architectures

---

## Integration Modes

### Integration with existing_vpc_resources

When deploying after `existing_vpc_resources`:

**Required variable coordination**:
```hcl
# Must match existing_vpc_resources values
aws_region          = "us-west-2"
availability_zone_1 = "a"
availability_zone_2 = "c"
cp                  = "acme"      # MUST MATCH
env                 = "test"      # MUST MATCH

# Connect to created TGW
enable_tgw_attachment = true
attach_to_tgw_name    = "acme-test-tgw"  # From existing_vpc_resources output

# Connect to management VPC (if created)
enable_dedicated_management_vpc = true
dedicated_management_vpc_tag = "acme-test-management-vpc"
dedicated_management_public_az1_subnet_tag = "acme-test-management-public-az1-subnet"
dedicated_management_public_az2_subnet_tag = "acme-test-management-public-az2-subnet"

# FortiManager integration (if enabled in existing_vpc_resources)
enable_fortimanager_integration = true
fortimanager_ip = "10.3.0.10"  # From existing_vpc_resources output
fortimanager_sn = "FMGVM0000000001"
```

---

### Integration with Existing Production Infrastructure

When deploying to existing production environment:

**Required information**:
- Existing Transit Gateway name (or skip TGW entirely)
- Existing management VPC details (or skip)
- Network CIDR ranges to avoid overlaps

**Configuration**:
```hcl
# Connect to existing production TGW
enable_tgw_attachment = true
attach_to_tgw_name = "production-tgw"  # Your existing TGW

# Use existing management infrastructure
enable_fortimanager_integration = true
fortimanager_ip = "10.100.50.10"  # Your existing FortiManager
fortimanager_sn = "FMGVM1234567890"
```

---

## Next Steps

- **Ready to deploy?** Go to [Deployment Guide](53_1_deployment/)
- **Already deployed?** See [Post-Deployment Configuration](53_2_configuration/)
- **Need help?** Check [Operations & Troubleshooting](53_3_operations/)
