
module "vpc-transit-gateway" {
  source                          = "git::https://github.com/40netse/terraform-modules.git//aws_tgw"
  count                           = var.enable_build_existing_subnets ? 1 : 0
  tgw_name                        = "${var.cp}-${var.env}-tgw"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "disable"
}

#
# East VPC Transit Gateway Attachment, Route Table and Routes
#
module "vpc-transit-gateway-attachment-east" {
  source                         = "git::https://github.com/40netse/terraform-modules.git//aws_tgw_attachment"
  count                          = var.enable_build_existing_subnets ? 1 : 0
  depends_on                     = [module.vpc-transit-gateway,
                                    module.subnet-east-tgw-az1,
                                    module.subnet-east-tgw-az2]
  tgw_attachment_name            = "${var.cp}-${var.env}-east-tgw-attachment"
  transit_gateway_id             = module.vpc-transit-gateway[0].tgw_id
  subnet_ids                     = [ module.subnet-east-tgw-az1[0].id, module.subnet-east-tgw-az2[0].id ]
  transit_gateway_default_route_table_propogation = "true"
  appliance_mode_support                          = "enable"
  vpc_id                                          = module.vpc-east[0].vpc_id
}

resource "aws_ec2_transit_gateway_route_table" "east" {
  count                           = var.enable_build_existing_subnets ? 1 : 0
  transit_gateway_id              = module.vpc-transit-gateway[0].tgw_id
  tags = {
      Name = "${var.cp}-${var.env}-east-tgw-rtb"
  }
}
resource "aws_ec2_transit_gateway_route_table_association" "east" {
  count                          = var.enable_build_existing_subnets ? 1 : 0
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.east[0].id
}
resource "aws_ec2_transit_gateway_route" "mgmt-cidr-route-east-tgw" {
  count                          = (var.enable_build_management_vpc && var.enable_management_tgw_attachment && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.east]
  destination_cidr_block         = var.vpc_cidr_management
  transit_gateway_attachment_id  = module.vpc-management[0].management_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.east[0].id
}
resource "aws_ec2_transit_gateway_route" "default-route-east-tgw" {
  count                          = (var.enable_build_management_vpc && var.enable_management_tgw_attachment && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.east]
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.vpc-management[0].management_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.east[0].id
}
resource "aws_ec2_transit_gateway_route" "default-route-east-inspection-tgw" {
  count                          = (!var.enable_build_management_vpc || !var.enable_management_tgw_attachment || !var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.east]
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.vpc-inspection.inspection_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.east[0].id
}
#
# West VPC Transit Gateway Attachment, Route Table and Routes
#
module "vpc-transit-gateway-attachment-west" {
  source               = "git::https://github.com/40netse/terraform-modules.git//aws_tgw_attachment"
  count                = var.enable_build_existing_subnets ? 1 : 0
  depends_on           = [module.vpc-transit-gateway,
                          module.subnet-west-tgw-az1,
                          module.subnet-west-tgw-az2]
  tgw_attachment_name  = "${var.cp}-${var.env}-west-tgw-attachment"

  transit_gateway_id   = module.vpc-transit-gateway[0].tgw_id
  subnet_ids           = [ module.subnet-west-tgw-az1[0].id, module.subnet-west-tgw-az2[0].id ]
  transit_gateway_default_route_table_propogation = "true"
  appliance_mode_support                          = "enable"
  vpc_id                                          = module.vpc-west[0].vpc_id
}

resource "aws_ec2_transit_gateway_route_table" "west" {
  count                           = var.enable_build_existing_subnets ? 1 : 0
  transit_gateway_id              = module.vpc-transit-gateway[0].tgw_id
  tags = {
    Name = "${var.cp}-${var.env}-west-tgw-rtb"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "west" {
  count                          = var.enable_build_existing_subnets ? 1 : 0
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.west[0].id
}
resource "aws_ec2_transit_gateway_route" "mgmt-cidr-route-west-tgw" {
  count                          = (var.enable_build_management_vpc && var.enable_management_tgw_attachment && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.west]
  destination_cidr_block         = var.vpc_cidr_management
  transit_gateway_attachment_id  = module.vpc-management[0].management_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.west[0].id
}
resource "aws_ec2_transit_gateway_route" "mgmt-cidr-route-west-inspection-tgw" {
  count                          = (!var.enable_build_management_vpc || !var.enable_management_tgw_attachment || !var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.west]
  destination_cidr_block         = var.vpc_cidr_management
  transit_gateway_attachment_id  = module.vpc-inspection.inspection_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.west[0].id
}
resource "aws_ec2_transit_gateway_route" "default-route-west-tgw" {
  count                          = (var.enable_build_management_vpc && var.enable_management_tgw_attachment && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.west]
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.vpc-management[0].management_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.west[0].id
}
resource "aws_ec2_transit_gateway_route" "default-route-west-inspection-tgw" {
  count                          = (!var.enable_build_management_vpc || !var.enable_management_tgw_attachment || !var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [aws_ec2_transit_gateway_route_table.west]
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.vpc-inspection.inspection_tgw_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.west[0].id
}

