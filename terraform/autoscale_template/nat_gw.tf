locals {
  nat_gw_subnet_az1_name   = "${var.cp}-${var.env}-inspection-natgw-az1-subnet"
  nat_gw_subnet_az2_name   = "${var.cp}-${var.env}-inspection-natgw-az2-subnet"
  enable_nat_gateway       = length(data.aws_subnet.inspection_nat_gw_subnet_az1) > 0 ? true : false
}
data "aws_subnet" "inspection_nat_gw_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = [local.nat_gw_subnet_az1_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_subnet" "inspection_nat_gw_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = [local.nat_gw_subnet_az2_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  vpc_id = data.aws_vpc.inspection_vpc.id
}
resource "aws_eip" "nat-gateway-az1" {
  count = local.enable_nat_gateway ? 1 : 0
}
resource "aws_nat_gateway" "vpc-az1" {
  count             = local.enable_nat_gateway ? 1 : 0
  allocation_id     = aws_eip.nat-gateway-az1[0].id
  subnet_id         = data.aws_subnet.inspection_nat_gw_subnet_az1.id
  tags = {
    Name = "${local.inspection_vpc}-nat-gw-az1"
  }
}
resource "aws_eip" "nat-gateway-az2" {
  count = local.enable_nat_gateway ? 1 : 0
}
resource "aws_nat_gateway" "vpc-az2" {
  count             = local.enable_nat_gateway ? 1 : 0
  allocation_id     = aws_eip.nat-gateway-az2[0].id
  subnet_id         = data.aws_subnet.inspection_nat_gw_subnet_az2.id
  tags = {
    Name = "${local.inspection_vpc}-nat-gw-az2"
  }
}

data "aws_route_table" "inspection_public_route_table_az1" {
  subnet_id = data.aws_subnet.inspection_public_subnet_az1.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}
data "aws_route_table" "inspection_public_route_table_az2" {
  subnet_id = data.aws_subnet.inspection_public_subnet_az2.id
  vpc_id = data.aws_vpc.inspection_vpc.id
}


