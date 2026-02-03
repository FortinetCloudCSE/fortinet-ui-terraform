---
title: "Licensing"
chapter: false
menuTitle: "Licensing"
weight: 30
---

## Overview

FortiGate autoscale deployments in AWS support three distinct licensing models, each optimized for different operational requirements, cost structures, and scaling behaviors. The choice of licensing strategy significantly impacts deployment complexity, operational costs, and the ability to dynamically scale capacity in response to demand.

This template supports all three licensing models and enables **hybrid licensing configurations** where multiple license types coexist within the same autoscale group, providing maximum flexibility for cost optimization and capacity management.

---

## Licensing Options

### AWS Marketplace Pay-As-You-Go (PAYG)

**Best for: Proof of concepts, temporary workloads, elastic burst capacity**

AWS Marketplace PAYG licensing offers the simplest deployment path with zero upfront licensing requirements. Instances are billed hourly through your AWS account based on instance type and included FortiGuard services.

#### Advantages
- **Zero configuration**: No license files, tokens, or registration required
- **Instant deployment**: Instances launch immediately without license provisioning delays
- **Elastic scaling**: Ideal for autoscale groups that frequently scale out and in
- **No commitment**: Pay only for actual runtime hours with no long-term contracts
- **Consolidated billing**: All costs appear on AWS invoices alongside infrastructure charges

#### Considerations
- **Higher per-hour cost**: Premium pricing compared to BYOL or FortiFlex over extended periods
- **Service bundle locked**: Cannot customize FortiGuard service subscriptions; you receive the bundle included with the marketplace offering
- **Limited cost optimization**: No volume discounts or prepaid savings
- **Vendor lock-in**: Cannot migrate licenses to on-premises or other cloud providers

#### When to Use
- Development, testing, and staging environments
- Proof-of-concept deployments with undefined timelines
- Burst capacity in hybrid licensing architectures (scale beyond BYOL/FortiFlex baseline)
- Short-term projects (< 6 months) where simplicity outweighs cost
- Disaster recovery standby capacity that remains dormant most of the time

#### Implementation Notes
- Select PAYG AMI from AWS Marketplace during launch template configuration
- No Lambda-based license management required
- Instances automatically activate upon boot
- FortiGuard services update immediately without additional registration

---

### Bring Your Own License (BYOL)

**Best for: Long-term production deployments with predictable capacity requirements**

BYOL licensing leverages perpetual or term-based FortiGate-VM licenses purchased directly from Fortinet or authorized resellers. This model provides the lowest per-instance operating cost for sustained workloads but requires manual license file management.

#### Advantages
- **Lowest operating cost**: Significant savings (40-60%) compared to PAYG for long-term deployments
- **Custom service bundles**: Select specific FortiGuard subscriptions (UTP, ATP, Enterprise) based on security requirements
- **Portable licenses**: Migrate licenses between environments (AWS, Azure, on-premises) with proper licensing terms
- **Volume discounts**: Enterprise agreements provide additional cost reductions at scale
- **Predictable budgeting**: Fixed annual or multi-year costs independent of instance runtime

#### Considerations
- **Manual license management**: Requires obtaining, storing, and deploying license files for each instance
- **Upfront capital expense**: Purchase licenses before deployment
- **Reduced flexibility**: Fixed license count limits maximum autoscale capacity unless additional licenses are procured
- **License tracking overhead**: Must maintain inventory of assigned vs. available licenses
- **Decommissioning process**: Requires license recovery when scaling in or decommissioning environments

#### When to Use
- Production workloads with predictable, steady-state capacity requirements
- Long-term deployments (> 1 year) where cost savings justify management overhead
- Organizations with existing Fortinet licensing agreements or ELAs
- Environments requiring specific FortiGuard service combinations not available in marketplace offerings
- Hybrid licensing architectures as the baseline capacity tier

#### Implementation Notes
- Store license files in S3 bucket accessible by Lambda function
- Lambda function reads license files and applies them during instance boot
- Configure `lic_folder_path` variable to point to license file directory
- Naming convention: License files should match naming pattern expected by Lambda (e.g., sequential numbering)
- DynamoDB table tracks license assignments to prevent duplicate usage
- Decommissioned instances return licenses to available pool for reuse

#### License File Requirements
```
licenses/
├── FGVM01-001.lic
├── FGVM01-002.lic
├── FGVM01-003.lic
└── FGVM01-004.lic
```

**Critical**: Ensure sufficient licenses exist for `asg_max_size`. If licenses are exhausted during scale-out, new instances will remain unlicensed and non-functional.

---

### FortiFlex (Usage-Based Licensing)

**Best for: Dynamic workloads requiring flexibility with optimized costs for medium to long-term deployments**

FortiFlex (formerly Flex-VM) is Fortinet's consumption-based, points-driven licensing program that combines the flexibility of PAYG with cost structures approaching BYOL. Points are consumed daily based on FortiGate configuration (CPU count, service package), and licenses are dynamically provisioned via API tokens.

#### Advantages
- **Flexible scaling**: Provision and deprovision licenses on-demand through API integration
- **Optimized costs**: 20-40% savings compared to PAYG for sustained workloads
- **Automated license lifecycle**: Lambda function generates license tokens automatically during instance launch
- **Right-sizing capability**: Change CPU count or service packages dynamically; pay only for what you consume
- **Simplified license management**: No physical license files; tokens generated via API calls
- **Point pooling**: Share point allocations across multiple deployments and cloud providers
- **Burst capacity support**: Quickly provision additional licenses without procurement delays

#### Considerations
- **Initial setup complexity**: Requires FortiFlex program registration, configuration templates, and API integration
- **Point management**: Monitor point consumption to prevent negative balance or service interruption
- **Active entitlement management**: Must create/stop entitlements to control costs
- **API dependency**: Relies on connectivity to FortiFlex API endpoints during instance provisioning
- **Grace period risks**: Running negative balance triggers 90-day grace period; service stops if not resolved
- **Minimum commitment**: Some FortiFlex programs require minimum annual consumption

#### When to Use
- Production workloads with variable but predictable traffic patterns
- Multi-environment deployments (dev, staging, production) sharing point pools
- Organizations pursuing cloud-first strategies without legacy perpetual licenses
- Architectures requiring frequent right-sizing of FortiGate instances
- Deployments spanning multiple cloud providers or hybrid architectures
- Cost-conscious autoscale groups with moderate to high uptime requirements

#### Implementation Notes
- Register FortiFlex program and purchase point packs via FortiCare portal
- Create FortiGate-VM configurations in FortiFlex portal defining CPU count and service packages
- Generate API credentials through IAM portal with FortiFlex permissions
- Configure Lambda function environment variables with FortiFlex API credentials
- Lambda function creates entitlements and retrieves license tokens during instance launch
- Entitlements automatically STOP when instances terminate, halting point consumption
- Monitor point balance via FortiFlex portal or API to prevent service interruption

#### FortiFlex Prerequisites
1. **FortiFlex Program Registration**:
   - Purchase program SKU: `FC-10-ELAVR-221-02-XX` (12, 36, or 60 months)
   - Register program in FortiCare at `https://support.fortinet.com`
   - Wait up to 4 hours for program validation

2. **Point Pack Purchase**:
   - Annual packs: `LIC-ELAVM-10K` (10,000 points, 1-year term with rollover)
   - Multi-year packs: `LIC-ELAVMMY-50K-XX` (50,000 points, 3-5 year terms)
   - Bulk packs: `LIC-ELAVMMY-BULK-SEAT` (100,000 points per seat, minimum 10 seats)

3. **Configuration Creation**:
   - Define VM specifications (CPU count, service package, VDOMs)
   - Example: 2-CPU FortiGate with UTP bundle = ~6.5 points/day
   - Use FortiFlex Calculator to estimate consumption: `https://fndn.fortinet.net/index.php?/tools/fortiflex/`

4. **API Access Setup**:
   - Create IAM permission profile including FortiFlex portal
   - Create API user and download credentials
   - Obtain API token via authentication endpoint
   - Store credentials securely (AWS Secrets Manager recommended)

#### Point Consumption Examples
| Configuration | Daily Points | Monthly Points (30 days) | Annual Points |
|---------------|--------------|--------------------------|---------------|
| 1 CPU, FortiCare Premium | 1.63 | 49 | 595 |
| 2 CPU, UTP Bundle | 6.52 | 196 | 2,380 |
| 4 CPU, ATP Bundle | 26.08 | 782 | 9,519 |
| 8 CPU, Enterprise Bundle | 104.32 | 3,130 | 38,077 |

**Note**: Actual consumption varies based on specific service selections and VDOM count. Always use the FortiFlex Calculator for accurate estimates.

---

## Hybrid Licensing Architecture

### Overview

The autoscale template supports **hybrid licensing configurations** where multiple license types coexist within separate Auto Scaling Groups (ASGs). This architecture provides cost optimization by using BYOL or FortiFlex for baseline capacity and PAYG for elastic burst capacity.

### Architecture Pattern

```
┌─────────────────────────────────────────────────────┐
│              GWLB Target Group                      │
│                  (Unified)                          │
└────────┬────────────────────────────────┬───────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────┐
│  BYOL/FortiFlex │              │   PAYG ASG      │
│       ASG       │              │                 │
│                 │              │                 │
│  Min: 2         │              │  Min: 0         │
│  Max: 4         │              │  Max: 8         │
│  Desired: 2     │              │  Desired: 0     │
│                 │              │                 │
│ (Baseline)      │              │ (Burst)         │
└─────────────────┘              └─────────────────┘
```

### Configuration Strategy

1. **Primary ASG (BYOL or FortiFlex)**:
   - Configure with minimum = desired capacity
   - Sets baseline capacity for steady-state traffic
   - Lower per-instance cost for sustained operation
   - Example: `min_size = 2`, `max_size = 4`, `desired_capacity = 2`

2. **Secondary ASG (PAYG)**:
   - Configure with minimum = 0, desired = 0
   - Remains dormant during normal operations
   - Scales out only when primary ASG reaches maximum capacity
   - Example: `min_size = 0`, `max_size = 8`, `desired_capacity = 0`

3. **Scaling Coordination**:
   - Configure CloudWatch alarms with staggered thresholds
   - Primary ASG scales at lower CPU threshold (e.g., 60%)
   - Secondary ASG scales at higher CPU threshold (e.g., 75%)
   - Provides buffer for primary ASG to stabilize before burst scaling

### Cost Optimization Example

**Scenario**: E-commerce application with baseline 4 Gbps throughput, occasional spikes to 12 Gbps

**Hybrid Configuration**:
- **Primary**: 4x c6i.xlarge (4 vCPUs) with FortiFlex
  - Daily points: 4 instances × 26.08 points = 104.32 points/day
  - Monthly cost: ~$X (based on point pricing)
  - Handles baseline traffic continuously

- **Secondary**: 0-8x c6i.xlarge with PAYG
  - Hourly cost: $Y per instance
  - Scales only during traffic spikes (estimated 10% of time)
  - Monthly cost: 8 instances × $Y/hour × 720 hours × 0.10 = $Z

**Savings vs. Pure PAYG**: Approximately 35-45% reduction for this traffic pattern

### Implementation Notes

- Both ASGs register with same GWLB target group for unified traffic distribution
- Each ASG requires separate launch template with appropriate licensing configuration
- CloudWatch alarms must reference correct ASG names for scaling actions
- Lambda function handles license provisioning independently for each ASG
- Monitor scaling activities to validate primary ASG exhausts capacity before secondary ASG activates

---

## License Selection Decision Tree

```
START: What is your deployment scenario?
│
├─ POC / Testing / Short-term project (< 6 months)
│  └─ Use: AWS Marketplace PAYG
│     └─ Rationale: Simplicity, no upfront investment, easy teardown
│
├─ Long-term production (> 12 months) with steady-state capacity
│  └─ Do you have existing Fortinet licenses or ELA?
│     ├─ YES → Use: BYOL
│     │  └─ Rationale: Lowest cost, leverage existing investment
│     └─ NO → Use: FortiFlex
│        └─ Rationale: Flexible, better cost than PAYG, no upfront licensing
│
├─ Production with variable traffic patterns
│  └─ Use: Hybrid (FortiFlex + PAYG)
│     └─ Rationale: Baseline cost optimization with elastic burst capacity
│
└─ Multi-environment deployment (dev/staging/prod)
   └─ Use: FortiFlex
      └─ Rationale: Point pooling across environments, on-demand provisioning
```

---

## Best Practices

### General Recommendations

1. **Calculate total cost of ownership (TCO)**:
   - Project instance runtime hours over 12-36 months
   - Factor in scaling frequency and burst capacity requirements
   - Include license management overhead costs for BYOL
   - Use FortiFlex Calculator for accurate point consumption estimates

2. **Start with PAYG for prototyping**:
   - Validate architecture and sizing before committing to licenses
   - Measure actual traffic patterns to inform license type selection
   - Convert to BYOL or FortiFlex after requirements stabilize

3. **Implement hybrid licensing for cost optimization**:
   - Use BYOL/FortiFlex for baseline capacity that runs 24/7
   - Use PAYG for burst capacity that scales intermittently
   - Monitor scaling patterns monthly and adjust ASG configurations

4. **Automate license lifecycle management**:
   - Use Lambda functions for automated license provisioning
   - Implement DynamoDB tracking for BYOL license assignments
   - Enable CloudWatch alarms for FortiFlex point balance monitoring
   - Store FortiFlex API credentials in AWS Secrets Manager

### BYOL-Specific Best Practices

1. **Maintain license inventory**:
   - Track assigned vs. available licenses in spreadsheet or CMDB
   - Reserve 10-20% buffer above `asg_max_size` for maintenance windows
   - Implement automated alerts when available licenses fall below threshold

2. **Standardize license file naming**:
   - Use consistent naming convention (e.g., `FGVMXX-001.lic`)
   - Document naming pattern in deployment runbooks
   - Ensure Lambda function matches naming pattern logic

3. **Test license recovery**:
   - Verify decommissioned instances return licenses to pool
   - Validate DynamoDB table updates correctly
   - Practice license recovery procedures before production incidents

### FortiFlex-Specific Best Practices

1. **Monitor point consumption actively**:
   - Review Point Usage reports weekly in FortiFlex portal
   - Set up email notifications for low balance (90/60/30 day thresholds)
   - Correlate point consumption with CloudWatch ASG metrics

2. **Plan point pack purchases**:
   - Purchase points early in program year to maximize rollover (annual packs)
   - Use multi-year packs for long-term stable deployments to avoid rollover complexity
   - Maintain 20-30% buffer above projected consumption

3. **Optimize entitlement lifecycle**:
   - STOP entitlements immediately after instance termination to halt point consumption
   - Use Lambda automation to stop entitlements within minutes of scale-in events
   - Review STOPPED entitlements weekly and delete if no longer needed

4. **Right-size FortiGate configurations**:
   - Start with minimal CPU count and scale up as needed
   - Use A La Carte service packages for cost optimization when not all services required
   - Adjust configurations quarterly based on actual usage patterns

---

## Troubleshooting

### Common Licensing Issues

#### BYOL: Instances Launch Without License

**Symptoms**: FortiGate instance boots but no license is applied; limited functionality

**Causes**:
- License file not found in S3 bucket
- Incorrect `lic_folder_path` variable
- Lambda function lacks S3 permissions
- License file naming doesn't match Lambda logic
- All licenses already assigned (pool exhausted)

**Resolution**:
1. Verify license files exist in S3 bucket: `aws s3 ls s3://<bucket>/licenses/`
2. Check Lambda CloudWatch logs for S3 access errors
3. Validate IAM role attached to Lambda has `s3:GetObject` permission
4. Confirm available licenses exist in DynamoDB tracking table
5. Manually apply license via FortiGate CLI: `execute restore config license.lic`

#### FortiFlex: License Token Generation Fails

**Symptoms**: Instance launches but does not activate; no serial number assigned

**Causes**:
- FortiFlex API credentials expired or invalid
- Insufficient points in FortiFlex account
- FortiFlex program expired
- Network connectivity issues to FortiFlex API
- Configuration ID not found or deactivated

**Resolution**:
1. Check Lambda CloudWatch logs for API authentication errors
2. Verify FortiFlex API credentials: `curl` test authentication endpoint
3. Log into FortiFlex portal and check point balance
4. Confirm program status and expiration date
5. Verify configuration exists and is active in FortiFlex portal
6. Test network connectivity from Lambda to `https://support.fortinet.com`

#### Hybrid Licensing: Secondary ASG Scales Before Primary Exhausted

**Symptoms**: PAYG instances launch while primary ASG has available capacity

**Causes**:
- CloudWatch alarm thresholds misconfigured
- Alarm evaluation periods too short
- ASG cooldown periods insufficient
- Stale CloudWatch metrics

**Resolution**:
1. Review CloudWatch alarm configurations for both ASGs
2. Increase primary ASG alarm threshold (e.g., 60% → 70%)
3. Lower secondary ASG alarm threshold (e.g., 75% → 80%)
4. Extend alarm evaluation periods to 3-5 minutes
5. Implement alarm dependencies (secondary alarm checks primary ASG size)

#### License Not Applied After Instance Boot

**Symptoms**: Instance operational but running in limited mode or showing expired license

**Causes**:
- User-data script failed during execution
- License injection command syntax error
- Network connectivity issues during boot
- FortiGate version mismatch with license

**Resolution**:
1. SSH to FortiGate instance and check status: `get system status`
2. Review user-data execution logs: `/var/log/cloud-init-output.log`
3. Manually inject license:
   - BYOL: `execute restore config tftp <license.lic> <tftp_server>`
   - FortiFlex: `execute vm-license <TOKEN>`
4. Verify network connectivity: `execute ping fortiguard.com`
5. Check FortiOS version compatibility with license type

---

## Additional Resources

### Official Documentation
- **FortiFlex Administration Guide**: [docs.fortinet.com](https://docs.fortinet.com) (search "FortiFlex")
- **FortiGate-VM Licensing Guide**: [docs.fortinet.com/document/fortigate-vm/](https://docs.fortinet.com/document/fortigate-vm/)
- **AWS Marketplace FortiGate Listings**: [AWS Marketplace](https://aws.amazon.com/marketplace/seller-profile?id=a979b519-0d9d-4a0b-b177-b00ff8204222)

### Tools & Calculators
- **FortiFlex Points Calculator**: [fndn.fortinet.net/index.php?/tools/fortiflex/](https://fndn.fortinet.net/index.php?/tools/fortiflex/)
- **AWS Pricing Calculator**: [calculator.aws](https://calculator.aws) (for PAYG cost estimation)

### Support Channels
- **FortiCare Portal**: [support.fortinet.com](https://support.fortinet.com)
- **FortiFlex Portal**: FortiCare > Services > Assets & Accounts > FortiFlex
- **Technical Support**: Open support ticket for licensing issues
- **Sales Team**: Contact for enterprise licensing agreements or volume discounts

---

## Summary

Choosing the appropriate licensing model for your FortiGate autoscale deployment requires careful evaluation of deployment duration, traffic patterns, operational complexity tolerance, and budget constraints. This template supports all licensing models and hybrid configurations, enabling you to optimize costs while maintaining the flexibility to adapt to changing requirements.

**Quick Selection Guide**:
- **PAYG**: Simplicity matters more than cost; short-term or highly variable workloads
- **BYOL**: Lowest cost for long-term, predictable capacity; you have existing licenses
- **FortiFlex**: Balance of flexibility and cost; dynamic workloads without upfront licenses
- **Hybrid**: Best cost optimization; combine baseline BYOL/FortiFlex with PAYG burst capacity
