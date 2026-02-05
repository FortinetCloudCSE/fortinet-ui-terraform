---
title: "HA Pair Template"
chapter: false
menuTitle: "HA Pair"
weight: 61
---

## Introduction

The **ha_pair** template deploys a FortiGate Active-Passive High Availability pair using FortiGate Clustering Protocol (FGCP) in AWS. Unlike the autoscale_template which uses Gateway Load Balancer for elastic scaling, the HA Pair provides a fixed-capacity deployment with native FortiOS failover capabilities.

### Key Features

- **Active-Passive HA**: One FortiGate active, one standby with automatic failover
- **Session Synchronization**: Maintains TCP sessions during failover for stateful inspection
- **FGCP (FortiGate Clustering Protocol)**: Industry-standard clustering with unicast heartbeat
- **AWS Native Failover**: Automatic EIP and ENI reassignment via AWS API
- **No GWLB Required**: Uses native AWS routing without additional load balancer costs
- **VPC Endpoint**: Private AWS API access for failover operations
- **Transit Gateway Integration**: Automatic TGW route table updates

---

## Prerequisites

{{% notice warning %}}
The ha_pair template **requires** existing_vpc_resources to be deployed first with **HA Pair Deployment mode enabled**.
{{% /notice %}}

Before deploying the ha_pair template:

1. Deploy [existing_vpc_resources](../3_1_existing_vpc_resources/) template
2. Set `enable_ha_pair_deployment = true` in existing_vpc_resources configuration
3. Verify HA sync subnets were created (indices 10 & 11 in inspection VPC)
4. Note the `cp` and `env` values - they must match in ha_pair configuration

---

## Architecture Overview

**DIAGRAM PLACEHOLDER: "ha-pair-architecture"**
```
Show complete HA Pair architecture:
- Management VPC (top) with FortiManager, FortiAnalyzer, Jump Box
- Transit Gateway (center) connecting Management, Inspection, East, West VPCs
- Inspection VPC (main focus):
  * Primary FortiGate in AZ1 with 4 interfaces:
    - Port1: Untrusted (public subnet)
    - Port2: Trusted (private subnet)
    - Port3: HA Sync (HA sync subnet)
    - Port4: Management (management subnet OR combined with port3)
  * Secondary FortiGate in AZ2 with same interface layout
  * VPC Endpoint in HA sync subnets
  * Cluster EIP that moves on failover
  * Route tables showing traffic flow
- East/West Spoke VPCs with Linux instances generating traffic
- Arrows showing:
  * Heartbeat between FortiGates over port3
  * Traffic flow: Spoke --> TGW --> Primary FGT --> Internet
  * Failover: EIP reassignment, route table updates
```

### Network Interfaces

Each FortiGate in the HA pair has four network interfaces:

| Interface | Purpose | Subnet | EIP |
|-----------|---------|--------|-----|
| **Port1** (eth0) | Untrusted/External | Public subnet | Per-instance EIP |
| **Port2** (eth1) | Trusted/Internal | Private subnet | No EIP |
| **Port3** (eth2) | HA Sync + Management* | HA sync subnet | Optional (management access) |
| **Port4** (eth3) | Dedicated Management* | Management subnet | Optional (management access) |

*\*Depending on management configuration: Port3 can handle both HA sync and management, or Port4 can be dedicated management*

### High Availability Components

**HA Sync Subnets:**
- Created by existing_vpc_resources (indices 10 & 11)
- One subnet in each AZ for HA pair
- Route tables with IGW routes for AWS API access
- VPC endpoint for private AWS EC2 API calls

**Failover Mechanism:**
1. Primary FortiGate monitors secondary via unicast heartbeat (port3)
2. On primary failure, secondary detects loss of heartbeat
3. Secondary calls AWS EC2 API via VPC endpoint
4. AWS reassigns cluster EIP to secondary's port1
5. AWS updates route table entries to point to secondary's ENIs
6. Session tables remain synchronized (stateful failover)

**IAM Permissions:**
- AssociateAddress / DisassociateAddress (for EIP reassignment)
- ReplaceRoute / CreateRoute / DeleteRoute (for route table updates)
- DescribeInstances / DescribeRouteTables (for discovery)

---

## Deployment Modes

### Management Options

The ha_pair template supports three management configurations:

#### 1. Combined HA Sync + Management (Default)
- Port3 handles both HA heartbeat and management traffic
- Simplest configuration
- Optional EIP on port3 for internet-based management

#### 2. Dedicated Management ENI in Inspection VPC
- Port3: HA sync only
- Port4: Dedicated management in inspection VPC management subnets
- Better security isolation
- Optional EIP on port4

#### 3. Dedicated Management VPC
- Port3: HA sync only
- Port4: Dedicated management in separate management VPC
- Maximum security isolation
- Requires existing_vpc_resources to create management VPC
- Optional EIP on port4

### Internet Access Modes

#### EIP Mode (Default)
- Each FortiGate gets public IPs on port1 (untrusted interface)
- Cluster EIP moves to active instance on failover
- Direct internet access from FortiGates

#### NAT Gateway Mode
- Centralized egress through AWS NAT Gateways
- No public IPs on FortiGate port1
- Requires NAT Gateways created by existing_vpc_resources
- Better for predictable source IPs

---

## Configuration Parameters

### Required Variables

These variables **must** be configured:

| Variable | Description | Example |
|----------|-------------|---------|
| `cp` | Customer prefix (must match existing_vpc_resources) | `"acme"` |
| `env` | Environment name (must match existing_vpc_resources) | `"test"` |
| `aws_region` | AWS region | `"us-west-2"` |
| `availability_zone_1` | First AZ letter | `"a"` |
| `availability_zone_2` | Second AZ letter | `"c"` |
| `keypair` | EC2 key pair name | `"my-keypair"` |
| `fortigate_admin_password` | FortiGate admin password | `"SecureP@ssw0rd!"` |
| `ha_password` | HA heartbeat password | `"HASecretPass!"` |

### Licensing Variables

Choose ONE licensing mode:

**PAYG (Pay-As-You-Go):**
```hcl
license_type = "payg"
# No additional variables needed
```

**BYOL (Bring Your Own License):**
```hcl
license_type = "byol"
fgt_primary_license_file = "/path/to/primary.lic"
fgt_secondary_license_file = "/path/to/secondary.lic"
```

**FortiFlex:**
```hcl
license_type = "fortiflex"
fortiflex_token = "your-fortiflex-token"
```

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `fortigate_instance_type` | `"c5n.xlarge"` | EC2 instance type (c5n.xlarge or larger recommended) |
| `fortios_version` | `"7.4.5"` | FortiOS version to deploy |
| `enable_management_eip` | `true` | Associate EIP with management interface |
| `enable_fortimanager` | `false` | Register with FortiManager |
| `fortimanager_ip` | `""` | FortiManager private IP |
| `enable_fortianalyzer` | `false` | Send logs to FortiAnalyzer |
| `fortianalyzer_ip` | `""` | FortiAnalyzer private IP |
| `access_internet_mode` | `"eip"` | Internet access: "eip" or "nat_gw" |
| `update_tgw_routes` | `true` | Update TGW route tables automatically |

---

## Documentation Sections

This documentation is organized into the following sections:

- **[Deployment Guide](3_2_manual_deployment/)** - Step-by-step deployment workflow
- **[Operations & Testing](3_3_operations/)** - Testing, validation, and maintenance procedures
- **[Troubleshooting & Comparison](3_4_troubleshooting/)** - Troubleshooting, cost optimization, and HA vs AutoScale comparison
