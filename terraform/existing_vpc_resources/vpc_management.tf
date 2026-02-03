locals {
  rfc1918_192 = "192.168.0.0/16"
}
locals {
  rfc1918_10 = "10.0.0.0/8"
}
locals {
  rfc1918_172 = "172.16.0.0/12"
}
resource "random_string" "random" {
  length           = 5
  special          = false
}

locals {
  faz_template_file = var.enable_fortianalyzer ? templatefile("${path.module}/config_templates/faz-userdata.tftpl", {
    faz_license_file   = var.fortianalyzer_license_file
    faz_vm_name        = var.fortianalyzer_vm_name
    faz_admin_password = var.fortianalyzer_admin_password
  }) :  null
  fmgr_template_file = var.enable_fortimanager ? templatefile("${path.module}/config_templates/fmgr-userdata.tftpl", {
    fmg_license_file   = var.fortimanager_license_file
    fmg_vm_name        = var.fortimanager_vm_name
    fmg_admin_password = var.fortimanager_admin_password
  }) : null
  jump_box_template_file = var.enable_jump_box ? templatefile("${path.module}/config_templates/jump-box-userdata.tpl", {
    region             = var.aws_region
    availability_zone  = var.availability_zone_1
  }) : null
}
module "vpc-management" {
  source                         = "git::https://github.com/40netse/terraform-modules.git//aws_management_vpc"
  count                          = var.enable_build_management_vpc ? 1 : 0
  depends_on                     = [ module.vpc-transit-gateway.tgw_id ]
  aws_region                     = var.aws_region
  cp                             = var.cp
  env                            = var.env
  vpc_name                       = "${var.cp}-${var.env}-management"
  vpc_cidr                       = var.vpc_cidr_management
  vpc_cidr_sg                    = concat(var.management_cidr_sg, [var.vpc_cidr_east, var.vpc_cidr_west])
  subnet_bits                    = var.subnet_bits
  availability_zone_1            = local.availability_zone_1
  availability_zone_2            = local.availability_zone_2
  named_tgw                      = var.attach_to_tgw_name
  enable_tgw_attachment          = var.enable_management_tgw_attachment
  acl                            = var.acl
  random_string                  = random_string.random.result
  keypair                        = var.keypair
  enable_fortianalyzer           = var.enable_fortianalyzer
  enable_fortianalyzer_public_ip = var.enable_fortianalyzer_public_ip
  enable_fortimanager            = var.enable_fortimanager
  enable_fortimanager_public_ip  = var.enable_fortimanager_public_ip
  enable_jump_box                = var.enable_jump_box
  enable_jump_box_public_ip      = var.enable_jump_box_public_ip
  fortianalyzer_host_ip          = var.fortianalyzer_host_ip
  fortianalyzer_instance_type    = var.fortianalyzer_instance_type
  fortianalyzer_os_version       = var.fortianalyzer_os_version
  fortianalyzer_user_data        = local.faz_template_file
  fortimanager_host_ip           = var.fortimanager_host_ip
  fortimanager_instance_type     = var.fortimanager_instance_type
  fortimanager_os_version        = var.fortimanager_os_version
  fortimanager_user_data         = local.fmgr_template_file
  linux_host_ip                  = var.linux_host_ip
  linux_instance_type            = var.linux_instance_type
  linux_user_data                = local.jump_box_template_file
}
resource "aws_route" "management-public-default-route-igw" {
  depends_on             = [module.vpc-management]
  count                  = var.enable_build_management_vpc ? 1 : 0
  route_table_id         = module.vpc-management[0].route_table_management_public
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.vpc-management[0].igw_id
}
resource "aws_route" "management-public-route-to-east-spoke" {
  depends_on             = [module.vpc-management]
  count                  = (var.enable_management_tgw_attachment && var.enable_build_management_vpc && var.enable_build_existing_subnets) ? 1 : 0
  route_table_id         = module.vpc-management[0].route_table_management_public
  destination_cidr_block = var.vpc_cidr_east
  transit_gateway_id     = module.vpc-transit-gateway[0].tgw_id
}
resource "aws_route" "management-public-route-to-west-spoke" {
  depends_on             = [module.vpc-management]
  count                  = (var.enable_management_tgw_attachment && var.enable_build_management_vpc && var.enable_build_existing_subnets) ? 1 : 0
  route_table_id         = module.vpc-management[0].route_table_management_public
  destination_cidr_block = var.vpc_cidr_west
  transit_gateway_id     = module.vpc-transit-gateway[0].tgw_id
}
resource "aws_ec2_transit_gateway_route" "route-to-west-tgw" {
  count                          = (var.enable_management_tgw_attachment && var.enable_build_management_vpc && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [module.vpc-management]
  destination_cidr_block         = var.vpc_cidr_west
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-west[0].tgw_attachment_id
  transit_gateway_route_table_id = module.vpc-management[0].management_tgw_route_table_id
}
resource "aws_ec2_transit_gateway_route" "route-to-east-tgw" {
  count                          = (var.enable_management_tgw_attachment && var.enable_build_management_vpc && var.enable_build_existing_subnets) ? 1 : 0
  depends_on                     = [module.vpc-management]
  destination_cidr_block         = var.vpc_cidr_east
  transit_gateway_attachment_id  = module.vpc-transit-gateway-attachment-east[0].tgw_attachment_id
  transit_gateway_route_table_id = module.vpc-management[0].management_tgw_route_table_id
}
