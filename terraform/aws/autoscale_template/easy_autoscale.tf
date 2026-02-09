
locals {
    common_tags = {
    Environment = var.env
  }
}

check "config_validation" {
  assert {
    condition = !(var.enable_dedicated_management_eni && var.enable_dedicated_management_vpc)
    error_message = "Cannot enable both dedicated management VPC and dedicated management ENI"
  }
  assert {
    condition = var.firewall_policy_mode == "1-arm" || var.firewall_policy_mode == "2-arm"
    error_message = "access_internet_mode must be '1-arm' or '2-arm'"
  }
}

locals {
  availability_zone_1  = "${var.aws_region}${var.availability_zone_1}"
  availability_zone_2  = "${var.aws_region}${var.availability_zone_2}"
  access_internet_mode = local.enable_nat_gateway ? "nat_gw" : "eip"
}

locals {
  dedicated_mgmt = var.enable_dedicated_management_vpc ? "-wdm" : var.enable_dedicated_management_eni ? "-wdm-eni" : ""
  fgt_config_file           = "./${var.firewall_policy_mode}${local.dedicated_mgmt}-${var.base_config_file}"
  management_device_index   = var.firewall_policy_mode == "2-arm" ? 2 : 1

  # Fortinet-Role tag patterns for resource discovery
  # Format: {cp}-{env}-{resource-type}-{details}
  management_vpc            = "${var.cp}-${var.env}-management-vpc"
  inspection_vpc            = "${var.cp}-${var.env}-inspection-vpc"
  east_vpc                  = "${var.cp}-${var.env}-east-vpc"
  west_vpc                  = "${var.cp}-${var.env}-west-vpc"
  inspection_igw            = "${var.cp}-${var.env}-inspection-igw"
  inspection_public_az1     = "${var.cp}-${var.env}-inspection-public-az1"
  inspection_public_az2     = "${var.cp}-${var.env}-inspection-public-az2"
  inspection_gwlbe_az1      = "${var.cp}-${var.env}-inspection-gwlbe-az1"
  inspection_gwlbe_az2      = "${var.cp}-${var.env}-inspection-gwlbe-az2"
  inspection_private_az1    = "${var.cp}-${var.env}-inspection-private-az1"
  inspection_private_az2    = "${var.cp}-${var.env}-inspection-private-az2"
  inspection_tgw_attachment = "${var.cp}-${var.env}-inspection-tgw-attachment"
  tgw                       = "${var.cp}-${var.env}-tgw"
  tgw_east_rtb              = "${var.cp}-${var.env}-tgw-east-rtb"
  tgw_west_rtb              = "${var.cp}-${var.env}-tgw-west-rtb"
}

locals {
  management_public_az1                = "${var.cp}-${var.env}-management-public-az1"
  management_public_az2                = "${var.cp}-${var.env}-management-public-az2"
  inspection_management_az1            = "${var.cp}-${var.env}-inspection-management-az1"
  inspection_management_az2            = "${var.cp}-${var.env}-inspection-management-az2"
}
data "aws_vpc" "management_vpc" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_vpcs"  "check_ew_vpcs" {
    filter {
        name   = "tag:Fortinet-Role"
        values = [local.east_vpc, local.west_vpc]
    }
}
data "aws_vpc" "east_vpc" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.east_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_vpc" "west_vpc" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.west_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_ec2_transit_gateway_route_table" "east_tgw_route_table" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.tgw_east_rtb]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_ec2_transit_gateway_route_table" "west_tgw_route_table" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.tgw_west_rtb]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_ec2_transit_gateway_vpc_attachment" "inspection_tgw_attachment" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_tgw_attachment]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "management_public_subnet_az1" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_public_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "management_public_subnet_az2" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.management_public_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_vpc" "inspection_vpc" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
locals {
  inspection_vpc_cidr = data.aws_vpc.inspection_vpc.cidr_block
}
data "aws_internet_gateway" "inspection_igw" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_igw]
  }
}
data "aws_ec2_transit_gateway" "existing_tgw" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.tgw]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "inspection_public_subnet_az1" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_public_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_public_subnet_az2" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_public_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_gwlbe_subnet_az1" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_gwlbe_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_gwlbe_subnet_az2" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_gwlbe_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_private_subnet_az1" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_private_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_private_subnet_az2" {
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_private_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_management_subnet_az1" {
  depends_on = [data.aws_vpc.inspection_vpc]
  count = var.enable_dedicated_management_eni ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_management_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_management_subnet_az2" {
  depends_on = [data.aws_vpc.inspection_vpc]
  count = var.enable_dedicated_management_eni ? 1 : 0
  filter {
    name   = "tag:Fortinet-Role"
    values = [local.inspection_management_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_vpc_endpoint" "gwlb_endpoint_az1" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  vpc_id = data.aws_vpc.inspection_vpc.id

  filter {
    name   = "tag:Name"
    values = [var.endpoint_name_az1]
  }
}
data "aws_vpc_endpoint" "gwlb_endpoint_az2" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  vpc_id = data.aws_vpc.inspection_vpc.id

  filter {
    name   = "tag:Name"
    values = [var.endpoint_name_az2]
  }
}
resource "random_string" "random" {
  length           = 5
  special          = false
}
data "aws_route_table" "inspection_private_route_table_az1" {
  subnet_id = data.aws_subnet.inspection_private_subnet_az1.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_route_table" "inspection_private_route_table_az2" {
  subnet_id = data.aws_subnet.inspection_private_subnet_az2.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_route_table" "inspection_gwlb_route_table_az1" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  subnet_id = data.aws_subnet.inspection_gwlbe_subnet_az1.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_route_table" "inspection_gwlb_route_table_az2" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  subnet_id = data.aws_subnet.inspection_gwlbe_subnet_az2.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}
resource "aws_route" "inspection-gwlb-spoke-route-east-az1" {
  route_table_id         = data.aws_route_table.inspection_gwlb_route_table_az1.id
  destination_cidr_block = data.aws_vpc.east_vpc[0].cidr_block
  transit_gateway_id     = data.aws_ec2_transit_gateway.existing_tgw.id
}
resource "aws_route" "inspection-gwlb-spoke-route-west-az1" {
  route_table_id         = data.aws_route_table.inspection_gwlb_route_table_az1.id
  destination_cidr_block = data.aws_vpc.west_vpc[0].cidr_block
  transit_gateway_id     = data.aws_ec2_transit_gateway.existing_tgw.id
}
resource "aws_route" "inspection-gwlb-spoke-route-east-az2" {
  route_table_id         = data.aws_route_table.inspection_gwlb_route_table_az2.id
  destination_cidr_block = data.aws_vpc.east_vpc[0].cidr_block
  transit_gateway_id     = data.aws_ec2_transit_gateway.existing_tgw.id
}
resource "aws_route" "inspection-gwlb-spoke-route-west-az2" {
  route_table_id         = data.aws_route_table.inspection_gwlb_route_table_az2.id
  destination_cidr_block = data.aws_vpc.west_vpc[0].cidr_block
  transit_gateway_id     = data.aws_ec2_transit_gateway.existing_tgw.id
}

# Delete existing default route from east TGW route table before creating new one
resource "null_resource" "delete_existing_east_default_route" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 delete-transit-gateway-route \
        --transit-gateway-route-table-id ${data.aws_ec2_transit_gateway_route_table.east_tgw_route_table[0].id} \
        --destination-cidr-block 0.0.0.0/0 \
        --region ${var.aws_region} 2>/dev/null || true
    EOT
  }

  triggers = {
    # Always run when the route table or inspection attachment changes
    route_table_id = data.aws_ec2_transit_gateway_route_table.east_tgw_route_table[0].id
    attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  }
}

resource "aws_ec2_transit_gateway_route" "default-route-east-tgw-attachment" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  depends_on = [null_resource.delete_existing_east_default_route]

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.east_tgw_route_table[0].id
}

# Delete existing default route from west TGW route table before creating new one
resource "null_resource" "delete_existing_west_default_route" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 delete-transit-gateway-route \
        --transit-gateway-route-table-id ${data.aws_ec2_transit_gateway_route_table.west_tgw_route_table[0].id} \
        --destination-cidr-block 0.0.0.0/0 \
        --region ${var.aws_region} 2>/dev/null || true
    EOT
  }

  triggers = {
    # Always run when the route table or inspection attachment changes
    route_table_id = data.aws_ec2_transit_gateway_route_table.west_tgw_route_table[0].id
    attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  }
}

resource "aws_ec2_transit_gateway_route" "default-route-west-tgw-attachment" {
  count = length(data.aws_vpcs.check_ew_vpcs.ids) > 0 ? 1 : 0
  depends_on = [null_resource.delete_existing_west_default_route]

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.west_tgw_route_table[0].id
}
resource "aws_route" "inspection-ns-private-default-route-gwlbe-az1" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  route_table_id         = data.aws_route_table.inspection_private_route_table_az1.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = data.aws_vpc_endpoint.gwlb_endpoint_az1.id
}
resource "aws_route" "inspection-ns-private-default-route-gwlbe-az2" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]
  route_table_id         = data.aws_route_table.inspection_private_route_table_az2.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = data.aws_vpc_endpoint.gwlb_endpoint_az2.id
}
resource "aws_route" "inspection-ns-public-default-route-igw-az1" {
  count                  = !local.enable_nat_gateway ? 1 : 0
  route_table_id         = data.aws_route_table.inspection_public_route_table_az1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = data.aws_internet_gateway.inspection_igw.id
}
resource "aws_route" "inspection-ns-public-default-route-igw-az2" {
  count                  = !local.enable_nat_gateway ? 1 : 0
  route_table_id         = data.aws_route_table.inspection_public_route_table_az2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = data.aws_internet_gateway.inspection_igw.id
}
resource "aws_route" "inspection-ns-public-default-route-ngw-az1" {
  count                  = local.enable_nat_gateway ? 1 : 0
  depends_on             =  [aws_nat_gateway.vpc-az1]
  route_table_id         = data.aws_route_table.inspection_public_route_table_az1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.vpc-az1[0].id
}
resource "aws_route" "inspection-ns-public-default-route-ngw-az2" {
  count                  = local.enable_nat_gateway ? 1 : 0
  depends_on             = [aws_nat_gateway.vpc-az2]
  route_table_id         = data.aws_route_table.inspection_public_route_table_az2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.vpc-az2[0].id
}

#
# ================================================================================
# DISTRIBUTED EGRESS VPC DISCOVERY
# ================================================================================
# Discover distributed egress VPCs by purpose tag and build spk_vpc configuration
# VPCs are tagged with purpose=distributed_egress by existing_vpc_resources
#

# Discover all VPCs with purpose=distributed_egress tag
data "aws_vpcs" "distributed_vpcs" {
  count = var.enable_distributed_inspection ? 1 : 0

  filter {
    name   = "tag:purpose"
    values = ["distributed_egress"]
  }
}

# For each distributed VPC, discover its details
data "aws_vpc" "distributed" {
  for_each = var.enable_distributed_inspection ? toset(data.aws_vpcs.distributed_vpcs[0].ids) : toset([])
  id       = each.value
}

# Discover GWLBE subnets for each distributed VPC using fortigatecnf_subnet_type=endpoint tag
data "aws_subnets" "distributed_gwlbe" {
  for_each = var.enable_distributed_inspection ? data.aws_vpc.distributed : {}

  filter {
    name   = "vpc-id"
    values = [each.value.id]
  }

  filter {
    name   = "tag:fortigatecnf_subnet_type"
    values = ["endpoint"]
  }
}

# Build the spk_vpc configuration map for the upstream module
# Structure matches upstream module expectation:
#   spk_vpc = {
#     "vpc_name" = {
#       vpc_id = "vpc-123456789"
#       subnet_ids = ["subnet-123456789", "subnet-987654321"]
#     }
#   }
locals {
  # Extract VPC names and build spk_vpc map
  distributed_spk_vpc = var.enable_distributed_inspection ? {
    for vpc_id, vpc_data in data.aws_vpc.distributed :
    vpc_data.tags["Name"] => {
      vpc_id     = vpc_id
      subnet_ids = data.aws_subnets.distributed_gwlbe[vpc_id].ids
    }
  } : {}
}

# ================================================================================
# ASG TERMINATION POLICY CONFIGURATION
# ================================================================================
# Set ASG termination policy to NewestInstance after module deployment
# This ensures scale-in removes the most recently launched instances first
#
resource "null_resource" "set_asg_termination_policy" {
  depends_on = [module.spk_tgw_gwlb_asg_fgt_igw]

  provisioner "local-exec" {
    command = <<-EOT
      ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
        --query "AutoScalingGroups[?contains(AutoScalingGroupName,'${var.asg_module_prefix}')].AutoScalingGroupName" \
        --output text \
        --region ${var.aws_region})

      if [ -n "$ASG_NAME" ]; then
        aws autoscaling update-auto-scaling-group \
          --auto-scaling-group-name "$ASG_NAME" \
          --termination-policies "NewestInstance" \
          --region ${var.aws_region}
        echo "Set termination policy to NewestInstance for ASG: $ASG_NAME"
      else
        echo "Warning: Could not find ASG with prefix ${var.asg_module_prefix}"
      fi
    EOT
  }

  triggers = {
    # Re-run if the module prefix changes
    asg_prefix = var.asg_module_prefix
  }
}