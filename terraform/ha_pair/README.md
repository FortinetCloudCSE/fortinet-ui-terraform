# FortiGate HA Pair Template

This template deploys a FortiGate High Availability (HA) pair in AWS using FGCP (FortiGate Clustering Protocol).

## Overview

The HA pair provides:
- **Active-Passive HA**: One FortiGate is active, the other is on standby
- **Fast Failover**: FortiGates monitor each other and trigger AWS API calls to reassign ENIs and EIPs on failover
- **Session Synchronization**: Session tables are synchronized between instances for stateful failover
- **Dual-AZ Deployment**: Primary in AZ1, Secondary in AZ2 for availability zone redundancy

## Architecture

### Network Interfaces (2-arm mode):
- **Port1** (Untrusted): Public/external interface in inspection VPC public subnets
- **Port2** (Trusted): Private/internal interface in inspection VPC private subnets
- **Port3** (HA Sync): Heartbeat and session sync interface OR combined sync+management
- **Port4** (Management): Dedicated management interface (optional)

### Management Options:
1. **Combined Sync+Management**: Port3 handles both HA sync and management (EIP optional)
2. **Dedicated Management in Inspection VPC**: Port3=sync, Port4=management in inspection VPC management subnets
3. **Dedicated Management VPC**: Port3=sync, Port4=management in separate management VPC

## Prerequisites

**IMPORTANT**: Deploy `existing_vpc_resources` template first!

The HA pair template discovers existing resources created by `existing_vpc_resources`:
- Inspection VPC and subnets (public, private, HA sync)
- Management VPC and subnets (if using dedicated management VPC)
- Transit Gateway (if enabled)
- FortiManager/FortiAnalyzer instances (if deployed)
- Internet Gateway and NAT Gateways

## Deployment Steps

### 1. Configure Variables

Copy the example file and customize:
```bash
cd terraform/ha_pair
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values. Key variables:
- `cp` and `env` - Must match existing_vpc_resources
- `keypair` - EC2 key pair for SSH access
- `fortigate_admin_password` - FortiGate admin password
- `ha_password` - HA heartbeat password
- `license_type` - payg, byol, or fortiflex
- `enable_management_eip` - true for internet-based management access

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review Plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Access FortiGates

After deployment, use the management URLs from outputs:
```bash
terraform output fortigate_primary_management_url
terraform output fortigate_secondary_management_url
```

Default credentials:
- Username: `admin`
- Password: (value you set in `fortigate_admin_password`)

## Key Features

### HA Failover

FortiGates automatically handle failover by:
1. Detecting primary failure via heartbeat (port3)
2. Secondary becomes active and calls AWS EC2 API
3. Reassigns cluster EIP to new active instance
4. Updates route tables to point to new active ENIs
5. Session tables remain synchronized (stateful failover)

### VPC Endpoint for AWS API

A VPC interface endpoint for EC2 API is created in the HA sync subnets. This allows FortiGates to make AWS API calls privately without requiring public internet access on the HA sync interface.

### IAM Role

FortiGates are assigned an IAM role with permissions to:
- Describe EC2 instances, routes, addresses
- Associate/disassociate EIPs
- Replace/create/delete routes
- Access S3 for bootstrap configs

### Licensing

Three licensing modes supported:
1. **PAYG** (Pay-As-You-Go): AWS Marketplace hourly billing
2. **BYOL** (Bring Your Own License): Upload `.lic` files
3. **FortiFlex**: Token-based licensing

## Internet Access Modes

### EIP Mode (Default)
- Each FortiGate gets public IPs on port1 (untrusted interface)
- Cluster EIP moves to active instance on failover
- Distributed egress through FortiGates

### NAT Gateway Mode
- Centralized egress through AWS NAT Gateways
- No public IPs on FortiGate untrusted interfaces
- Requires NAT Gateways created by existing_vpc_resources

## Transit Gateway Routing

### Spoke VPC Traffic Flow

When `update_tgw_routes` is enabled (default), the template automatically updates Transit Gateway routing:

**Before HA Pair Deployment (existing_vpc_resources only):**
- East/West spoke VPC default routes point to Management VPC attachment
- Allows spoke instances to bootstrap via Management VPC jump box NAT

**After HA Pair Deployment:**
- Template deletes old default routes from east/west TGW route tables
- Creates new default routes pointing to Inspection VPC attachment
- Traffic from spoke VPCs now flows through FortiGate HA pair
- Management VPC specific routes remain for ongoing management access

This two-stage approach ensures:
1. Spoke instances can successfully run cloud-init and pull packages during initial deployment
2. Traffic seamlessly shifts to FortiGates once they're ready to forward traffic
3. No manual TGW route table updates required

## Outputs

Important outputs:
- `fortigate_primary_management_url` - Primary FortiGate management URL
- `fortigate_secondary_management_url` - Secondary FortiGate management URL
- `fortigate_cluster_eip` - Cluster EIP (moves on failover)
- `fortigate_primary_port1_eni_id` - Primary port1 ENI (for route table targets)
- `fortigate_primary_port2_eni_id` - Primary port2 ENI (for route table targets)

Use ENI IDs to configure route tables in spoke VPCs to route traffic through the FortiGates.

## Files Created

- `main.tf` - Provider configuration
- `variables.tf` - Input variables
- `data_sources.tf` - Discover existing resources
- `vpc_resources.tf` - VPC endpoint for EC2 API
- `security_groups.tf` - Security groups for FortiGate interfaces
- `iam.tf` - IAM role and policy for HA failover
- `fortigate_instances.tf` - Network interfaces and EC2 instances
- `eips.tf` - Elastic IPs and associations
- `userdata.tf` - Template data sources for FortiGate configs
- `tgw_routes.tf` - Transit Gateway route table updates
- `outputs.tf` - Output values
- `config_templates/primary-fortigate-userdata.tpl` - Primary FortiGate bootstrap config
- `config_templates/secondary-fortigate-userdata.tpl` - Secondary FortiGate bootstrap config

## Troubleshooting

### Check HA Status

SSH to FortiGate and run:
```
get system ha status
```

### Test AWS API Access

```
diag test app awsd 4
```

### Debug AWS API Calls

```
diag deb app awsd -1
diag deb enable
```

To disable:
```
diag deb app awsd 0
diag deb disable
```

### Verify Cluster EIP Failover

1. Note the current active FortiGate
2. Power off or reboot the active instance
3. Watch for secondary to become active
4. Verify cluster EIP moved to new active instance
5. Check route tables updated to new active ENIs

## Notes

- FortiGates are deployed in separate AZs (primary in AZ1, secondary in AZ2)
- Interface IPs and routes are NOT synchronized (use `vdom-exception`)
- DNS server set to 169.254.169.253 (AWS intrinsic DNS) for API hostname resolution
- HA heartbeat uses unicast over port3
- Session pickup is enabled for stateful failover

## Cost Estimate

Approximate monthly costs (US regions):
- 2x FortiGate instances (c5n.xlarge): ~$150-300/month (depending on licensing)
- Cluster EIP: ~$3.60/month
- Management EIPs (if enabled): ~$7.20/month
- VPC Endpoint: ~$7.30/month + data processing
- Data transfer: Variable based on traffic

Always `terraform destroy` when done testing to avoid unnecessary costs.
