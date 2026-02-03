---
title: "Additional Configuration Options"
chapter: false
menuTitle: "Additional Configuration"
weight: 48
---

## Overview

This section covers additional configuration options for fine-tuning FortiGate instance specifications and advanced deployment settings.

---

## FortiGate Instance Specifications

### Instance Type Selection

```hcl
fgt_instance_type = "c7gn.xlarge"
```

**Instance type selection considerations**:
- **c6i/c7i series**: Intel-based compute-optimized (best for x86 workloads)
- **c6g/c7g/c7gn series**: AWS Graviton (ARM-based, excellent performance)
- **Sizing**: Choose vCPU count matching expected throughput requirements

**Common instance types for FortiGate**:

| Instance Type | vCPUs | Memory | Network Performance | Best For |
|--------------|-------|--------|---------------------|----------|
| c6i.large | 2 | 4 GB | Up to 12.5 Gbps | Small deployments, dev/test |
| c6i.xlarge | 4 | 8 GB | Up to 12.5 Gbps | Standard production workloads |
| c6i.2xlarge | 8 | 16 GB | Up to 12.5 Gbps | High-throughput environments |
| c7gn.xlarge | 4 | 8 GB | Up to 30 Gbps | High-performance networking |
| c7gn.2xlarge | 8 | 16 GB | Up to 30 Gbps | Very high-performance networking |

### FortiOS Version

```hcl
fortios_version = "7.4.5"
```

**Version specification options**:
- **Exact version** (e.g., `"7.4.5"`): Pin to specific version for consistency across environments
- **Major version** (e.g., `"7.4"`): Automatically use latest minor version within major release
- **Latest**: Omit or use `"latest"` to always deploy newest available version

**Recommendations**:
- **Production**: Use exact version numbers to prevent unexpected changes
- **Dev/Test**: Use major version or latest to test new features and fixes
- **Always test** new FortiOS versions in non-production before upgrading production deployments

**Version considerations**:
- Newer versions may include critical security fixes
- Performance improvements and new features
- Potential breaking changes in configuration syntax
- Always review release notes before upgrading

---

## FortiGate GUI Port

```hcl
fortigate_gui_port = 443
```

**Common options**:
- `443` (default): Standard HTTPS port
- `8443`: Alternate HTTPS port (some organizations prefer moving GUI off default port for security)
- `10443`: Another common alternate port

**When changing the GUI port**:
- Update security group rules to allow traffic to new port
- Update documentation and runbooks with new port
- Existing sessions will be dropped when port changes
- Coordinate change with operations team

---

## Gateway Load Balancer Cross-Zone Load Balancing

```hcl
allow_cross_zone_load_balancing = true
```

### Enabled (`true`) - Recommended for Production
- GWLB distributes traffic to healthy FortiGate instances in **any** Availability Zone
- Better utilization of capacity during partial AZ failures
- Improved overall availability and fault tolerance
- Traffic can flow to any healthy instance regardless of AZ

### Disabled (`false`)
- GWLB only distributes traffic to instances in **same** AZ as GWLB endpoint
- Traffic remains within single AZ (lowest latency)
- Reduced capacity during AZ-specific health issues
- Must maintain sufficient capacity in each AZ independently

### Decision Factors

**Enable for**:
- Production environments requiring maximum availability
- Multi-AZ deployments where instance distribution may be uneven
- Architectures where AZ-level failures must be transparent to applications
- Workloads where availability is prioritized over lowest latency

**Disable for**:
- Workloads with strict latency requirements
- Architectures with guaranteed even instance distribution across AZs
- Environments with predictable AZ-local traffic patterns
- Data residency requirements mandating AZ-local processing

**Recommendation**: Enable for production deployments to maximize availability and capacity utilization

---

## SSH Key Pair

```hcl
keypair_name = "my-fortigate-keypair"
```

**Purpose**: SSH key pair for emergency CLI access to FortiGate instances

**Best practices**:
- Create dedicated key pair for FortiGate instances (separate from application instances)
- Store private key securely in password manager or AWS Secrets Manager
- Rotate key pairs periodically (every 6-12 months)
- Document key pair name and location in runbooks
- Limit access to private key to authorized personnel only

**Creating a key pair**:
```bash
# Via AWS CLI
aws ec2 create-key-pair --key-name my-fortigate-keypair --query 'KeyMaterial' --output text > my-fortigate-keypair.pem
chmod 400 my-fortigate-keypair.pem

# Or via AWS Console: EC2 > Key Pairs > Create Key Pair
```

---

## Resource Tagging

```hcl
resource_tags = {
  Environment = "Production"
  Project     = "FortiGate-Autoscale"
  Owner       = "security-team@example.com"
  CostCenter  = "CC-12345"
}
```

**Common tags to include**:
- **Environment**: Production, Development, Staging, Test
- **Project**: Project or application name
- **Owner**: Team or individual responsible for resources
- **CostCenter**: For cost allocation and chargeback
- **ManagedBy**: Terraform, CloudFormation, etc.
- **CreatedDate**: When resources were initially deployed

**Benefits of comprehensive tagging**:
- Cost allocation and reporting
- Resource organization and filtering
- Access control policies
- Automation and orchestration
- Compliance and governance

---

## Summary Checklist

Before proceeding to deployment, verify you've configured:

- ✅ **Internet Egress**: EIP or NAT Gateway mode selected
- ✅ **Firewall Architecture**: 1-ARM or 2-ARM mode chosen
- ✅ **Management Isolation**: Dedicated ENI and/or VPC configured (if required)
- ✅ **Licensing**: BYOL directory populated or FortiFlex configured
- ✅ **FortiManager**: Integration enabled (if centralized management required)
- ✅ **Capacity**: ASG min/max/desired sizes set appropriately
- ✅ **Primary Protection**: Scale-in protection enabled for production
- ✅ **Instance Specs**: Instance type and FortiOS version selected
- ✅ **Additional Options**: GUI port, cross-zone LB, key pair, tags configured

---

## Next Steps

You're now ready to proceed to the [Summary](../4_9_summary/) page for a complete overview of all solution components, or jump directly to [Templates](../../5_templates/) to begin deployment.
