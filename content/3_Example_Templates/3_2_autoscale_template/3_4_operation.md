---
title: "Operations & Troubleshooting"
chapter: false
menuTitle: "Operations"
weight: 533
---

## Monitoring and Operations

### CloudWatch Metrics

Key metrics to monitor:

```bash
# CPU utilization (triggers autoscaling)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average

# Network throughput
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Lambda Function Logs

Monitor license assignment and lifecycle events:

```bash
# Stream Lambda logs
aws logs tail /aws/lambda/<function-name> --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/<function-name> \
  --filter-pattern "ERROR"

# Search for license assignments
aws logs filter-log-events \
  --log-group-name /aws/lambda/<function-name> \
  --filter-pattern "license"
```

### Auto Scaling Group Activity

```bash
# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name <asg-name> \
  --max-records 20

# View current capacity
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name> \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]'
```

---

## Troubleshooting

### Issue: Instances Launch But Don't Get Licensed

**Symptoms**:
- Instances running but showing unlicensed
- Throughput limited to 1 Mbps
- FortiGuard services not working

**Causes and Solutions**:

**For BYOL**:
1. Check license files exist in directory:
   ```bash
   ls -la asg_license/
   ```

2. Check S3 bucket has licenses uploaded:
   ```bash
   aws s3 ls s3://<bucket-name>/licenses/
   ```

3. Check Lambda CloudWatch logs for errors:
   ```bash
   aws logs tail /aws/lambda/<function-name> --follow | grep -i error
   ```

4. Verify DynamoDB table has available licenses:
   ```bash
   aws dynamodb scan --table-name <table-name>
   ```

**For FortiFlex**:
1. Check Lambda CloudWatch logs for API errors
2. Verify FortiFlex credentials are correct
3. Check point balance in FortiFlex portal
4. Verify configuration ID matches instance CPU count
5. Check entitlements created in FortiFlex portal

**For PAYG**:
1. Verify AWS Marketplace subscription is active
2. Check instance profile has correct permissions
3. Verify internet connectivity from FortiGate

### Issue: Cannot Access FortiGate GUI

**Symptoms**:
- Timeout when accessing FortiGate IP
- Connection refused

**Solutions**:

1. **Verify instance is running**:
   ```bash
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

2. **Check security groups allow your IP**:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

3. **Verify you're using correct port** (default 443):
   ```bash
   https://<fortigate-ip>:443
   ```

4. **Try alternate access methods**:
   ```bash
   # SSH to check if instance is responsive
   ssh -i ~/.ssh/keypair.pem admin@<fortigate-ip>
   
   # Check system status
   get system status
   ```

5. **If using dedicated management VPC**:
   - Ensure you're accessing via correct IP (management interface)
   - Check VPC peering or TGW attachment is working
   - Verify route tables allow return traffic

### Issue: Traffic Not Flowing Through FortiGate

**Symptoms**:
- No traffic visible in FortiGate logs
- Connectivity tests bypass FortiGate
- Sessions not appearing on FortiGate

**Solutions**:

1. **Verify TGW routing** (if using TGW):
   ```bash
   # Check TGW route tables
   aws ec2 describe-transit-gateway-route-tables \
     --transit-gateway-id <tgw-id>
   
   # Verify routes point to inspection VPC attachment
   aws ec2 search-transit-gateway-routes \
     --transit-gateway-route-table-id <spoke-rt-id> \
     --filters "Name=state,Values=active"
   ```

2. **Check GWLB health checks**:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <gwlb-target-group-arn>
   ```

3. **Verify FortiGate firewall policies**:
   ```bash
   # SSH to FortiGate
   ssh admin@<fortigate-ip>
   
   # Check policies
   get firewall policy
   
   # Enable debug
   diagnose debug flow trace start 10
   diagnose debug enable
   # Generate traffic and watch logs
   ```

4. **Check spoke VPC route tables** (for distributed architecture):
   ```bash
   # Verify routes point to GWLB endpoints
   aws ec2 describe-route-tables \
     --filters "Name=vpc-id,Values=<spoke-vpc-id>"
   ```

### Issue: Primary Election Issues

**Symptoms**:
- No primary instance elected
- Multiple instances think they're primary
- HA sync not working

**Solutions**:

1. **Check Lambda logs for election logic**:
   ```bash
   aws logs tail /aws/lambda/<function-name> --follow | grep -i primary
   ```

2. **Verify `enable_fgt_system_autoscale = true`**:
   ```bash
   # On FortiGate
   get system auto-scale
   ```

3. **Check for network connectivity between instances**:
   ```bash
   # From one FortiGate, ping another
   execute ping <other-fortigate-private-ip>
   ```

4. **Manually verify auto-scale configuration**:
   ```bash
   # SSH to FortiGate
   ssh admin@<fortigate-ip>
   
   # Check auto-scale config
   show system auto-scale
   
   # Should show:
   # set status enable
   # set role primary (or secondary)
   # set sync-interface "port1"
   # set psksecret "..."
   ```

### Issue: FortiManager Integration Not Working

**Symptoms**:
- FortiGate doesn't appear in FortiManager device list
- Device shows as unauthorized but can't authorize
- Connection errors in FortiManager

**Solutions**:

1. **Verify FortiManager 7.6.3+ VM recognition enabled**:
   ```bash
   # On FortiManager CLI
   show system global | grep fgfm-allow-vm
   # Should show: set fgfm-allow-vm enable
   ```

2. **Check network connectivity**:
   ```bash
   # From FortiGate
   execute ping <fortimanager-ip>
   
   # Check FortiManager reachability
   diagnose debug application fgfmd -1
   diagnose debug enable
   ```

3. **Verify central-management config**:
   ```bash
   # On FortiGate
   show system central-management
   
   # Should show:
   # set type fortimanager
   # set fmg <fortimanager-ip>
   # set serial-number <fmgr-sn>
   ```

4. **Check FortiManager logs**:
   ```bash
   # On FortiManager CLI
   diagnose debug application fgfmd -1
   diagnose debug enable
   # Watch for connection attempts from FortiGate
   ```

5. **Verify only primary instance has central-management config**:
   ```bash
   # On primary: Should have config
   show system central-management
   
   # On secondary: Should NOT have config (or be blocked by vdom-exception)
   show system vdom-exception
   ```

---

