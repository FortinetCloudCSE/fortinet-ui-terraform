#====================================================================================================
# FORTINET-ROLE TAGS
#====================================================================================================
#
# This file adds Fortinet-Role tags to all VPC resources for discovery by autoscale_template.
# The autoscale_template uses these tags to discover existing infrastructure without needing
# to know specific resource IDs.
#
# Tag Format: {cp}-{env}-{resource-type}-{details}
# Example: acme-test-inspection-vpc, acme-test-inspection-public-az1
#
# IMPORTANT: The cp and env values MUST match between existing_vpc_resources and autoscale_template
# for resource discovery to work correctly.
#
#====================================================================================================

#====================================================================================================
# INSPECTION VPC TAGS
#====================================================================================================

# Inspection VPC
resource "aws_ec2_tag" "inspection_vpc" {
  resource_id = module.vpc-inspection.vpc_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-vpc"
}

# Inspection IGW
resource "aws_ec2_tag" "inspection_igw" {
  resource_id = module.vpc-inspection.igw_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-igw"
}

#----------------------------------------------------------------------------------------------------
# Inspection VPC Subnets
#----------------------------------------------------------------------------------------------------

# Public Subnets
resource "aws_ec2_tag" "inspection_public_az1" {
  resource_id = module.vpc-inspection.subnet_public_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-public-az1"
}

resource "aws_ec2_tag" "inspection_public_az2" {
  resource_id = module.vpc-inspection.subnet_public_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-public-az2"
}

# GWLBE Subnets
resource "aws_ec2_tag" "inspection_gwlbe_az1" {
  resource_id = module.vpc-inspection.subnet_gwlbe_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-gwlbe-az1"
}

resource "aws_ec2_tag" "inspection_gwlbe_az2" {
  resource_id = module.vpc-inspection.subnet_gwlbe_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-gwlbe-az2"
}

# Private Subnets
resource "aws_ec2_tag" "inspection_private_az1" {
  resource_id = module.vpc-inspection.subnet_private_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-private-az1"
}

resource "aws_ec2_tag" "inspection_private_az2" {
  resource_id = module.vpc-inspection.subnet_private_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-private-az2"
}

# NAT Gateway Subnets (conditional)
resource "aws_ec2_tag" "inspection_natgw_az1" {
  count       = local.enable_nat_gateway ? 1 : 0
  resource_id = module.vpc-inspection.subnet_natgw_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-natgw-az1"
}

resource "aws_ec2_tag" "inspection_natgw_az2" {
  count       = local.enable_nat_gateway ? 1 : 0
  resource_id = module.vpc-inspection.subnet_natgw_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-natgw-az2"
}

# Management Subnets in Inspection VPC (conditional - for dedicated management ENI)
resource "aws_ec2_tag" "inspection_management_az1" {
  count       = var.create_management_subnet_in_inspection_vpc ? 1 : 0
  resource_id = module.vpc-inspection.subnet_management_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-management-az1"
}

resource "aws_ec2_tag" "inspection_management_az2" {
  count       = var.create_management_subnet_in_inspection_vpc ? 1 : 0
  resource_id = module.vpc-inspection.subnet_management_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-management-az2"
}

#----------------------------------------------------------------------------------------------------
# Inspection VPC Route Tables
#----------------------------------------------------------------------------------------------------

# Public Route Tables
resource "aws_ec2_tag" "inspection_public_rt_az1" {
  resource_id = module.vpc-inspection.route_table_public_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-public-rt-az1"
}

resource "aws_ec2_tag" "inspection_public_rt_az2" {
  resource_id = module.vpc-inspection.route_table_public_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-public-rt-az2"
}

# GWLBE Route Tables
resource "aws_ec2_tag" "inspection_gwlbe_rt_az1" {
  resource_id = module.vpc-inspection.route_table_gwlbe_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-gwlbe-rt-az1"
}

resource "aws_ec2_tag" "inspection_gwlbe_rt_az2" {
  resource_id = module.vpc-inspection.route_table_gwlbe_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-gwlbe-rt-az2"
}

# Private Route Tables
resource "aws_ec2_tag" "inspection_private_rt_az1" {
  resource_id = module.vpc-inspection.route_table_private_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-private-rt-az1"
}

resource "aws_ec2_tag" "inspection_private_rt_az2" {
  resource_id = module.vpc-inspection.route_table_private_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-private-rt-az2"
}

#----------------------------------------------------------------------------------------------------
# Inspection VPC TGW Resources (conditional)
#----------------------------------------------------------------------------------------------------

resource "aws_ec2_tag" "inspection_tgw_attachment" {
  count       = var.enable_tgw_attachment ? 1 : 0
  resource_id = module.vpc-inspection.inspection_tgw_attachment_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-tgw-attachment"
}

resource "aws_ec2_tag" "inspection_tgw_rtb" {
  count       = var.enable_tgw_attachment ? 1 : 0
  resource_id = module.vpc-inspection.inspection_tgw_route_table_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-inspection-tgw-rtb"
}

#====================================================================================================
# MANAGEMENT VPC TAGS (conditional)
#====================================================================================================

resource "aws_ec2_tag" "management_vpc" {
  count       = var.enable_build_management_vpc ? 1 : 0
  resource_id = module.vpc-management[0].vpc_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-vpc"
}

resource "aws_ec2_tag" "management_igw" {
  count       = var.enable_build_management_vpc ? 1 : 0
  resource_id = module.vpc-management[0].igw_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-igw"
}

# Management Public Subnets
resource "aws_ec2_tag" "management_public_az1" {
  count       = var.enable_build_management_vpc ? 1 : 0
  resource_id = module.vpc-management[0].subnet_management_public_az1_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-public-az1"
}

resource "aws_ec2_tag" "management_public_az2" {
  count       = var.enable_build_management_vpc ? 1 : 0
  resource_id = module.vpc-management[0].subnet_management_public_az2_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-public-az2"
}

# Management Public Route Table
resource "aws_ec2_tag" "management_public_rt" {
  count       = var.enable_build_management_vpc ? 1 : 0
  resource_id = module.vpc-management[0].route_table_management_public
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-public-rt"
}

# Management TGW Attachment (conditional)
resource "aws_ec2_tag" "management_tgw_attachment" {
  count       = (var.enable_build_management_vpc && var.enable_management_tgw_attachment) ? 1 : 0
  resource_id = module.vpc-management[0].management_tgw_attachment_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-management-tgw-attachment"
}

#====================================================================================================
# HA SYNC SUBNET TAGS (conditional - for FortiGate HA Pair)
#====================================================================================================

resource "aws_ec2_tag" "ha_sync_az1" {
  count       = local.create_ha_sync_subnets ? 1 : 0
  resource_id = aws_subnet.ha_sync_subnet_az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-ha-sync-az1"
}

resource "aws_ec2_tag" "ha_sync_az2" {
  count       = local.create_ha_sync_subnets ? 1 : 0
  resource_id = aws_subnet.ha_sync_subnet_az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-ha-sync-az2"
}

resource "aws_ec2_tag" "ha_sync_rt_az1" {
  count       = local.create_ha_sync_subnets ? 1 : 0
  resource_id = aws_route_table.ha_sync_route_table_az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-ha-sync-rt-az1"
}

resource "aws_ec2_tag" "ha_sync_rt_az2" {
  count       = local.create_ha_sync_subnets ? 1 : 0
  resource_id = aws_route_table.ha_sync_route_table_az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-ha-sync-rt-az2"
}

#====================================================================================================
# TRANSIT GATEWAY TAGS (conditional)
#====================================================================================================

resource "aws_ec2_tag" "transit_gateway" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.vpc-transit-gateway[0].tgw_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-tgw"
}

resource "aws_ec2_tag" "tgw_east_rtb" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = aws_ec2_transit_gateway_route_table.east[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-tgw-east-rtb"
}

resource "aws_ec2_tag" "tgw_west_rtb" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = aws_ec2_transit_gateway_route_table.west[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-tgw-west-rtb"
}

#====================================================================================================
# SPOKE VPC TAGS (conditional - East and West)
#====================================================================================================

# East VPC
resource "aws_ec2_tag" "east_vpc" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.vpc-east[0].vpc_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-vpc"
}

resource "aws_ec2_tag" "east_public_az1" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-east-public-az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-public-az1"
}

resource "aws_ec2_tag" "east_public_az2" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-east-public-az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-public-az2"
}

resource "aws_ec2_tag" "east_tgw_az1" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-east-tgw-az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-tgw-az1"
}

resource "aws_ec2_tag" "east_tgw_az2" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-east-tgw-az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-tgw-az2"
}

resource "aws_ec2_tag" "east_tgw_attachment" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-east-tgw-attachment"
}

# West VPC
resource "aws_ec2_tag" "west_vpc" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.vpc-west[0].vpc_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-vpc"
}

resource "aws_ec2_tag" "west_public_az1" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-west-public-az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-public-az1"
}

resource "aws_ec2_tag" "west_public_az2" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-west-public-az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-public-az2"
}

resource "aws_ec2_tag" "west_tgw_az1" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-west-tgw-az1[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-tgw-az1"
}

resource "aws_ec2_tag" "west_tgw_az2" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.subnet-west-tgw-az2[0].id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-tgw-az2"
}

resource "aws_ec2_tag" "west_tgw_attachment" {
  count       = var.enable_build_existing_subnets ? 1 : 0
  resource_id = module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id
  key         = "Fortinet-Role"
  value       = "${var.cp}-${var.env}-west-tgw-attachment"
}
