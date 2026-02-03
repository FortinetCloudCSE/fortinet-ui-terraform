---
title: "Templates"
chapter: true
menuTitle: "Templates"
weight: 50
---

# Deployment Templates

The FortiGate Autoscale Simplified Template provides modular Terraform templates for deploying autoscale architectures in AWS. This section covers both templates and their integration patterns.

## Available Templates

### [Templates Overview](5_1_overview/)
Understand the template architecture, choose deployment patterns, and learn how templates work together.

### [existing_vpc_resources Template](5_2_existing_vpc_resources/) (Required First)
Create supporting infrastructure for lab and test environments including management VPC, Transit Gateway, spoke VPCs, and deployment mode configuration (AutoScale or HA Pair).

### [autoscale_template](5_3_unified_template/) (Choose One)
Deploy FortiGate AutoScale group with Gateway Load Balancer for elastic scaling and distributed traffic inspection.

### [ha_pair Template](5_4_ha_pair/) (Choose One)
Deploy FortiGate Active-Passive HA Pair with FGCP for fixed-capacity deployment with stateful failover.

---

## Quick Start Paths

### For AutoScale Lab/Test Environments
1. Start with [Templates Overview](5_1_overview/) to understand architecture
2. Deploy [existing_vpc_resources](5_2_existing_vpc_resources/) with **AutoScale Deployment** mode
3. Deploy [autoscale_template](5_3_unified_template/) connected to created resources
4. Time: ~30-40 minutes

### For HA Pair Lab/Test Environments
1. Start with [Templates Overview](5_1_overview/) to understand architecture
2. Deploy [existing_vpc_resources](5_2_existing_vpc_resources/) with **HA Pair Deployment** mode
3. Deploy [ha_pair](5_4_ha_pair/) connected to created resources
4. Time: ~25-35 minutes

### For Production Deployments
1. Review [Templates Overview](5_1_overview/) for integration patterns
2. Deploy [existing_vpc_resources](5_2_existing_vpc_resources/) with appropriate deployment mode
3. Deploy either [autoscale_template](5_3_unified_template/) OR [ha_pair](5_4_ha_pair/)
4. Time: ~20-30 minutes

---

## Template Coordination

When using both templates together, ensure these variables **match exactly**:
- `aws_region`
- `availability_zone_1` and `availability_zone_2`
- `cp` (customer prefix)
- `env` (environment)
- `vpc_cidr_management`
- `vpc_cidr_spoke`

See [Templates Overview](5_1_overview/) for detailed coordination requirements.

---

## What's Next?

- **New to FortiGate AWS deployment?** Start with [Templates Overview](5_1_overview/)
- **Need lab environment?** Go to [existing_vpc_resources](5_2_existing_vpc_resources/)
- **Ready for AutoScale deployment?** Go to [autoscale_template](5_3_unified_template/)
- **Ready for HA Pair deployment?** Go to [ha_pair](5_4_ha_pair/)
- **Need configuration details?** See [Solution Components](../4_solution_components/)
