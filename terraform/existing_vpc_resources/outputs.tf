#
# ========================================================================
# MANAGEMENT VPC OUTPUTS
# ========================================================================
#

output "management_vpc_id" {
  value       = var.enable_build_management_vpc ? module.vpc-management[0].vpc_id : null
  description = "The VPC Id of the management VPC."
}

output "management_igw_id" {
  value       = var.enable_build_management_vpc ? module.vpc-management[0].igw_id : null
  description = "The IGW Id of the management VPC."
}

output "jump_box_public_ip" {
  value       = (var.enable_build_management_vpc && var.enable_jump_box_public_ip) ? module.vpc-management[0].jump_box_public_ip : null
  description = "The public IP address of the jump box."
}

output "jump_box_private_ip" {
  value       = (var.enable_build_management_vpc && var.enable_jump_box) ? module.vpc-management[0].jump_box_private_ip : null
  description = "The private IP address of the jump box."
}

output "fortimanager_public_ip" {
  value       = (var.enable_fortimanager && var.enable_fortimanager_public_ip && var.enable_build_management_vpc) ? module.vpc-management[0].fortimanager_public_ip : null
  description = "The public IP address of the FortiManager."
}

output "fortimanager_private_ip" {
  value       = (var.enable_fortimanager && var.enable_build_management_vpc) ? module.vpc-management[0].fortimanager_private_ip : null
  description = "The private IP address of the FortiManager."
}

output "fortianalyzer_public_ip" {
  value       = (var.enable_fortianalyzer_public_ip && var.enable_fortianalyzer && var.enable_build_management_vpc) ? module.vpc-management[0].fortianalyzer_public_ip : null
  description = "The public IP address of the FortiAnalyzer."
}

output "fortianalyzer_private_ip" {
  value       = (var.enable_fortianalyzer && var.enable_build_management_vpc) ? module.vpc-management[0].fortianalyzer_private_ip : null
  description = "The private IP address of the FortiAnalyzer."
}

#
# ========================================================================
# INSPECTION VPC OUTPUTS
# ========================================================================
#

output "inspection_vpc_id" {
  value       = module.vpc-inspection.vpc_id
  description = "The VPC Id of the inspection VPC."
}

output "inspection_igw_id" {
  value       = module.vpc-inspection.igw_id
  description = "The IGW Id of the inspection VPC."
}

output "inspection_vpc_subnet_ids" {
  value = {
    public_az1        = module.vpc-inspection.subnet_public_az1_id
    public_az2        = module.vpc-inspection.subnet_public_az2_id
    private_az1       = module.vpc-inspection.subnet_private_az1_id
    private_az2       = module.vpc-inspection.subnet_private_az2_id
    gwlbe_az1         = module.vpc-inspection.subnet_gwlbe_az1_id
    gwlbe_az2         = module.vpc-inspection.subnet_gwlbe_az2_id
    # Note: TGW attachment uses private subnets (subnet_private_az1_id / subnet_private_az2_id)
    natgw_az1         = local.enable_nat_gateway ? module.vpc-inspection.subnet_natgw_az1_id : null
    natgw_az2         = local.enable_nat_gateway ? module.vpc-inspection.subnet_natgw_az2_id : null
    management_az1    = var.create_management_subnet_in_inspection_vpc ? module.vpc-inspection.subnet_management_az1_id : null
    management_az2    = var.create_management_subnet_in_inspection_vpc ? module.vpc-inspection.subnet_management_az2_id : null
  }
  description = "Map of inspection VPC subnet IDs by type and availability zone."
}

output "inspection_vpc_route_table_ids" {
  value = {
    public_az1  = module.vpc-inspection.route_table_public_az1_id
    public_az2  = module.vpc-inspection.route_table_public_az2_id
    private_az1 = module.vpc-inspection.route_table_private_az1_id
    private_az2 = module.vpc-inspection.route_table_private_az2_id
    gwlbe_az1   = module.vpc-inspection.route_table_gwlbe_az1_id
    gwlbe_az2   = module.vpc-inspection.route_table_gwlbe_az2_id
    tgw         = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
  }
  description = "Map of inspection VPC route table IDs."
}

output "inspection_tgw_attachment_id" {
  value       = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_attachment_id : null
  description = "The Transit Gateway attachment ID for the inspection VPC."
}

output "inspection_tgw_route_table_id" {
  value       = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
  description = "The Transit Gateway route table ID associated with the inspection VPC."
}

#
# ========================================================================
# TRANSIT GATEWAY OUTPUTS
# ========================================================================
#

output "transit_gateway_id" {
  value       = var.enable_build_existing_subnets ? module.vpc-transit-gateway[0].tgw_id : null
  description = "The Transit Gateway ID."
}

output "tgw_route_table_ids" {
  value = {
    east       = var.enable_build_existing_subnets ? aws_ec2_transit_gateway_route_table.east[0].id : null
    west       = var.enable_build_existing_subnets ? aws_ec2_transit_gateway_route_table.west[0].id : null
    inspection = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
  }
  description = "Map of Transit Gateway route table IDs."
}

output "tgw_attachment_ids" {
  value = {
    east       = var.enable_build_existing_subnets ? module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id : null
    west       = var.enable_build_existing_subnets ? module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id : null
    inspection = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_attachment_id : null
    management = (var.enable_build_management_vpc && var.enable_management_tgw_attachment) ? module.vpc-management[0].management_tgw_attachment_id : null
  }
  description = "Map of Transit Gateway attachment IDs."
}

#
# ========================================================================
# SPOKE VPC OUTPUTS (EAST/WEST)
# ========================================================================
#

output "east_vpc_id" {
  value       = var.enable_build_existing_subnets ? module.vpc-east[0].vpc_id : null
  description = "The VPC Id of the east spoke VPC."
}

output "west_vpc_id" {
  value       = var.enable_build_existing_subnets ? module.vpc-west[0].vpc_id : null
  description = "The VPC Id of the west spoke VPC."
}

output "east_vpc_subnet_ids" {
  value = {
    public_az1 = var.enable_build_existing_subnets ? module.subnet-east-public-az1[0].id : null
    public_az2 = var.enable_build_existing_subnets ? module.subnet-east-public-az2[0].id : null
    tgw_az1    = var.enable_build_existing_subnets ? module.subnet-east-tgw-az1[0].id : null
    tgw_az2    = var.enable_build_existing_subnets ? module.subnet-east-tgw-az2[0].id : null
  }
  description = "Map of east VPC subnet IDs."
}

output "west_vpc_subnet_ids" {
  value = {
    public_az1 = var.enable_build_existing_subnets ? module.subnet-west-public-az1[0].id : null
    public_az2 = var.enable_build_existing_subnets ? module.subnet-west-public-az2[0].id : null
    tgw_az1    = var.enable_build_existing_subnets ? module.subnet-west-tgw-az1[0].id : null
    tgw_az2    = var.enable_build_existing_subnets ? module.subnet-west-tgw-az2[0].id : null
  }
  description = "Map of west VPC subnet IDs."
}

output "east_vpc_route_table_id" {
  value       = var.enable_build_existing_subnets ? module.vpc-east[0].vpc_main_route_table_id : null
  description = "The main route table ID for the east VPC."
}

output "west_vpc_route_table_id" {
  value       = var.enable_build_existing_subnets ? module.vpc-west[0].vpc_main_route_table_id : null
  description = "The main route table ID for the west VPC."
}

#
# ========================================================================
# LINUX INSTANCE OUTPUTS
# ========================================================================
#

output "linux_instances" {
  value = {
    east_az1_public_ip   = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az1[0].public_eip[0], null) : null
    east_az1_private_ip  = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az1[0].network_public_interface_ip : null
    east_az2_public_ip   = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az2[0].public_eip[0], null) : null
    east_az2_private_ip  = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az2[0].network_public_interface_ip : null
    west_az1_public_ip   = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az1[0].public_eip[0], null) : null
    west_az1_private_ip  = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az1[0].network_public_interface_ip : null
    west_az2_public_ip   = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az2[0].public_eip[0], null) : null
    west_az2_private_ip  = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az2[0].network_public_interface_ip : null
  }
  description = "Map of Linux spoke instance IP addresses (both public and private)."
}

output "linux_instance_ids" {
  value = {
    east_az1 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az1[0].instance_id : null
    east_az2 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az2[0].instance_id : null
    west_az1 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az1[0].instance_id : null
    west_az2 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az2[0].instance_id : null
  }
  description = "Map of Linux spoke instance IDs."
}

#
# ========================================================================
# CONNECTION INFORMATION SUMMARY
# ========================================================================
#

output "connection_info" {
  value = <<-EOT
    ========================================
    AWS Infrastructure Connection Details
    ========================================

    Management VPC:
      Jump Box:        ${var.enable_build_management_vpc && var.enable_jump_box ? (var.enable_jump_box_public_ip ? "Enabled with public IP" : "Enabled (private only)") : "Not enabled"}
      FortiManager:    ${var.enable_build_management_vpc && var.enable_fortimanager ? (var.enable_fortimanager_public_ip ? "Enabled with public IP" : "Enabled (private only)") : "Not enabled"}
      FortiAnalyzer:   ${var.enable_build_management_vpc && var.enable_fortianalyzer ? (var.enable_fortianalyzer_public_ip ? "Enabled with public IP" : "Enabled (private only)") : "Not enabled"}

    Spoke VPC Linux Instances:
      Status:          ${var.enable_build_existing_subnets && var.enable_linux_spoke_instances ? "Enabled (4 instances across East/West AZs)" : "Not enabled"}

    Key Resource IDs:
    ${var.enable_build_existing_subnets ? "  Transit Gateway: ${module.vpc-transit-gateway[0].tgw_id}" : "  Transit Gateway: Not created"}
      Inspection VPC:  ${module.vpc-inspection.vpc_id}
    ${var.enable_build_management_vpc ? "  Management VPC:  ${module.vpc-management[0].vpc_id}" : "  Management VPC:  Not created"}
    ${var.enable_build_existing_subnets ? "  East Spoke VPC:  ${module.vpc-east[0].vpc_id}" : "  East Spoke VPC:  Not created"}
    ${var.enable_build_existing_subnets ? "  West Spoke VPC:  ${module.vpc-west[0].vpc_id}" : "  West Spoke VPC:  Not created"}

    ========================================
  EOT
  description = "Formatted summary of connection information and key resource IDs."
}

#
# ========================================================================
# VERIFICATION SCRIPT DATA
# ========================================================================
#
# This output provides all resource IDs in a structured format that
# verification scripts can consume directly, eliminating the need for
# AWS CLI lookups by tag name.
#

output "verification_data" {
  value = {
    # Management VPC
    management_vpc = {
      vpc_id              = var.enable_build_management_vpc ? module.vpc-management[0].vpc_id : null
      igw_id              = var.enable_build_management_vpc ? module.vpc-management[0].igw_id : null
      jump_box_private_ip = (var.enable_build_management_vpc && var.enable_jump_box) ? module.vpc-management[0].jump_box_private_ip : null
      jump_box_public_ip  = (var.enable_build_management_vpc && var.enable_jump_box_public_ip) ? module.vpc-management[0].jump_box_public_ip : null
      fmgr_private_ip     = (var.enable_fortimanager && var.enable_build_management_vpc) ? module.vpc-management[0].fortimanager_private_ip : null
      fmgr_public_ip      = (var.enable_fortimanager && var.enable_fortimanager_public_ip && var.enable_build_management_vpc) ? module.vpc-management[0].fortimanager_public_ip : null
      faz_private_ip      = (var.enable_fortianalyzer && var.enable_build_management_vpc) ? module.vpc-management[0].fortianalyzer_private_ip : null
      faz_public_ip       = (var.enable_fortianalyzer_public_ip && var.enable_fortianalyzer && var.enable_build_management_vpc) ? module.vpc-management[0].fortianalyzer_public_ip : null
    }
    # Inspection VPC
    inspection_vpc = {
      vpc_id                    = module.vpc-inspection.vpc_id
      igw_id                    = module.vpc-inspection.igw_id
      subnet_public_az1_id      = module.vpc-inspection.subnet_public_az1_id
      subnet_public_az2_id      = module.vpc-inspection.subnet_public_az2_id
      subnet_private_az1_id     = module.vpc-inspection.subnet_private_az1_id
      subnet_private_az2_id     = module.vpc-inspection.subnet_private_az2_id
      subnet_gwlbe_az1_id       = module.vpc-inspection.subnet_gwlbe_az1_id
      subnet_gwlbe_az2_id       = module.vpc-inspection.subnet_gwlbe_az2_id
      subnet_natgw_az1_id       = local.enable_nat_gateway ? module.vpc-inspection.subnet_natgw_az1_id : null
      subnet_natgw_az2_id       = local.enable_nat_gateway ? module.vpc-inspection.subnet_natgw_az2_id : null
      route_table_public_az1_id = module.vpc-inspection.route_table_public_az1_id
      route_table_public_az2_id = module.vpc-inspection.route_table_public_az2_id
      route_table_private_az1_id = module.vpc-inspection.route_table_private_az1_id
      route_table_private_az2_id = module.vpc-inspection.route_table_private_az2_id
      route_table_gwlbe_az1_id  = module.vpc-inspection.route_table_gwlbe_az1_id
      route_table_gwlbe_az2_id  = module.vpc-inspection.route_table_gwlbe_az2_id
      route_table_tgw_id        = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
      tgw_attachment_id         = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_attachment_id : null
      tgw_route_table_id        = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
    }
    # Transit Gateway
    transit_gateway = {
      tgw_id                    = var.enable_build_existing_subnets ? module.vpc-transit-gateway[0].tgw_id : null
      east_route_table_id       = var.enable_build_existing_subnets ? aws_ec2_transit_gateway_route_table.east[0].id : null
      west_route_table_id       = var.enable_build_existing_subnets ? aws_ec2_transit_gateway_route_table.west[0].id : null
      inspection_route_table_id = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_route_table_id : null
      east_attachment_id        = var.enable_build_existing_subnets ? module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id : null
      west_attachment_id        = var.enable_build_existing_subnets ? module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id : null
      inspection_attachment_id  = var.enable_tgw_attachment ? module.vpc-inspection.inspection_tgw_attachment_id : null
      management_attachment_id  = (var.enable_build_management_vpc && var.enable_management_tgw_attachment) ? module.vpc-management[0].management_tgw_attachment_id : null
    }
    # East Spoke VPC
    east_vpc = {
      vpc_id                    = var.enable_build_existing_subnets ? module.vpc-east[0].vpc_id : null
      subnet_public_az1_id      = var.enable_build_existing_subnets ? module.subnet-east-public-az1[0].id : null
      subnet_public_az2_id      = var.enable_build_existing_subnets ? module.subnet-east-public-az2[0].id : null
      subnet_tgw_az1_id         = var.enable_build_existing_subnets ? module.subnet-east-tgw-az1[0].id : null
      subnet_tgw_az2_id         = var.enable_build_existing_subnets ? module.subnet-east-tgw-az2[0].id : null
      route_table_id            = var.enable_build_existing_subnets ? module.vpc-east[0].vpc_main_route_table_id : null
      linux_az1_instance_id     = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az1[0].instance_id : null
      linux_az1_private_ip      = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az1[0].network_public_interface_ip : null
      linux_az1_public_ip       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az1[0].public_eip[0], null) : null
      linux_az2_instance_id     = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az2[0].instance_id : null
      linux_az2_private_ip      = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.east_instance_public_az2[0].network_public_interface_ip : null
      linux_az2_public_ip       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az2[0].public_eip[0], null) : null
    }
    # West Spoke VPC
    west_vpc = {
      vpc_id                    = var.enable_build_existing_subnets ? module.vpc-west[0].vpc_id : null
      subnet_public_az1_id      = var.enable_build_existing_subnets ? module.subnet-west-public-az1[0].id : null
      subnet_public_az2_id      = var.enable_build_existing_subnets ? module.subnet-west-public-az2[0].id : null
      subnet_tgw_az1_id         = var.enable_build_existing_subnets ? module.subnet-west-tgw-az1[0].id : null
      subnet_tgw_az2_id         = var.enable_build_existing_subnets ? module.subnet-west-tgw-az2[0].id : null
      route_table_id            = var.enable_build_existing_subnets ? module.vpc-west[0].vpc_main_route_table_id : null
      linux_az1_instance_id     = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az1[0].instance_id : null
      linux_az1_private_ip      = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az1[0].network_public_interface_ip : null
      linux_az1_public_ip       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az1[0].public_eip[0], null) : null
      linux_az2_instance_id     = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az2[0].instance_id : null
      linux_az2_private_ip      = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? module.west_instance_public_az2[0].network_public_interface_ip : null
      linux_az2_public_ip       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az2[0].public_eip[0], null) : null
    }
    # HA Sync Subnets (for FortiGate HA pair)
    ha_sync_subnets = (var.enable_ha_pair_deployment || var.enable_ha_sync_subnets) ? {
      subnet_az1_id    = aws_subnet.ha_sync_subnet_az1[0].id
      subnet_az1_cidr  = aws_subnet.ha_sync_subnet_az1[0].cidr_block
      subnet_az2_id    = aws_subnet.ha_sync_subnet_az2[0].id
      subnet_az2_cidr  = aws_subnet.ha_sync_subnet_az2[0].cidr_block
    } : null
    # Distributed VPCs
    distributed_vpcs = var.enable_distributed_egress_vpcs ? {
      count = local.distributed_vpc_count
      vpcs = [for i in range(local.distributed_vpc_count) : {
        vpc_id                     = aws_vpc.distributed[i].id
        vpc_cidr                   = aws_vpc.distributed[i].cidr_block
        igw_id                     = aws_internet_gateway.distributed[i].id
        subnet_public_az1_id       = aws_subnet.distributed_public_az1[i].id
        subnet_public_az2_id       = aws_subnet.distributed_public_az2[i].id
        subnet_private_az1_id      = aws_subnet.distributed_private_az1[i].id
        subnet_private_az2_id      = aws_subnet.distributed_private_az2[i].id
        subnet_gwlbe_az1_id        = aws_subnet.distributed_gwlbe_az1[i].id
        subnet_gwlbe_az2_id        = aws_subnet.distributed_gwlbe_az2[i].id
        route_table_public_az1_id  = aws_route_table.distributed_public_az1[i].id
        route_table_public_az2_id  = aws_route_table.distributed_public_az2[i].id
        route_table_private_az1_id = aws_route_table.distributed_private_az1[i].id
        route_table_private_az2_id = aws_route_table.distributed_private_az2[i].id
#        route_table_gwlbe_az1_id   = aws_route_table.distributed_gwlbe_az1[i].id
#        route_table_gwlbe_az2_id   = aws_route_table.distributed_gwlbe_az2[i].id
        linux_az1_instance_id      = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az1[i].id : null
        linux_az1_private_ip       = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az1[i].private_ip : null
        linux_az1_public_ip        = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az1[i].public_ip : null
        linux_az2_instance_id      = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az2[i].id : null
        linux_az2_private_ip       = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az2[i].private_ip : null
        linux_az2_public_ip        = local.distributed_instance_count > 0 ? aws_instance.distributed_test_az2[i].public_ip : null
        security_group_id          = local.distributed_instance_count > 0 ? aws_security_group.distributed_instances[i].id : null
      }]
    } : null
  }
  description = "Structured resource data for verification scripts. Use 'terraform output -json verification_data' to export."
}

# HA Sync Subnet Outputs (for ha_pair template discovery)
output "ha_sync_subnet_az1_id" {
  description = "HA sync subnet ID in availability zone 1"
  value       = (var.enable_ha_pair_deployment || var.enable_ha_sync_subnets) ? aws_subnet.ha_sync_subnet_az1[0].id : null
}

output "ha_sync_subnet_az1_cidr" {
  description = "HA sync subnet CIDR in availability zone 1"
  value       = (var.enable_ha_pair_deployment || var.enable_ha_sync_subnets) ? aws_subnet.ha_sync_subnet_az1[0].cidr_block : null
}

output "ha_sync_subnet_az2_id" {
  description = "HA sync subnet ID in availability zone 2"
  value       = (var.enable_ha_pair_deployment || var.enable_ha_sync_subnets) ? aws_subnet.ha_sync_subnet_az2[0].id : null
}

output "ha_sync_subnet_az2_cidr" {
  description = "HA sync subnet CIDR in availability zone 2"
  value       = (var.enable_ha_pair_deployment || var.enable_ha_sync_subnets) ? aws_subnet.ha_sync_subnet_az2[0].cidr_block : null
}

#
# ========================================================================
# PUBLIC IP SUMMARY (for easy copy/paste access)
# ========================================================================
#

output "public_ips" {
  description = "Summary of all public IP addresses for easy access"
  value = {
    jump_box       = (var.enable_build_management_vpc && var.enable_jump_box_public_ip) ? module.vpc-management[0].jump_box_public_ip : null
    fortimanager   = (var.enable_fortimanager && var.enable_fortimanager_public_ip && var.enable_build_management_vpc) ? module.vpc-management[0].fortimanager_public_ip : null
    fortianalyzer  = (var.enable_fortianalyzer_public_ip && var.enable_fortianalyzer && var.enable_build_management_vpc) ? module.vpc-management[0].fortianalyzer_public_ip : null
    east_linux_az1 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az1[0].public_eip[0], null) : null
    east_linux_az2 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.east_instance_public_az2[0].public_eip[0], null) : null
    west_linux_az1 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az1[0].public_eip[0], null) : null
    west_linux_az2 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? try(module.west_instance_public_az2[0].public_eip[0], null) : null
  }
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands for all instances with public IPs"
  value = <<-EOT
    # Management VPC Instances
    ${(var.enable_build_management_vpc && var.enable_jump_box_public_ip) ? "ssh ubuntu@${try(module.vpc-management[0].jump_box_public_ip[0], "N/A")}  # Jump Box" : "# Jump Box: No public IP"}
    ${(var.enable_fortimanager && var.enable_fortimanager_public_ip && var.enable_build_management_vpc) ? "ssh admin@${try(module.vpc-management[0].fortimanager_public_ip[0], "N/A")}  # FortiManager" : "# FortiManager: No public IP"}
    ${(var.enable_fortianalyzer_public_ip && var.enable_fortianalyzer && var.enable_build_management_vpc) ? "ssh admin@${try(module.vpc-management[0].fortianalyzer_public_ip[0], "N/A")}  # FortiAnalyzer" : "# FortiAnalyzer: No public IP"}

    # Spoke VPC Linux Instances (via Jump Box or FortiGate)
    ${(var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? "# East AZ1: ${module.east_instance_public_az1[0].network_public_interface_ip}" : "# East AZ1: Not deployed"}
    ${(var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? "# East AZ2: ${module.east_instance_public_az2[0].network_public_interface_ip}" : "# East AZ2: Not deployed"}
    ${(var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? "# West AZ1: ${module.west_instance_public_az1[0].network_public_interface_ip}" : "# West AZ1: Not deployed"}
    ${(var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? "# West AZ2: ${module.west_instance_public_az2[0].network_public_interface_ip}" : "# West AZ2: Not deployed"}
  EOT
}

#
# ========================================================================
# DISTRIBUTED EGRESS VPC OUTPUTS (for autoscale_template discovery)
# Tagged with purpose=distributed_egress for discovery
# ========================================================================
#

output "distributed_vpc_ids" {
  description = "List of distributed VPC IDs"
  value       = aws_vpc.distributed[*].id
}

output "distributed_vpc_cidrs" {
  description = "List of distributed VPC CIDRs"
  value       = aws_vpc.distributed[*].cidr_block
}

output "distributed_gwlbe_subnet_ids" {
  description = "Map of distributed VPC GWLB endpoint subnet IDs by VPC index"
  value = {
    for idx in range(local.distributed_vpc_count) :
    idx => {
      vpc_id = aws_vpc.distributed[idx].id
      az1    = aws_subnet.distributed_gwlbe_az1[idx].id
      az2    = aws_subnet.distributed_gwlbe_az2[idx].id
    }
  }
}

output "distributed_public_subnet_ids" {
  description = "Map of distributed VPC public subnet IDs by VPC index"
  value = {
    for idx in range(local.distributed_vpc_count) :
    idx => {
      az1 = aws_subnet.distributed_public_az1[idx].id
      az2 = aws_subnet.distributed_public_az2[idx].id
    }
  }
}

output "distributed_private_subnet_ids" {
  description = "Map of distributed VPC private subnet IDs by VPC index"
  value = {
    for idx in range(local.distributed_vpc_count) :
    idx => {
      az1 = aws_subnet.distributed_private_az1[idx].id
      az2 = aws_subnet.distributed_private_az2[idx].id
    }
  }
}

output "distributed_instance_ids" {
  description = "Map of distributed VPC test instance IDs"
  value = {
    for idx in range(local.distributed_vpc_count) :
    idx => {
      az1 = aws_instance.distributed_test_az1[idx].id
      az2 = aws_instance.distributed_test_az2[idx].id
    }
  }
}

output "distributed_instance_private_ips" {
  description = "Map of distributed VPC test instance private IPs"
  value = {
    for idx in range(local.distributed_vpc_count) :
    idx => {
      az1 = aws_instance.distributed_test_az1[idx].private_ip
      az2 = aws_instance.distributed_test_az2[idx].private_ip
    }
  }
}
