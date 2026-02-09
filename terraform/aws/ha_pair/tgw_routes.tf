#====================================================================================================
# TRANSIT GATEWAY ROUTE UPDATES FOR HA PAIR
#====================================================================================================
# When deploying HA pair, update the default routes in the east/west TGW route tables
# to point to the inspection VPC attachment instead of management VPC attachment.
# This allows traffic from spoke VPCs to flow through the FortiGate HA pair.
#====================================================================================================

# Discover the east and west TGW route tables
data "aws_ec2_transit_gateway_route_table" "east_tgw_route_table" {
  count = var.update_tgw_routes ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-east-tgw-rtb"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ec2_transit_gateway_route_table" "west_tgw_route_table" {
  count = var.update_tgw_routes ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-west-tgw-rtb"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Delete existing default route from east TGW route table before creating new one
# This removes the route pointing to management VPC
resource "null_resource" "delete_existing_east_default_route" {
  count = var.update_tgw_routes ? 1 : 0

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

# Create new default route in east TGW route table pointing to inspection VPC
resource "aws_ec2_transit_gateway_route" "default_route_east_tgw_attachment" {
  count      = var.update_tgw_routes ? 1 : 0
  depends_on = [null_resource.delete_existing_east_default_route]

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.east_tgw_route_table[0].id
}

# Delete existing default route from west TGW route table before creating new one
# This removes the route pointing to management VPC
resource "null_resource" "delete_existing_west_default_route" {
  count = var.update_tgw_routes ? 1 : 0

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

# Create new default route in west TGW route table pointing to inspection VPC
resource "aws_ec2_transit_gateway_route" "default_route_west_tgw_attachment" {
  count      = var.update_tgw_routes ? 1 : 0
  depends_on = [null_resource.delete_existing_west_default_route]

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpc_attachment.inspection_tgw_attachment.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.west_tgw_route_table[0].id
}
