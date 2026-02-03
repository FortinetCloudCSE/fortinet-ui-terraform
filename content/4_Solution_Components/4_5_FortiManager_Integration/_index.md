---
title: "FortiManager Integration"
chapter: false
menuTitle: "FortiManager Integration"
weight: 45
---

## Overview

The template supports optional integration with FortiManager for centralized management, policy orchestration, and configuration synchronization across the autoscale group.

### Configuration

Enable FortiManager integration by setting the following variables in `terraform.tfvars`:

```hcl
enable_fortimanager_integration = true
fortimanager_ip                 = "10.0.100.50"
fortimanager_sn                 = "FMGVM0000000001"
fortimanager_vrf_select         = 1
```

---

## Variable Definitions

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `enable_fortimanager_integration` | boolean | Yes | Master switch to enable/disable FortiManager integration |
| `fortimanager_ip` | string | Yes | FortiManager IP address or FQDN accessible from FortiGate management interfaces |
| `fortimanager_sn` | string | Yes | FortiManager serial number for device registration |
| `fortimanager_vrf_select` | number | No | VRF ID for routing to FortiManager (default: 0 for global VRF) |

---

## How FortiManager Integration Works

When `enable_fortimanager_integration = true`:

1. **Lambda generates FortiOS config**: Lambda function creates `config system central-management` stanza
2. **Primary instance registration**: Only the primary FortiGate instance registers with FortiManager
3. **VDOM exception configured**: Lambda adds `config system vdom-exception` to prevent central-management config from syncing to secondaries
4. **Configuration synchronization**: Primary instance syncs configuration to secondary instances via FortiGate-native HA sync
5. **Policy deployment**: Policies deployed from FortiManager propagate through primary → secondary sync

---

## Generated FortiOS Configuration

Lambda automatically generates the following configuration on the **primary instance only**:

```
config system vdom-exception
    edit 0
        set object system.central-management
    next
end

config system central-management
    set type fortimanager
    set fmg 10.0.100.50
    set serial-number FMGVM0000000001
    set vrf-select 1
end
```

**Secondary instances** do not receive `central-management` configuration, preventing:
- Orphaned device entries on FortiManager during scale-in events
- Confusion about which instance is authoritative for policy
- Unnecessary FortiManager license consumption

---

## Network Connectivity Requirements

**FortiGate → FortiManager**:
- **TCP 541**: FortiManager to FortiGate communication (FGFM protocol)
- **TCP 514** (optional): Syslog if logging to FortiManager
- **HTTPS 443**: FortiManager GUI access for administrators

Ensure:
- Security groups allow traffic from FortiGate management interfaces to FortiManager
- Route tables provide path to FortiManager IP
- Network ACLs permit required traffic
- VRF routing configured if using non-default VRF

---

## VRF Selection

The `fortimanager_vrf_select` parameter specifies which VRF to use for FortiManager connectivity:

**Common scenarios**:
- `0` (default): Use global VRF; FortiManager accessible via default routing table
- `1` or higher: Use specific management VRF; FortiManager accessible via separate routing domain

**When to use non-default VRF**:
- FortiManager in separate management VPC requiring VPC peering or TGW
- Network segmentation requires management traffic in dedicated VRF
- Multiple VRFs configured and explicit path selection needed

---

## FortiManager 7.6.3+ Critical Requirement

{{% notice warning %}}
**CRITICAL: FortiManager 7.6.3+ Requires VM Device Recognition**

Starting with FortiManager version 7.6.3, VM serial numbers are **not recognized by default** for security purposes.

**If you deploy FortiGate-VM instances with `enable_fortimanager_integration = true` to a FortiManager 7.6.3 or later WITHOUT enabling VM device recognition, instances will FAIL to register.**

**Required Configuration on FortiManager 7.6.3+**:

Before deploying FortiGate instances, log into FortiManager CLI and enable VM device recognition:

```
config system global
    set fgfm-allow-vm enable
end
```

**Verify the setting**:
```
show system global | grep fgfm-allow-vm
```

**Important notes**:
- This configuration must be completed **BEFORE** deploying FortiGate-VM instances
- When upgrading from FortiManager < 7.6.3, existing managed VM devices continue functioning, but **new VM devices cannot be added** until `fgfm-allow-vm` is enabled
- This setting is **global** and affects **all ADOMs** on the FortiManager
- This is a **one-time** configuration change per FortiManager instance

**Verification after deployment**:
1. Navigate to **Device Manager > Device & Groups** in FortiManager GUI
2. Confirm FortiGate-VM instances appear as **unauthorized devices** (not as errors)
3. Authorize devices as normal

**Troubleshooting if instances fail to register**:
1. Check FortiManager version: `get system status`
2. If version is 7.6.3 or later, verify `fgfm-allow-vm` is enabled
3. If disabled, enable it and wait 1-5 minutes for FortiGate instances to retry registration
4. Check FortiManager logs: `diagnose debug application fgfmd -1`
{{% /notice %}}

---

## FortiManager Workflow

**After deployment**:

1. **Verify device registration**:
   - Log into FortiManager GUI
   - Navigate to **Device Manager > Device & Groups**
   - Confirm primary FortiGate instance appears as unauthorized device

2. **Authorize device**:
   - Right-click on unauthorized device
   - Select **Authorize**
   - Assign to appropriate ADOM and device group

3. **Install policy package**:
   - Create or assign policy package to authorized device
   - Click **Install** to push policies to FortiGate

4. **Verify configuration sync**:
   - Make configuration change on FortiManager
   - Install policy package to primary FortiGate
   - Verify change appears on secondary FortiGate instances via HA sync

---

## Best Practices

1. **Pre-configure FortiManager**: Create ADOMs, device groups, and policy packages before deploying autoscale group
2. **Test in non-production**: Validate FortiManager integration in dev/test environment first
3. **Monitor device status**: Set up FortiManager alerts for device disconnections
4. **Document policy workflow**: Ensure team understands FortiManager → Primary → Secondary sync pattern
5. **Plan for primary failover**: If primary instance fails, new primary automatically registers with FortiManager
6. **Backup FortiManager regularly**: Critical single point of management; ensure proper backup strategy

---

## Reference Documentation

For complete FortiManager integration details, including User Managed Scaling (UMS) mode, see the project file: [FortiManager Integration Configuration](/mnt/project/fmg_integration_configuration.md)

---

## Next Steps

After configuring FortiManager integration, proceed to [Autoscale Group Capacity](../4_6_autoscale_group_capacity/) to configure instance counts and scaling behavior.
