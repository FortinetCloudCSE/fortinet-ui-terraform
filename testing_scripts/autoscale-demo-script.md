# FortiGate Autoscale Demo - Video Script (~11 minutes)

## Overview

This script demonstrates FortiGate autoscaling with AWS Gateway Load Balancer, showing:
- Configuration sync before traffic (port 8008 probe-response)
- Zero dropped connections during scale-out
- Graceful connection draining during scale-in

---

## [0:00 - 1:15] Opening - The Problem & Configuration Fix

**On Screen:** Title card "FortiGate Autoscale with AWS Gateway Load Balancer"

**Narration:**

> "Today we're demonstrating FortiGate autoscaling with AWS Gateway Load Balancer. But first, let me explain a problem we encountered - and how we solved it.
>
> In our initial testing, secondary FortiGates were receiving traffic before their configuration had synced. The GWLB health check was using port 80, which responds as soon as FortiOS boots - before the Lambda function delivers the configuration.
>
> We made three changes to fix this:"

**On Screen:** Show Terraform configuration

```hcl
# terraform.tfvars

# GWLB Health Check - use FortiGate probe-response port
gwlb_health_check_port     = 8008    # Was: 80
gwlb_health_check_interval = 60      # Was: 30
gwlb_healthy_threshold     = 5       # Was: 3

# ASG Health Check Grace Period
asg_health_check_grace_period = 700  # Was: 300
```

**Narration:**

> "**Port 8008** is the FortiGate probe-response port. Unlike port 80, this only responds after Lambda delivers the userdata configuration."

**On Screen:** Show FortiGate probe-response config

```
config system probe-response
    set mode http-probe
    set port 8008
    set http-probe-value "OK"
end
config system interface
    edit port1
        set allowaccess ping https probe-response
    next
end
```

> "The probe-response is configured in the FortiGate userdata template. It responds with 'OK' on port 8008 - but only after this configuration is applied. No userdata, no response, no healthy status.
>
> **The health check timing**: 5 checks at 60-second intervals means 5 minutes before an instance can be marked healthy. Combined with the 700-second grace period, AWS won't terminate the instance for failing health checks during the sync window.
>
> Now let me show you this working correctly..."

---

## [1:15 - 2:30] Panel Layout Introduction

**On Screen:** Show 4 terminals arranged in a grid

**Narration:**

> "We have four monitoring panels open. Let me describe each one."

### Panel 1 - Top Left: iperf Servers

```
+------------------+------------------+
| West AZ2 iperf3  | East AZ1 iperf3  |
| server (-s)      | server (-s)      |
+------------------+------------------+
```

> "Top left shows our iperf3 servers. We have two servers listening - one in West AZ2 and one in East AZ1. These receive traffic that traverses through the FortiGates via the Transit Gateway."

### Panel 2 - Top Right: iperf Clients

```
+------------------+------------------+
| West AZ1 client  | East AZ2 client  |
| -> East AZ1      | -> West AZ2      |
+------------------+------------------+
```

> "Top right shows our iperf3 clients. West AZ1 sends traffic to East AZ1, and East AZ2 sends to West AZ2. This cross-VPC traffic must traverse the inspection VPC where our FortiGates sit."

### Panel 3 - Bottom Left: ASG & GWLB Monitor

```bash
./monitor_asg.sh -w
```

> "Bottom left runs our ASG monitor script. This shows instance state, GWLB target health, and the role assignment - Primary or Secondary. We'll SSH to the FortiGates directly to verify policy sync."

### Panel 4 - Bottom Right: FortiGate CPU Monitor

```
diag sys mpstat 1
```

> "Bottom right shows real-time CPU utilization on the primary FortiGate using `diagnose sys mpstat 1`, which refreshes every second. This is how we'll trigger the scale-out - by driving CPU above the scaling threshold."

---

## [2:30 - 3:30] Initial State - Single FortiGate

**On Screen:** Focus on ASG monitor panel

**Narration:**

> "Let's look at our starting state. We have a single FortiGate instance running - this is our Primary."

**Highlight ASG monitor output:**

```
ASG: acme-test-fgt_on_demand_asg
  Capacity: 1 running | Desired: 1 | Min: 1 | Max: 4

  Instance ID          State        Private IP       Public IP        Health     Role
  i-0abc123def456...   running      10.0.20.10       54.x.x.x        healthy    Primary

GWLB Target Group Health
    Instance              State        Reason
    i-0abc123def456...    healthy      N/A
```

> "Notice the GWLB Target Group shows 'healthy'. The ASG shows desired capacity of 1, with a maximum of 4. The primary FortiGate holds the master configuration. When secondary instances launch, they'll sync this configuration before receiving traffic."

---

## [3:30 - 5:00] Start Traffic Generation

**On Screen:** Focus on iperf client panel, then FortiGate mpstat

**Narration:**

> "Now let's start our traffic. The iperf clients are running in a loop with 10-second test intervals."

**Show client output:**

```
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-2.00   sec  4.25 MBytes  17.0 Mbits/sec
[  5]   2.00-4.00   sec  4.21 MBytes  16.8 Mbits/sec
```

> "We see bidirectional traffic flowing. The `-R` flag means reverse mode - traffic flows from server to client. Combined with 100 parallel streams and 17 Mbps bandwidth limit, this generates significant CPU load on the FortiGate."

**Switch to FortiGate mpstat panel:**

```
FGT # diag sys mpstat 1
  cpu     %usr    %sys     %irq   %idle
    0    45.2    12.3      8.1    34.4
    0    58.7    15.1      9.2    17.0
    0    72.3    18.4     10.1     0.0
    0    85.1    14.9      0.0     0.0
```

> "Watch the CPU utilization climbing. Our autoscale policy triggers at 80% CPU. As we sustain load, we'll cross that threshold and CloudWatch will trigger a scale-out action."

---

## [5:00 - 6:15] Scale-Out Triggered

**On Screen:** Focus on ASG monitor as new instance appears

**Narration:**

> "CPU has sustained above 80% for the configured evaluation period. CloudWatch has triggered our scale-out action. Watch the ASG monitor..."

**Show ASG monitor updating:**

```
ASG: acme-test-fgt_on_demand_asg
  Capacity: 2 running | Desired: 2 | Min: 1 | Max: 4

  Instance ID          State        Private IP       Public IP        Health     Role
  i-0abc123def456...   running      10.0.20.10       54.x.x.x        healthy    Primary
  i-0xyz789ghi012...   pending      10.0.21.15       -               initial    N/A       @14:32:15
```

> "A new instance is launching. Notice several important details:
> - State shows 'pending' - the EC2 instance is booting
> - Health shows 'initial' - GWLB is probing port 8008, but no response yet
> - Role shows 'N/A' - it hasn't registered with the Primary yet
> - The timestamp shows when we first detected this instance
>
> Remember our configuration: 5 health checks at 60-second intervals. This instance won't become healthy for at least 5 minutes - plenty of time for Lambda to deliver the configuration."

---

## [6:15 - 7:45] Configuration Sync - AV & IPS Profiles

**On Screen:** SSH to both FortiGates

**Narration:**

> "This is the critical part. Let me SSH to both FortiGates and show you the East-West firewall rule.
>
> First, the primary..."

**Show Primary FortiGate policy:**

```
FGT-Primary # show firewall policy 2
config firewall policy
    edit 2
        set name "East-West"
        set srcintf "port2"
        set dstintf "port2"
        set srcaddr "East-VPC" "West-VPC"
        set dstaddr "East-VPC" "West-VPC"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable
        set av-profile "default"
        set ips-sensor "default"
        set logtraffic all
    next
end
```

> "Notice this policy has UTM enabled with the default antivirus profile and default IPS sensor. All East-West traffic is inspected for malware and intrusion attempts.
>
> Now let's check the secondary - remember, it's still in 'initial' health state, not yet receiving traffic..."

**Show Secondary FortiGate policy:**

```
FGT-Secondary # show firewall policy 2
config firewall policy
    edit 2
        set name "East-West"
        set srcintf "port2"
        set dstintf "port2"
        set srcaddr "East-VPC" "West-VPC"
        set dstaddr "East-VPC" "West-VPC"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable
        set av-profile "default"
        set ips-sensor "default"
        set logtraffic all
    next
end
```

> "Identical configuration. The secondary has the same East-West rule with the same AV and IPS profiles."

**Show AV profile on secondary:**

```
FGT-Secondary # show antivirus profile default
config antivirus profile
    edit "default"
        config http
            set av-scan enable
        end
        config ftp
            set av-scan enable
        end
    next
end
```

**Show IPS sensor on secondary:**

```
FGT-Secondary # show ips sensor default
config ips sensor
    edit "default"
        set comment "Prevent critical attacks."
        config entries
            edit 1
                set severity critical high
            next
        end
    next
end
```

> "Both the antivirus profile and IPS sensor are present. This is why port 8008 matters - the probe-response only works after Lambda delivers this configuration. With our old port 80 health check, this instance would already be receiving traffic - potentially without these security profiles in place."

---

## [7:45 - 8:15] Both Instances Healthy

**On Screen:** ASG monitor showing both healthy

**Narration:**

> "After 5 successful health checks, the secondary is now healthy..."

**Show ASG monitor:**

```
ASG: acme-test-fgt_on_demand_asg
  Capacity: 2 running | Desired: 2 | Min: 1 | Max: 4

  Instance ID          State        Private IP       Public IP        Health     Role
  i-0abc123def456...   running      10.0.20.10       54.x.x.x        healthy    Primary
  i-0xyz789ghi012...   running      10.0.21.15       54.y.y.y        healthy    Secondary  @14:32:15

GWLB Target Group Health
    Instance              State        Reason
    i-0abc123def456...    healthy      N/A
    i-0xyz789ghi012...    healthy      N/A
```

> "Both FortiGates are healthy and processing traffic. New flows are being distributed by GWLB across both instances. Throughout this entire scale-out process, our iperf sessions continued without interruption - GWLB flow stickiness maintained session affinity."

---

## [8:15 - 9:00] Stop Traffic - Trigger Scale-In

**On Screen:** Focus on iperf client panel

**Narration:**

> "Now let's trigger scale-in by stopping our traffic generators. I'll press Ctrl+C on both iperf clients..."

**Action:** Ctrl+C in both client panes

**Show client output stopping:**

```
^C
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-45.23  sec   192 MBytes  35.6 Mbits/sec  sender
[  5]   0.00-45.23  sec   189 MBytes  35.1 Mbits/sec  receiver
```

> "Traffic has stopped. Watch the FortiGate CPU..."

**Switch to mpstat panel:**

```
  cpu     %usr    %sys     %irq   %idle
    0     2.1     1.3      0.8    95.8
```

> "CPU drops immediately to idle. CloudWatch is now evaluating the low-CPU condition. Once it sustains below the scale-in threshold for the configured evaluation periods, scale-in will trigger."

---

## [9:00 - 10:00] Scale-In Process - Connection Draining

**On Screen:** Focus on ASG monitor

*(Add "~2 minutes later..." caption if editing in post)*

**Narration:**

> "CloudWatch has triggered scale-in. Watch the ASG monitor..."

**Show ASG monitor with draining state:**

```
GWLB Target Group Health

    Instance              State        Reason
    i-0abc123def456...    healthy      N/A
    i-0xyz789ghi012...    draining     Target.DeregistrationInProgress
```

> "The secondary instance has entered 'draining' state. This is critical for graceful scale-in.
>
> GWLB deregistration delay gives existing connections time to complete. During this time:
> - No NEW flows are sent to this instance
> - EXISTING flows continue to be forwarded
> - The FortiGate keeps processing until connections close naturally
>
> Since we stopped iperf, there are no active flows to drain."

---

## [10:00 - 10:45] Instance Termination & Traffic Restart

**On Screen:** ASG monitor showing single instance

**Narration:**

> "After the draining period, the instance is terminated..."

**Show ASG monitor:**

```
ASG: acme-test-fgt_on_demand_asg
  Capacity: 1 running | Desired: 1 | Min: 1 | Max: 4

  Instance ID          State        Private IP       Public IP        Health     Role
  i-0abc123def456...   running      10.0.20.10       54.x.x.x        healthy    Primary

GWLB Target Group Health
    Instance              State        Reason
    i-0abc123def456...    healthy      N/A
```

> "We're back to a single FortiGate - our Primary. Let me restart traffic to prove the system is fully functional..."

**Action:** Restart iperf clients

**Show traffic flowing:**

```
[  5]   0.00-2.00   sec  4.25 MBytes  17.0 Mbits/sec
[  5]   2.00-4.00   sec  4.21 MBytes  16.8 Mbits/sec
```

> "Traffic flows immediately through the remaining FortiGate. The autoscale lifecycle is complete."

---

## [10:45 - 11:15] Summary

**On Screen:** Summary slide

**Narration:**

> "Let's recap what we demonstrated.
>
> **The Problem:** Port 80 health checks responded before configuration sync, causing traffic to hit unconfigured FortiGates.
>
> **The Solution:** Three configuration changes..."

### Configuration Changes

| Setting | Old | New | Why |
|---------|-----|-----|-----|
| `gwlb_health_check_port` | 80 | 8008 | Probe-response requires config |
| `gwlb_health_check_interval` | 30s | 60s | More time between checks |
| `gwlb_healthy_threshold` | 3 | 5 | 5 x 60s = 5 min to healthy |
| `asg_health_check_grace_period` | 300s | 700s | Don't terminate during sync |

> "**Scale-Out:** New instances sync their complete configuration - including AV and IPS profiles - before port 8008 responds. No traffic reaches an unconfigured firewall.
>
> **Scale-In:** GWLB draining protects active connections. Sessions complete naturally before instance termination.
>
> This is enterprise-grade autoscaling - elastic capacity that responds to demand while maintaining security policy consistency and zero service disruption.
>
> Thanks for watching."

---

## Timeline Summary

| Time | Section |
|------|---------|
| 0:00 | Problem & Terraform config fix |
| 1:15 | Panel layout walkthrough |
| 2:30 | Initial state (1 FortiGate) |
| 3:30 | Start traffic, show CPU rising |
| 5:00 | Scale-out triggered |
| 6:15 | Config sync - East-West rule with AV & IPS |
| 7:45 | Both instances healthy |
| 8:15 | Stop iperf clients (Ctrl+C) |
| 9:00 | Scale-in - draining state |
| 10:00 | Instance terminated |
| 10:45 | Restart traffic |
| 11:15 | End |

---

## Pre-Recording Checklist

1. Deploy infrastructure with correct health check settings
2. Run `./testing_scripts/stress_test_servers.sh` - start iperf servers
3. Run `./testing_scripts/stress_test_clients.sh` - start iperf clients (pause before starting)
4. Run `./monitor_asg.sh -w` - ASG/GWLB monitor
5. Run `./testing_scripts/stress_test_fortigates.sh` - FortiGate CPU monitor
6. Ensure ASG is at minimum capacity (1 instance)
7. Have SSH sessions ready to both FortiGates for policy verification

---

## Demo Commands Reference

```bash
# FortiGate CPU monitoring
diag sys mpstat 1

# Show East-West policy with UTM
show firewall policy 2

# Show security profiles
show antivirus profile default
show ips sensor default

# Verify probe-response config
show system probe-response
```
