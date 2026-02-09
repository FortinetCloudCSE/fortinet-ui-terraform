
locals {
    common_tags = {
    Environment = var.env
  }
}

locals {
  availability_zone_1 = "${var.aws_region}${var.availability_zone_1}"
}

locals {
  availability_zone_2 = "${var.aws_region}${var.availability_zone_2}"
}

locals {
    public_subnet_index = 0
}
locals {
  tgw_subnet_index = 2
}
locals {
  east_public_subnet_cidr_az1 = cidrsubnet(var.vpc_cidr_east, var.spoke_subnet_bits, local.public_subnet_index)
}
locals {
  east_tgw_subnet_cidr_az1 = cidrsubnet(var.vpc_cidr_east, var.spoke_subnet_bits, local.public_subnet_index + 1)
}

locals {
  east_public_subnet_cidr_az2 = cidrsubnet(var.vpc_cidr_east, var.spoke_subnet_bits, local.public_subnet_index + 2)
}
locals {
  east_tgw_subnet_cidr_az2 = cidrsubnet(var.vpc_cidr_east, var.spoke_subnet_bits, local.public_subnet_index + 3)
}

#
# east VPC
#
module "vpc-east" {
  source     = "git::https://github.com/40netse/terraform-modules.git//aws_vpc"
  count      = var.enable_build_existing_subnets ? 1 : 0
  depends_on = [ module.vpc-transit-gateway.tgw_id ]
  vpc_name   = "${var.cp}-${var.env}-east-vpc"
  vpc_cidr   = var.vpc_cidr_east
}

module "subnet-east-tgw-az1" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_subnet"
  count  = var.enable_build_existing_subnets ? 1 : 0

  subnet_name       = "${var.cp}-${var.env}-east-tgw-az1-subnet"
  vpc_id            = module.vpc-east[0].vpc_id
  availability_zone = local.availability_zone_1
  subnet_cidr       = local.east_tgw_subnet_cidr_az1
}

module "subnet-east-tgw-az2" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_subnet"
  count  = var.enable_build_existing_subnets ? 1 : 0

  subnet_name                = "${var.cp}-${var.env}-east-tgw-az2-subnet"

  vpc_id                     = module.vpc-east[0].vpc_id
  availability_zone          = local.availability_zone_2
  subnet_cidr                = local.east_tgw_subnet_cidr_az2
}

module "subnet-east-public-az1" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_subnet"
  count  = var.enable_build_existing_subnets ? 1 : 0

  subnet_name       = "${var.cp}-${var.env}-east-public-az1-subnet"
  vpc_id            = module.vpc-east[0].vpc_id
  availability_zone = local.availability_zone_1
  subnet_cidr       = local.east_public_subnet_cidr_az1
}
module "subnet-east-public-az2" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_subnet"
  count  = var.enable_build_existing_subnets ? 1 : 0

  subnet_name                = "${var.cp}-${var.env}-east-public-az2-subnet"

  vpc_id                     = module.vpc-east[0].vpc_id
  availability_zone          = local.availability_zone_2
  subnet_cidr                = local.east_public_subnet_cidr_az2
}

#
# Default route table that is created with the main VPC.
#
resource "aws_default_route_table" "route_east" {
  count                  = var.enable_build_existing_subnets ? 1 : 0
  default_route_table_id = module.vpc-east[0].vpc_main_route_table_id
  tags = {
    Name = "${var.cp}-${var.env}-east-vpc-main-route-table"
  }
}

resource "aws_route" "default-route-east-public" {
  depends_on             = [module.vpc-transit-gateway-attachment-east]
  count                  = var.enable_build_existing_subnets ? 1 : 0
  route_table_id         = module.vpc-east[0].vpc_main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = module.vpc-transit-gateway[0].tgw_id
}
resource "aws_route" "management-route-east-public" {
  depends_on             = [module.vpc-transit-gateway-attachment-east]
  count                  = var.enable_build_management_vpc ? 1 : 0
  route_table_id         = module.vpc-east[0].vpc_main_route_table_id
  destination_cidr_block = var.vpc_cidr_management
  transit_gateway_id     = module.vpc-transit-gateway[0].tgw_id
}


