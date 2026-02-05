---
title: "Reference"
chapter: false
menuTitle: "Reference"
weight: 534
---

## Outputs Reference

Important outputs from the template:

```bash
terraform output
```

| Output | Description | Use Case |
|--------|-------------|----------|
| `inspection_vpc_id` | ID of inspection VPC | VPC peering, routing configuration |
| `inspection_vpc_cidr` | CIDR of inspection VPC | Route table configuration |
| `gwlb_arn` | Gateway Load Balancer ARN | GWLB endpoint creation |
| `gwlb_endpoint_az1_id` | GWLB endpoint ID in AZ1 | Spoke VPC route tables |
| `gwlb_endpoint_az2_id` | GWLB endpoint ID in AZ2 | Spoke VPC route tables |
| `fortigate_autoscale_group_name` | BYOL ASG name | CloudWatch, monitoring |
| `fortigate_ondemand_autoscale_group_name` | PAYG ASG name | CloudWatch, monitoring |
| `lambda_function_name` | Lifecycle Lambda function name | CloudWatch logs, debugging |
| `dynamodb_table_name` | License tracking table name | License management |
| `s3_bucket_name` | License storage bucket name | License management |
| `tgw_attachment_id` | TGW attachment ID | TGW routing configuration |

---

## Best Practices

### Pre-Deployment

1. **Plan capacity thoroughly**: Use [Autoscale Group Capacity](../../3_example_templates/3_2_autoscale_template/autoscale_reference/4_6_autoscale_group_capacity/) guidance
2. **Test in dev/test first**: Validate configuration before production
3. **Document customizations**: Maintain runbook of configuration decisions
4. **Review security groups**: Ensure least-privilege access
5. **Coordinate with network team**: Verify CIDR allocations don't conflict

### During Deployment

1. **Monitor Lambda logs**: Watch for errors during instance launch
2. **Verify license assignments**: Check first instance gets licensed before scaling
3. **Test connectivity incrementally**: Validate routing at each step
4. **Document public IPs**: Save instance IPs for troubleshooting access

### Post-Deployment

1. **Configure firewall policies immediately**: Don't leave FortiGates in pass-through mode
2. **Enable security profiles**: IPS, Application Control, Web Filtering
3. **Set up monitoring**: CloudWatch alarms, FortiGate logging
4. **Test failover scenarios**: Verify autoscaling behavior
5. **Document recovery procedures**: Maintain runbook for common issues

### Ongoing Operations

1. **Monitor autoscale events**: Review CloudWatch metrics weekly
2. **Update FortiOS regularly**: Test updates in dev first
3. **Review firewall logs**: Look for blocked traffic patterns
4. **Optimize scaling thresholds**: Adjust based on observed traffic
5. **Plan capacity additions**: Add licenses/entitlements before needed

---

## Cleanup

### Destroying the Deployment

To destroy the autoscale_template infrastructure:

```bash
cd terraform/autoscale_template
terraform destroy
```

Type `yes` when prompted.

{{% notice warning %}}
**Destroy Order is Critical**

If you also deployed `existing_vpc_resources`, destroy in this order:

1. **First**: Destroy `autoscale_template` (this template)
2. **Second**: Destroy `existing_vpc_resources`

**Why?** The inspection VPC has a Transit Gateway attachment to the TGW created by `existing_vpc_resources`. Destroying the TGW first will cause the attachment deletion to fail.

```bash
# Correct order:
cd terraform/autoscale_template
terraform destroy

cd ../existing_vpc_resources
terraform destroy
```
{{% /notice %}}

### Selective Cleanup

To destroy only specific components:

```bash
# Destroy only BYOL ASG
terraform destroy -target=module.fortigate_byol_asg

# Destroy only on-demand ASG
terraform destroy -target=module.fortigate_ondemand_asg

# Destroy only Lambda and DynamoDB
terraform destroy -target=module.lambda_functions
terraform destroy -target=module.dynamodb_table
```

### Verify Complete Cleanup

After destroying, verify no resources remain:

```bash
# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:cp,Values=acme" "Name=tag:env,Values=prod"

# Check running instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
           "Name=tag:cp,Values=acme"

# Check GWLB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `acme`)]'

# Check Lambda functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `acme`)]'
```

---

## Summary

The autoscale_template is the core component of the FortiGate Autoscale Simplified Template, providing:

**Complete autoscale infrastructure**: FortiGate ASG, GWLB, Lambda, IAM
**Flexible deployment options**: Centralized, distributed, or hybrid architectures
**Multiple licensing models**: BYOL, FortiFlex, PAYG, or hybrid
**Management options**: Dedicated ENI, dedicated VPC, FortiManager integration
**Production-ready**: High availability, autoscaling, lifecycle management

**Next Steps**:
- Review [Solution Components](../../3_example_templates/3_2_autoscale_template/autoscale_reference/) for configuration options
- See [Licensing Options](../../3_example_templates/3_2_autoscale_template/autoscale_reference/4_4_Licensing_Options/) for cost optimization
- Check [FortiManager Integration](../../3_example_templates/3_2_autoscale_template/autoscale_reference/4_5_fortimanager_integration/) for centralized management

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Terraform Module Version**: Compatible with terraform-aws-cloud-modules v1.0+
