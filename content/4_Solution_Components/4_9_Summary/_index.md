---
title: "Solution Components Summary"
chapter: false
menuTitle: "Summary"
weight: 49
---

## Overview

This summary provides a comprehensive reference of all solution components covered in this section, with quick decision guides and configuration references.

---

## Component Quick Reference

### 1. Internet Egress Options

| Option | Hourly Cost | Data Processing | Monthly Cost (2 AZs) | Source IP | Best For |
|--------|-------------|-----------------|----------------------|-----------|----------|
| **EIP Mode** | $0.005/IP | None | ~$7.20 | Variable | Cost-sensitive, dev/test |
| **NAT Gateway** | $0.045/NAT × 2 | $0.045/GB | ~$65 base + data† | Stable | Production, compliance |

† **Data processing example**: 1 TB/month = $45 additional cost  
**Total NAT Gateway cost estimate**: $65 (base) + $45 (1TB data) = **$110/month** for 2 AZs with 1TB egress

```hcl
access_internet_mode = "eip"  # or "nat_gw"
```

**Key Decision**: Do you need predictable source IPs for allowlisting (white-listing)?
- Yes → NAT Gateway (stable IPs, higher cost)
- No → EIP (variable IPs, lower cost)

---

### 2. Firewall Architecture

| Mode | Interfaces | Complexity | Best For |
|------|------------|------------|----------|
| **2-ARM** | port1 + port2 | Higher | Production, clear segmentation |
| **1-ARM** | port1 only | Lower | Simplified routing |

```hcl
firewall_policy_mode = "2-arm"  # or "1-arm"
```

---

### 3. Management Isolation

**Three progressive levels:**
1. **Combined (Default)**: Port2 serves data + management
2. **Dedicated ENI**: Port2 dedicated to management only
3. **Dedicated VPC**: Complete physical network separation

```hcl
enable_dedicated_management_eni = true
enable_dedicated_management_vpc = true
```

---

### 4. Licensing Options

| Model | Best For | Cost (12 months) | Management |
|-------|----------|------------------|------------|
| **BYOL** | Long-term, predictable | Lowest | License files |
| **FortiFlex** | Variable, flexible | Medium | API-driven |
| **PAYG** | Short-term, simple | Highest | None required |

**Hybrid Strategy** (Recommended): BYOL baseline + PAYG burst

---

### 5. FortiManager Integration

```hcl
enable_fortimanager_integration = true
fortimanager_ip                 = "10.0.100.50"
fortimanager_sn                 = "FMGVM0000000001"
```

**⚠️ Critical**: FortiManager 7.6.3+ requires `fgfm-allow-vm` enabled before deployment

---

### 6. Autoscale Group Capacity

```hcl
asg_byol_asg_min_size = 2
asg_byol_asg_max_size = 4
asg_ondemand_asg_max_size = 4
```

**Formula**: `Capacity = (Peak Gbps / Per-Instance Gbps) × 1.2`

---

### 7. Primary Scale-In Protection

```hcl
primary_scalein_protection = true
```

Always enable for production to prevent primary instance termination during scale-in.

---

### 8. Additional Configuration

```hcl
fgt_instance_type               = "c6i.xlarge"
fortios_version                 = "7.4.5"
fortigate_gui_port              = 443
allow_cross_zone_load_balancing = true
keypair_name                    = "my-fortigate-keypair"
```

---

## Common Deployment Patterns

### Pattern 1: Production with Maximum Isolation

```hcl
access_internet_mode = "nat_gw"
firewall_policy_mode = "2-arm"
enable_dedicated_management_eni = true
enable_dedicated_management_vpc = true
asg_license_directory = "asg_license"
enable_fortimanager_integration = true
primary_scalein_protection = true
```

**Use case**: Enterprise production, compliance-driven

---

### Pattern 2: Development and Testing

```hcl
access_internet_mode = "eip"
firewall_policy_mode = "1-arm"
asg_ondemand_asg_min_size = 1
asg_ondemand_asg_max_size = 2
enable_fortimanager_integration = false
```

**Use case**: Development, testing, POC

---

### Pattern 3: Balanced Production

```hcl
access_internet_mode = "nat_gw"
firewall_policy_mode = "2-arm"
enable_dedicated_management_eni = true
fortiflex_username = "your-api-username"
enable_fortimanager_integration = true
primary_scalein_protection = true
```

**Use case**: Standard production, flexible licensing

---

## Decision Tree

```
1. Do you need predictable source IPs for allowlisting?
   ├─ Yes → NAT Gateway (~$110/month for 2 AZs + 1TB data)
   └─ No → EIP (~$7/month)

2. Dedicated management interface?
   ├─ Yes → 2-ARM + Dedicated ENI
   └─ No → 1-ARM

3. Complete management isolation?
   ├─ Yes → Dedicated Management VPC
   └─ No → Dedicated ENI or skip

4. Licensing model?
   ├─ Long-term (12+ months) → BYOL
   ├─ Variable workload → FortiFlex
   ├─ Short-term (< 3 months) → PAYG
   └─ Best optimization → BYOL + PAYG hybrid

5. Centralized policy management?
   ├─ Yes → Enable FortiManager
   └─ No → Standalone

6. Production deployment?
   ├─ Yes → Enable primary scale-in protection
   └─ No → Optional
```

---

## Pre-Deployment Checklist

**Infrastructure**:
- [ ] AWS account with permissions
- [ ] VPC architecture designed
- [ ] Subnet CIDR planning complete
- [ ] Transit Gateway configured (if needed)

**Licensing**:
- [ ] BYOL: License files ready (≥ max_size)
- [ ] FortiFlex: Program registered, API credentials
- [ ] PAYG: Marketplace subscription accepted

**FortiManager** (if applicable):
- [ ] FortiManager deployed and accessible
- [ ] FortiManager 7.6.3+: `fgfm-allow-vm` enabled
- [ ] ADOMs and device groups created
- [ ] Network connectivity verified

**Configuration**:
- [ ] `terraform.tfvars` populated
- [ ] SSH key pair created
- [ ] Resource tags defined
- [ ] Instance type selected

---

## Troubleshooting Quick Reference

| Issue | Check |
|-------|-------|
| No internet connectivity | Route tables, IGW, NAT GW, EIP |
| Management inaccessible | Security groups, routing, EIP |
| License not activating | Lambda logs, S3, DynamoDB, FortiFlex API |
| FortiManager registration fails | `fgfm-allow-vm`, network, serial number |
| Scaling not working | CloudWatch alarms, ASG health checks |
| Primary terminated | Verify protection enabled |

---

## Next Steps

**Proceed to [Templates](../../5_templates/)** for step-by-step deployment procedures.

---

## Additional Resources

- [Fortinet Documentation](https://docs.fortinet.com)
- [FortiFlex Setup Guide](/mnt/project/FortiFlex_Setup_Guide.md)
- [FortiManager Integration](/mnt/project/fmg_integration_configuration.md)
- [Terraform Module Repository](https://github.com/fortinetdev/terraform-aws-cloud-modules)
