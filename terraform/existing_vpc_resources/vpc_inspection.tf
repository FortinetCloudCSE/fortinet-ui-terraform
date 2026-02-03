#
# access mode = nat_gw will create the nat gateway subnets, but we don't want to
# actually create the nat gateways (and charges) until the fortgates are in place to
# send traffic through them.
#
# NOTE: The vpc-inspection module always creates GWLB subnets regardless of deployment mode.
# For HA Pair deployments, these GWLB subnets are created but not used (no cost impact).
# The UI hides GWLB subnet outputs when HA Pair deployment is selected.

locals {
  enable_nat_gateway        = var.access_internet_mode == "nat_gw" ? true : false
  create_nat_gateway        = false
  # Auto-enable HA sync subnets when HA Pair deployment is enabled
  create_ha_sync_subnets    = var.enable_ha_pair_deployment ? true : var.enable_ha_sync_subnets
}
module "vpc-inspection" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_inspection_vpc"
  depends_on                       = [ module.vpc-transit-gateway.tgw_id,
                                       module.vpc-transit-gateway-attachment-west,
                                       module.vpc-transit-gateway-attachment-east]
  vpc_name                         = "${var.cp}-${var.env}-inspection"
  vpc_cidr                         = var.vpc_cidr_inspection
  subnet_bits                      = var.subnet_bits
  availability_zone_1              = local.availability_zone_1
  availability_zone_2              = local.availability_zone_2
  enable_nat_gateway               = local.enable_nat_gateway
  create_nat_gateway               = local.create_nat_gateway
  enable_dedicated_management_eni  = var.create_management_subnet_in_inspection_vpc
  named_tgw                        = var.attach_to_tgw_name
  enable_tgw_attachment            = var.enable_tgw_attachment
  create_gwlb_route_associations   = false
}

#
# if you are using the existing_vpc_resources template, setup the TGW route tables to route everything.
# If you are not using existing_vpc_resources template, the equivalent routes will need to be created manually.
#
resource "aws_ec2_transit_gateway_route" "inspection-route-to-west-tgw" {
  count                          = var.create_tgw_routes_for_existing ? 1 : 0
  depends_on                     = [module.vpc-inspection]
  destination_cidr_block         = var.vpc_cidr_west
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id
  transit_gateway_route_table_id = module.vpc-inspection.inspection_tgw_route_table_id
}
resource "aws_ec2_transit_gateway_route" "inspection-route-to-east-tgw" {
  count                          = var.create_tgw_routes_for_existing? 1 : 0
  depends_on                     = [module.vpc-inspection]
  destination_cidr_block         = var.vpc_cidr_east
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id
  transit_gateway_route_table_id = module.vpc-inspection.inspection_tgw_route_table_id
}

#====================================================================================================
# HA SYNC SUBNETS FOR FORTIGATE HA PAIR
#====================================================================================================

# HA Sync Subnet in AZ1
resource "aws_subnet" "ha_sync_subnet_az1" {
  count             = local.create_ha_sync_subnets ? 1 : 0
  vpc_id            = module.vpc-inspection.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr_inspection, var.subnet_bits, 10)
  availability_zone = local.availability_zone_1

  tags = {
    Name        = "${var.cp}-${var.env}-ha-sync-az1-subnet"
    Environment = var.env
    Terraform   = "true"
  }
}

# HA Sync Subnet in AZ2
resource "aws_subnet" "ha_sync_subnet_az2" {
  count             = local.create_ha_sync_subnets ? 1 : 0
  vpc_id            = module.vpc-inspection.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr_inspection, var.subnet_bits, 11)
  availability_zone = local.availability_zone_2

  tags = {
    Name        = "${var.cp}-${var.env}-ha-sync-az2-subnet"
    Environment = var.env
    Terraform   = "true"
  }
}

# Route table for HA sync subnet AZ1
resource "aws_route_table" "ha_sync_route_table_az1" {
  count  = local.create_ha_sync_subnets ? 1 : 0
  vpc_id = module.vpc-inspection.vpc_id

  tags = {
    Name        = "${var.cp}-${var.env}-ha-sync-az1-rtb"
    Environment = var.env
    Terraform   = "true"
  }
}

# Route table for HA sync subnet AZ2
resource "aws_route_table" "ha_sync_route_table_az2" {
  count  = local.create_ha_sync_subnets ? 1 : 0
  vpc_id = module.vpc-inspection.vpc_id

  tags = {
    Name        = "${var.cp}-${var.env}-ha-sync-az2-rtb"
    Environment = var.env
    Terraform   = "true"
  }
}

# Default route for HA sync AZ1 - use IGW for AWS API access
resource "aws_route" "ha_sync_default_route_az1" {
  count                  = local.create_ha_sync_subnets ? 1 : 0
  route_table_id         = aws_route_table.ha_sync_route_table_az1[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc-inspection.igw_id
}

# Default route for HA sync AZ2 - use IGW for AWS API access
resource "aws_route" "ha_sync_default_route_az2" {
  count                  = local.create_ha_sync_subnets ? 1 : 0
  route_table_id         = aws_route_table.ha_sync_route_table_az2[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc-inspection.igw_id
}

# Associate route table with HA sync subnet AZ1
resource "aws_route_table_association" "ha_sync_rtb_assoc_az1" {
  count          = local.create_ha_sync_subnets ? 1 : 0
  subnet_id      = aws_subnet.ha_sync_subnet_az1[0].id
  route_table_id = aws_route_table.ha_sync_route_table_az1[0].id
}

# Associate route table with HA sync subnet AZ2
resource "aws_route_table_association" "ha_sync_rtb_assoc_az2" {
  count          = local.create_ha_sync_subnets ? 1 : 0
  subnet_id      = aws_subnet.ha_sync_subnet_az2[0].id
  route_table_id = aws_route_table.ha_sync_route_table_az2[0].id
}
