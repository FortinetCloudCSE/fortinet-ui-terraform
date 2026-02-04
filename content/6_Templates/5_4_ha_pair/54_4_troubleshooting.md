---
title: "Troubleshooting & Comparison"
menuTitle: "Troubleshooting"
weight: 4
---

## Troubleshooting

### HA Pair Not Forming

**Symptoms:** FortiGates don't see each other in HA status

**Checks:**
```bash
# Verify HA sync connectivity
execute ping-options source <port3-ip>
execute ping <peer-port3-ip>

# Check HA configuration
show system ha

# Check security group rules
# Ensure UDP 23/703 and all TCP allowed on HA sync subnet
```

**Resolution:**
- Verify HA sync subnets were created
- Check security group allows all traffic between HA sync IPs
- Verify unicast heartbeat configuration matches

### AWS API Calls Failing

**Symptoms:** Failover doesn't update EIPs or routes

**Checks:**
```bash
# Test AWS connectivity
diag test app awsd 4

# Verify IAM role
diag deb app awsd -1
diag deb enable
# Trigger failover and watch logs
```

**Resolution:**
- Verify VPC endpoint exists in HA sync subnets
- Check IAM role has required permissions
- Verify Private DNS enabled on VPC endpoint

### Session Synchronization Not Working

**Symptoms:** Active sessions drop during failover

**Checks:**
```bash
# Verify session pickup enabled
show system ha | grep session-pickup

# Check current sessions
diag sys session list
```

**Resolution:**
```bash
config system ha
    set session-pickup enable
    set session-pickup-connectionless enable
end
```

### TGW Routes Not Updating

**Symptoms:** Spoke VPC traffic not reaching FortiGates

**Checks:**
```bash
# Verify update_tgw_routes is enabled
terraform show | grep update_tgw_routes

# Check TGW route tables manually
aws ec2 search-transit-gateway-routes \
  --transit-gateway-route-table-id <rtb-id> \
  --filters "Name=type,Values=static"
```

**Resolution:**
- Set `update_tgw_routes = true` in terraform.tfvars
- Run `terraform apply` to update routes
- Or manually update TGW route tables

---

## Cost Optimization

### Estimated Monthly Costs

**Minimum Configuration (PAYG):**
- 2x FortiGate c5n.xlarge: ~$350/month
- 4-6x Elastic IPs: ~$15-20/month
- VPC Interface Endpoint: ~$7/month
- **Total: ~$370-380/month**

**With Management (BYOL):**
- 2x FortiGate c5n.xlarge (compute only): ~$140/month
- FortiManager m5.xlarge: ~$73/month
- FortiAnalyzer m5.xlarge: ~$73/month
- EIPs and VPC endpoint: ~$22/month
- **Total: ~$310/month + BYOL licenses**

### Cost Savings Tips

1. **Use BYOL for long-term deployments** (break-even ~6-8 months)
2. **Stop non-production environments** when not in use
3. **Right-size instance types** based on throughput requirements
4. **Disable management EIPs** if using management VPC with VPN
5. **Use NAT Gateway mode** for predictable egress costs

---

## Comparison: HA Pair vs AutoScale

| Feature | HA Pair | AutoScale |
|---------|---------|-----------|
| **Scaling** | Fixed 2 instances | Auto scales 2-10+ |
| **Failover** | Active-Passive (seconds) | Load balanced (instant) |
| **Session Sync** | Yes (stateful) | No (stateless) |
| **Complexity** | Low | High |
| **Cost** | Fixed (~$370/mo) | Variable (scales with load) |
| **Best For** | Predictable workloads | Variable/elastic workloads |
| **Management** | Standard FortiOS HA | Lambda + CloudWatch |
| **GWLB** | Not required | Required |

**Choose HA Pair When:**
- Workload is predictable and consistent
- Stateful failover is critical
- Simplicity preferred over elastic scaling
- Cost predictability important
- Standard FortiOS HA experience desired

**Choose AutoScale When:**
- Workload varies significantly
- Need to scale beyond 2 instances
- Cost optimization through scaling down
- Can tolerate stateless failover
- Want AWS-native auto scaling

---

## Additional Resources

### Related Documentation

- [existing_vpc_resources Template](../5_2_existing_vpc_resources/) - Required prerequisite
- [autoscale_template](../5_3_autoscale_template/) - Alternative deployment mode
- [Licensing Options](../../3_licensing/) - BYOL, PAYG, FortiFlex guidance
- [Solution Components](../../5_architecture/) - Deep dive into architecture

### FortiGate HA Documentation

- [FortiOS HA Cookbook](https://docs.fortinet.com/document/fortigate/latest/ha-cookbook)
- [AWS HA Configuration](https://docs.fortinet.com/document/fortigate-public-cloud/latest/aws-administration-guide/345193/ha-for-fortigate-on-aws)
- [FGCP Active-Passive](https://docs.fortinet.com/document/fortigate/latest/administration-guide/321816/fgcp-active-passive)

### Terraform Documentation

- [ha_pair README](https://github.com/FortinetCloudCSE/fortinet-ui-terraform/tree/main/terraform/ha_pair)
- [Variables Reference](https://github.com/FortinetCloudCSE/fortinet-ui-terraform/blob/main/terraform/ha_pair/terraform.tfvars.example)

---

## Summary

The ha_pair template provides a robust Active-Passive FortiGate HA deployment using native FortiOS clustering:

**Key Capabilities:**
- ✅ FGCP Active-Passive with automatic failover
- ✅ Session synchronization for stateful inspection
- ✅ Native AWS integration (EIP/route reassignment)
- ✅ VPC endpoint for private AWS API access
- ✅ Automatic Transit Gateway routing updates
- ✅ Support for PAYG, BYOL, and FortiFlex licensing
- ✅ FortiManager/FortiAnalyzer integration

**Deployment Time:** 20-30 minutes after existing_vpc_resources

**Next Steps:**
1. Deploy [existing_vpc_resources](../5_2_existing_vpc_resources/) with HA Pair mode
2. Configure ha_pair terraform.tfvars
3. Deploy ha_pair template
4. Verify HA status and test failover
5. Configure policies and begin production traffic
