---
title: "Operations & Troubleshooting"
menuTitle: "Operations"
weight: 4
---

## Post-Deployment Configuration

### Configure FortiManager for Integration

If you enabled FortiManager and plan to integrate with autoscale group:

1. **Access FortiManager GUI**: `https://<FortiManager-Public-IP>`

2. **Change default password**:
   - Login with `admin` / `<instance-id>`
   - Follow password change prompts

3. **Enable VM device recognition** (7.6.3+):
   ```
   config system global
       set fgfm-allow-vm enable
   end
   ```

4. **Create ADOM for autoscale group** (optional):
   - Device Manager > ADOM
   - Create ADOM for organizing autoscale FortiGates

5. **Note FortiManager details** for autoscale_template:
   - Private IP: From outputs
   - Serial number: Get from CLI: `get system status`

### Configure FortiAnalyzer for Logging

If you enabled FortiAnalyzer:

1. **Access FortiAnalyzer GUI**: `https://<FortiAnalyzer-Public-IP>`

2. **Change default password**

3. **Configure log settings**:
   - System Settings > Storage
   - Configure log retention policies
   - Enable features needed for testing

4. **Note FortiAnalyzer private IP** for FortiGate syslog configuration

---

## Important Notes

### Resource Lifecycle Considerations

{{% notice warning %}}
**Management Resource Persistence**

If you deploy the `existing_vpc_resources` template:
- Management VPC and resources (FortiManager, FortiAnalyzer) will be **destroyed** when you run `terraform destroy`
- If you want management resources to persist across inspection VPC redeployments, consider:
  - Deploying management VPC separately with different Terraform state
  - Using existing management infrastructure instead of template-created resources
  - Setting appropriate lifecycle rules in Terraform to prevent destruction
{{% /notice %}}

### Cost Optimization Tips

{{% notice info %}}
**Managing Lab Costs**

The `existing_vpc_resources` template can create expensive resources:
- FortiManager m5.large: ~$0.10/hour (~$73/month)
- FortiAnalyzer m5.large: ~$0.10/hour (~$73/month)
- Transit Gateway: $0.05/hour (~$36/month) + data processing charges
- NAT Gateways: $0.045/hour each (~$33/month each)

**Cost reduction strategies**:
- Use smaller instance types (t3.micro, t3.small) where possible
- Disable FortiManager/FortiAnalyzer if not testing those features
- **Destroy resources when not actively testing**
- Use AWS Cost Explorer to monitor spend
- Consider AWS budgets and alerts

**Example budget-conscious configuration**:
```hcl
enable_fortimanager = false    # Save $73/month
enable_fortianalyzer = false   # Save $73/month
jump_box_instance_type = "t3.micro"  # Use smallest size
east_linux_instance_type = "t3.micro"
west_linux_instance_type = "t3.micro"
```
{{% /notice %}}

### State File Management

Store Terraform state securely:

```hcl
# backend.tf (optional - recommended for teams)
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "existing-vpc-resources/terraform.tfstate"
    region = "us-west-2"
    encrypt = true
    dynamodb_table = "terraform-locks"
  }
}
```

---

## Troubleshooting

### Issue: Terraform Fails with "Resource Already Exists"

**Symptoms**:
```
Error: Error creating VPC: VpcLimitExceeded
```

**Solutions**:
- Check VPC limits in your AWS account
- Clean up unused VPCs
- Request limit increase via AWS Support

### Issue: Cannot Access FortiManager/FortiAnalyzer

**Symptoms**:
- Timeout when accessing GUI
- SSH connection refused

**Solutions**:
1. Verify security groups allow your IP:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. Check instance is running:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Name,Values=*fortimanager*"
   ```

3. Verify `my_ip` variable matches your current public IP:
   ```bash
   curl ifconfig.me
   ```

4. Check instance system log for boot issues:
   ```bash
   aws ec2 get-console-output --instance-id <instance-id>
   ```

### Issue: Transit Gateway Attachment Pending

**Symptoms**:
- TGW attachment stuck in "pending" state
- Spoke VPCs can't communicate

**Solutions**:
1. Wait 5-10 minutes for attachment to complete
2. Check TGW route tables are configured
3. Verify no CIDR overlaps between VPCs
4. Check TGW attachment state:
   ```bash
   aws ec2 describe-transit-gateway-attachments
   ```

### Issue: Linux Instances Not Reachable

**Symptoms**:
- Cannot curl or SSH to Linux instances

**Solutions**:
1. Verify you're accessing from jump box (if not public)
2. Check security groups allow port 80 and 22
3. Verify NAT Gateway is functioning for internet access
4. Check route tables in spoke VPCs

### Issue: High Costs After Deployment

**Symptoms**:
- AWS bill higher than expected

**Solutions**:
1. Check what's running:
   ```bash
   aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
   ```

2. Identify expensive resources:
   ```bash
   # Use AWS Cost Explorer in AWS Console
   # Filter by resource tags: cp and env
   ```

3. Shut down unused components:
   ```bash
   terraform destroy -target=module.fortimanager
   terraform destroy -target=module.fortianalyzer
   ```

4. Or destroy entire deployment:
   ```bash
   terraform destroy
   ```

---

## Cleanup

### Destroying Resources

To destroy the `existing_vpc_resources` infrastructure:

```bash
cd terraform/existing_vpc_resources
terraform destroy
```

Type `yes` when prompted.

{{% notice warning %}}
**Destroy Order is Critical**

If you deployed either `autoscale_template` or `ha_pair`, **destroy it FIRST** before destroying `existing_vpc_resources`:

**For AutoScale Deployment:**
```bash
# Step 1: Destroy autoscale_template
cd terraform/autoscale_template
terraform destroy

# Step 2: Destroy existing_vpc_resources
cd ../existing_vpc_resources
terraform destroy
```

**For HA Pair Deployment:**
```bash
# Step 1: Destroy ha_pair
cd terraform/ha_pair
terraform destroy

# Step 2: Destroy existing_vpc_resources
cd ../existing_vpc_resources
terraform destroy
```

**Why?** The inspection VPC has a Transit Gateway attachment to the TGW created by `existing_vpc_resources`. Destroying the TGW first will cause the attachment deletion to fail.
{{% /notice %}}

### Selective Cleanup

To destroy only specific components:

```bash
# Destroy only FortiManager
terraform destroy -target=module.fortimanager

# Destroy only spoke VPCs and TGW
terraform destroy -target=module.transit_gateway
terraform destroy -target=module.spoke_vpcs

# Destroy only management VPC
terraform destroy -target=module.management_vpc
```

### Verify Complete Cleanup

After destroying, verify no resources remain:

```bash
# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:cp,Values=acme" "Name=tag:env,Values=test"

# Check Transit Gateways
aws ec2 describe-transit-gateways --filters "Name=tag:cp,Values=acme"

# Check running instances
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:cp,Values=acme"
```

---

## Next Steps

After deploying `existing_vpc_resources`, proceed to deploy your chosen FortiGate template:

### For AutoScale Deployment

Deploy [autoscale_template](../5_3_autoscale_template/) to create the FortiGate autoscale group with Gateway Load Balancer:

**Key information to carry forward**:
- Transit Gateway name (from outputs): Use for `attach_to_tgw_name`
- FortiManager private IP (if enabled): Use for `fortimanager_ip`
- FortiAnalyzer private IP (if enabled): Use for FortiGate syslog config
- Same `cp` and `env` values (critical for resource discovery)

**Recommended next reading**:
- [autoscale_template Deployment Guide](../5_3_autoscale_template/)
- [FortiManager Integration Configuration](../../4_solution_components/4_5_fortimanager_integration/)
- [Licensing Options](../../3_licensing/)

### For HA Pair Deployment

Deploy [ha_pair template](../5_4_ha_pair/) to create the FortiGate Active-Passive HA Pair:

**Key information to carry forward**:
- Transit Gateway name (from outputs): Use for `attach_to_tgw_name`
- FortiManager private IP (if enabled): Use for `fortimanager_ip`
- FortiAnalyzer private IP (if enabled): Use for FortiGate syslog config
- Same `cp` and `env` values (critical for resource discovery)

**Recommended next reading**:
- [ha_pair Template Deployment Guide](../5_4_ha_pair/)
- [FGCP HA Configuration](../../4_solution_components/)
- [Licensing Options](../../3_licensing/)
