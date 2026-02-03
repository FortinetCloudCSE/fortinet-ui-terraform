---
title: "Post-Deployment Configuration"
chapter: false
menuTitle: "Configuration"
weight: 532
---

## Post-Deployment Configuration

### Configure TGW Route Tables

If you enabled `enable_tgw_attachment = true`, configure Transit Gateway route tables to route traffic through inspection VPC:

#### For Centralized Egress

**Spoke VPC route table** (route internet traffic to inspection VPC):
```bash
# Get inspection VPC TGW attachment ID
INSPECT_ATTACH_ID=$(aws ec2 describe-transit-gateway-attachments \
  --filters "Name=resource-type,Values=vpc" \
           "Name=tag:Name,Values=*inspection*" \
  --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' \
  --output text)

# Add default route to spoke route table
aws ec2 create-transit-gateway-route \
  --destination-cidr-block 0.0.0.0/0 \
  --transit-gateway-route-table-id <spoke-rt-id> \
  --transit-gateway-attachment-id $INSPECT_ATTACH_ID
```

**Inspection VPC route table** (route spoke traffic to internet):
```bash
# This is typically configured automatically by the template
# Verify it exists:
aws ec2 describe-transit-gateway-route-tables \
  --transit-gateway-route-table-ids <inspection-rt-id>
```

#### For East-West Inspection

If you enabled `enable_east_west_inspection = true`:

**Spoke-to-spoke traffic** routes through inspection VPC automatically.

**Verify routing**:
```bash
# From east spoke instance
ssh ec2-user@<east-linux-ip>
ping <west-linux-ip>  # Should succeed and be inspected by FortiGate

# Check FortiGate logs
diagnose debug flow trace start 10
diagnose debug enable
# Generate traffic and watch logs
```

### Configure FortiGate Policies

Access FortiGate GUI and configure firewall policies:

#### Basic Internet Egress Policy

```
Policy & Objects > Firewall Policy > Create New

Name: Internet-Egress
Incoming Interface: port1 (or TGW interface)
Outgoing Interface: port2 (internet interface)
Source: all
Destination: all
Service: ALL
Action: ACCEPT
NAT: Enable
Logging: All Sessions
```

#### East-West Inspection Policy

```
Policy & Objects > Firewall Policy > Create New

Name: East-West-Inspection
Incoming Interface: port1 (TGW interface)
Outgoing Interface: port1 (TGW interface)
Source: 192.168.0.0/16
Destination: 192.168.0.0/16
Service: ALL
Action: ACCEPT
NAT: Disable
Logging: All Sessions
Security Profiles: Enable IPS, Application Control, etc.
```

### Configure FortiManager (If Enabled)

1. **Authorize FortiGate device**:
   - Device Manager > Device & Groups
   - Right-click unauthorized device > Authorize
   - Assign to ADOM

2. **Create policy package**:
   - Policy & Objects > Policy Package
   - Create new package
   - Add firewall policies

3. **Install policy**:
   - Select device
   - Policy & Objects > Install
   - Select package
   - Click Install

4. **Verify sync to secondary instances**:
   - Check secondary FortiGate instances
   - Policies should appear automatically via HA sync

---

