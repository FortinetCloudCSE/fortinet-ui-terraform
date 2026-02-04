---
title: "Configuration Scenarios"
menuTitle: "Configuration Scenarios"
weight: 2
---

## Configuration Scenarios

### Scenario 1: Complete Lab Environment with AutoScale

**Use case**: Full-featured lab for testing AutoScale capabilities

```hcl
# Deployment Mode Selection (REQUIRED - Choose One)
enable_autoscale_deployment = true
enable_ha_pair_deployment   = false

# Management VPC Components
enable_build_management_vpc    = true
enable_fortimanager            = true
enable_fortianalyzer           = true
enable_jump_box                = true
enable_mgmt_vpc_tgw_attachment = true

# Spoke VPC Components
enable_build_existing_subnets  = true
enable_east_linux_instances    = true
enable_west_linux_instances    = true
enable_debug_tgw_attachment    = true
```

**What you get**: Complete environment with management, spoke VPCs, traffic generators, and debug path configured for AutoScale deployment

**Cost**: ~$300-400/month

**Best for**: Training, demonstrations, comprehensive AutoScale testing

**Next step**: Deploy [autoscale_template](../5_3_autoscale_template/)

---

### Scenario 1b: Complete Lab Environment with HA Pair

**Use case**: Full-featured lab for testing HA Pair capabilities

```hcl
# Deployment Mode Selection (REQUIRED - Choose One)
enable_autoscale_deployment = false
enable_ha_pair_deployment   = true

# Management VPC Components
enable_build_management_vpc    = true
enable_fortimanager            = true
enable_fortianalyzer           = true
enable_jump_box                = true
enable_mgmt_vpc_tgw_attachment = true

# Spoke VPC Components
enable_build_existing_subnets  = true
enable_east_linux_instances    = true
enable_west_linux_instances    = true
enable_debug_tgw_attachment    = true
```

**What you get**: Complete environment with management, spoke VPCs, traffic generators, and debug path configured for HA Pair deployment

**Cost**: ~$300-400/month

**Best for**: Training, demonstrations, comprehensive HA Pair testing

**Next step**: Deploy [ha_pair template](../5_4_ha_pair/)

---

### Scenario 2: Management VPC Only (AutoScale)

**Use case**: Testing FortiManager/FortiAnalyzer integration with AutoScale without spoke VPCs

```hcl
# Deployment Mode Selection (REQUIRED - Choose One)
enable_autoscale_deployment = true
enable_ha_pair_deployment   = false

# Management VPC Components
enable_build_management_vpc    = true
enable_fortimanager            = true
enable_fortianalyzer           = true
enable_jump_box                = false
enable_mgmt_vpc_tgw_attachment = false

# Spoke VPC Components
enable_build_existing_subnets  = false
```

**What you get**: Management VPC with FortiManager and FortiAnalyzer configured for AutoScale deployment

**Cost**: ~$200/month

**Best for**: FortiManager/FortiAnalyzer integration testing with autoscale_template

**Next step**: Deploy [autoscale_template](../5_3_autoscale_template/) with FortiManager integration

---

### Scenario 3: Traffic Generation Only (AutoScale)

**Use case**: Testing AutoScale with traffic generators, no management VPC

```hcl
# Deployment Mode Selection (REQUIRED - Choose One)
enable_autoscale_deployment = true
enable_ha_pair_deployment   = false

# Management VPC Components
enable_build_management_vpc    = false

# Spoke VPC Components
enable_build_existing_subnets  = true
enable_east_linux_instances    = true
enable_west_linux_instances    = true
enable_debug_tgw_attachment    = false
```

**What you get**: Transit Gateway and spoke VPCs with Linux instances configured for AutoScale deployment

**Cost**: ~$100-150/month

**Best for**: AutoScale behavior testing, load testing, capacity planning

**Next step**: Deploy [autoscale_template](../5_3_autoscale_template/)

---

### Scenario 4: Minimal Test Environment (HA Pair)

**Use case**: Lowest cost configuration for basic HA Pair connectivity testing

```hcl
# Deployment Mode Selection (REQUIRED - Choose One)
enable_autoscale_deployment = false
enable_ha_pair_deployment   = true

# Management VPC Components
enable_build_management_vpc    = true
enable_fortimanager            = false
enable_fortianalyzer           = false
enable_jump_box                = true
enable_mgmt_vpc_tgw_attachment = true

# Spoke VPC Components
enable_build_existing_subnets  = true
enable_east_linux_instances    = true
enable_west_linux_instances    = false
enable_debug_tgw_attachment    = true
```

**What you get**: Management VPC with jump box, TGW, one spoke VPC with traffic generator, debug path, configured for HA Pair deployment

**Cost**: ~$60-80/month

**Best for**: Cost-sensitive testing, basic HA Pair connectivity validation

**Next step**: Deploy [ha_pair template](../5_4_ha_pair/)

---
