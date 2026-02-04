---
title: "Operations & Testing"
menuTitle: "Operations"
weight: 3
---

## Transit Gateway Routing

### Two-Stage Routing Approach

The ha_pair template implements automatic TGW route updates:

**Stage 1: After existing_vpc_resources deployment**
- East/West spoke VPC default routes --> Management VPC attachment
- Allows spoke instances to bootstrap via jump box NAT

**Stage 2: After ha_pair deployment**
- ha_pair template deletes old default routes from east/west TGW route tables
- Creates new default routes --> Inspection VPC attachment
- Traffic now flows through FortiGate HA pair
- Management VPC routes remain for ongoing access

This two-stage approach is handled automatically by `tgw_routes.tf`.

To **disable** automatic TGW route updates:
```hcl
update_tgw_routes = false
```

---

## Testing and Validation

### Test Traffic Flow

From a spoke VPC Linux instance:

```bash
# SSH to Linux instance in east or west spoke VPC
ssh -i ~/.ssh/keypair.pem ec2-user@<linux-ip>

# Test internet connectivity
curl -I https://www.fortinet.com

# Test cross-VPC connectivity
ping <other-spoke-instance-ip>

# Generate sustained traffic
ab -n 10000 -c 100 http://<other-spoke-instance-ip>/
```

### Monitor on FortiGate

```bash
# SSH to primary FortiGate
ssh admin@<primary-management-ip>

# View real-time sessions
diag sys session list

# View traffic logs
execute log filter category traffic
execute log display

# View HA sync status
get system ha status
diagnose sys ha status
```

### Test Failover

**Manual Failover Test:**

```bash
# SSH to primary FortiGate
ssh admin@<primary-management-ip>

# Trigger failover
execute ha manage ?
execute ha manage 1 admin  # Switch to secondary

# Or simulate failure
config system ha
    set priority 1  # Lower than secondary
end
```

**Verify Failover:**
1. Secondary becomes active
2. Cluster EIP moves to secondary
3. Route tables update to secondary ENIs
4. Sessions maintained (check with `diag sys session list`)
5. Traffic continues flowing

**Failover Time:** Typically 30-60 seconds

---

## Maintenance Operations

### Upgrading FortiOS

{{% notice warning %}}
Upgrade secondary first, then primary to minimize downtime.
{{% /notice %}}

**Procedure:**

1. **Upgrade Secondary:**
```bash
# SSH to secondary
ssh admin@<secondary-management-ip>

# Upload firmware
execute restore image tftp <firmware-file> <tftp-server>

# Secondary will reboot, remain in standby
```

2. **Verify Secondary:**
```bash
# After reboot, verify version
get system status | grep Version

# Verify HA status
get system ha status
```

3. **Failover to Secondary:**
```bash
# SSH to primary
execute ha manage 1 admin
# Traffic now flows through upgraded secondary
```

4. **Upgrade Former Primary:**
```bash
# SSH to new secondary (former primary)
execute restore image tftp <firmware-file> <tftp-server>
```

5. **Verify Both Running Same Version:**
```bash
get system ha status
# Check both running same FortiOS version
```

### Scaling Instance Size

To change instance type (e.g., c5n.xlarge --> c5n.2xlarge):

```bash
# Edit terraform.tfvars
fortigate_instance_type = "c5n.2xlarge"

# Apply changes
terraform apply
# Terraform will recreate instances one at a time
# HA pair maintains service during recreation
```

### Adding FortiManager Integration

```bash
# Edit terraform.tfvars
enable_fortimanager = true
fortimanager_ip = "10.3.0.10"

# Apply changes
terraform apply

# Authorize on FortiManager
# Device Manager > Device & Groups > Right-click > Authorize
```

---
