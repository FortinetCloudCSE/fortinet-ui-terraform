---
title: "Primary Scale-In Protection"
chapter: false
menuTitle: "Primary Scale-In Protection"
weight: 47
---

## Overview

Protect the primary FortiGate instance from scale-in events to maintain configuration synchronization stability and prevent unnecessary primary elections.

### Configuration

![Scale-in Protection](../scale-in-protection.png)

```hcl
primary_scalein_protection = true
```

---

## Why Protect the Primary Instance?

In FortiGate autoscale architecture:
- **Primary instance**: Elected leader responsible for configuration management and HA sync
- **Secondary instances**: Receive configuration from primary via FortiGate-native HA synchronization

**Without scale-in protection**:
1. AWS autoscaling may select primary instance for termination during scale-in
2. Remaining instances must elect new primary
3. Configuration may be temporarily unavailable during election
4. Potential for configuration loss if primary was processing updates

**With scale-in protection**:
1. AWS autoscaling only terminates secondary instances
2. Primary instance remains stable unless it is the last instance
3. Configuration synchronization continues uninterrupted
4. Predictable autoscale group behavior

---

## How It Works

The `primary_scalein_protection` variable is passed through to the autoscale group configuration:

![Scale-in Passthru 1](../scale-in-passthru-1.png)

In the underlying Terraform module (`autoscale_group.tf`):

![Scale-in Passthru 2](../scale-in-passthru-2.png)

AWS autoscaling respects the protection attribute and **never** selects protected instances for scale-in events.

---

## Verification

You can verify scale-in protection in the AWS Console:

1. Navigate to **EC2 > Auto Scaling Groups**
2. Select your autoscale group
3. Click **Instance management** tab
4. Look for **Scale-in protection** column showing "Protected" for primary instance

---

## When Protection is Removed

Scale-in protection automatically removes when:
- Instance is the **last remaining** instance in the ASG (respecting `min_size`)
- Manual termination via AWS Console or API (protection can be overridden)
- Autoscale group is deleted

---

## Best Practices

1. **Always enable for production**: Set `primary_scalein_protection = true` for production deployments
2. **Consider disabling for dev/test**: Development environments may not require protection
3. **Monitor primary health**: Protected instances still fail health checks and can be replaced
4. **Document protection status**: Ensure operations teams understand why primary instance is protected

---

## AWS Documentation Reference

For more information on AWS autoscaling instance protection:
- [Using AWS Autoscale Scale-in Protection](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-instance-protection.html)

---

## Next Steps

After configuring primary protection, review [Additional Configuration Options](../4_8_additional_configuration/) for fine-tuning instance specifications and advanced settings.
