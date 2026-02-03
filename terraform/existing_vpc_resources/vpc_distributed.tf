#
# Distributed Egress VPCs (not attached to TGW)
# These VPCs use GWLB endpoints for bump-in-the-wire inspection
# Traffic hairpins through FortiGates and egresses via local IGW/NAT
#

locals {
  # Build list of CIDRs based on count (max 3)
  distributed_egress_vpc_cidrs = var.enable_distributed_egress_vpcs ? slice([
    var.distributed_egress_vpc_1_cidr,
    var.distributed_egress_vpc_2_cidr,
    var.distributed_egress_vpc_3_cidr,
  ], 0, var.distributed_egress_vpc_count) : []

  distributed_vpc_count = length(local.distributed_egress_vpc_cidrs)

  # Subnet indices: 0-1 = public (az1,az2), 2-3 = private (az1,az2), 4-5 = gwlbe (az1,az2)
  distributed_public_index  = 0
  distributed_private_index = 2
  distributed_gwlbe_index   = 4

  # Instance count - only create if both distributed VPCs and Linux instances are enabled
  distributed_instance_count = var.enable_distributed_linux_instances ? local.distributed_vpc_count : 0
}

#
# VPCs
#
resource "aws_vpc" "distributed" {
  count      = local.distributed_vpc_count
  cidr_block = local.distributed_egress_vpc_cidrs[count.index]

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-vpc"
    Environment = var.env
    purpose     = "distributed_egress"
  }
}

#
# Internet Gateways
#
resource "aws_internet_gateway" "distributed" {
  count  = local.distributed_vpc_count
  vpc_id = aws_vpc.distributed[count.index].id

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-igw"
    Environment = var.env
  }
}

#
# Public Subnets (AZ1 and AZ2)
#
resource "aws_subnet" "distributed_public_az1" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_public_index)
  availability_zone = local.availability_zone_1

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-public-az1-subnet"
    Environment = var.env
  }
}

resource "aws_subnet" "distributed_public_az2" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_public_index + 1)
  availability_zone = local.availability_zone_2

  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-public-az2-subnet"
    Environment = var.env
  }
}

#
# Private Subnets (AZ1 and AZ2) - For workload instances
#
resource "aws_subnet" "distributed_private_az1" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_private_index)
  availability_zone = local.availability_zone_1

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-private-az1-subnet"
    Environment = var.env
  }
}

resource "aws_subnet" "distributed_private_az2" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_private_index + 1)
  availability_zone = local.availability_zone_2

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-private-az2-subnet"
    Environment = var.env
  }
}

resource "aws_route" "distributed_private_to_igw_az1" {
  count                  = local.distributed_vpc_count
  route_table_id         = aws_route_table.distributed_private_az1[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.distributed[count.index].id
}

resource "aws_route" "distributed_private_to_igw_az2" {
  count                  = local.distributed_vpc_count
  route_table_id         = aws_route_table.distributed_private_az2[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.distributed[count.index].id
}

#
# GWLBE Subnets (AZ1 and AZ2) - For Gateway Load Balancer Endpoints
#
resource "aws_subnet" "distributed_gwlbe_az1" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_gwlbe_index)
  availability_zone = local.availability_zone_1

  tags = {
    Name                      = "${var.cp}-${var.env}-distributed-${count.index + 1}-gwlbe-az1-subnet"
    Environment               = var.env
    fortigatecnf_subnet_type  = "endpoint"
  }
}

resource "aws_subnet" "distributed_gwlbe_az2" {
  count             = local.distributed_vpc_count
  vpc_id            = aws_vpc.distributed[count.index].id
  cidr_block        = cidrsubnet(local.distributed_egress_vpc_cidrs[count.index], var.distributed_egress_subnet_bits, local.distributed_gwlbe_index + 1)
  availability_zone = local.availability_zone_2

  tags = {
    Name                      = "${var.cp}-${var.env}-distributed-${count.index + 1}-gwlbe-az2-subnet"
    Environment               = var.env
    fortigatecnf_subnet_type  = "endpoint"
  }
}

#
# Route Tables for Public Subnets
# NOTE: Routes to GWLBE will be added by autoscale_template module
#
resource "aws_route_table" "distributed_public_az1" {
  count  = local.distributed_vpc_count
  vpc_id = aws_vpc.distributed[count.index].id

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-public-az1-rtb"
    Environment = var.env
  }
}

resource "aws_route_table" "distributed_public_az2" {
  count  = local.distributed_vpc_count
  vpc_id = aws_vpc.distributed[count.index].id

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-public-az2-rtb"
    Environment = var.env
  }
}

# Default route to IGW for public subnets
resource "aws_route" "distributed_public_to_igw_az1" {
  count                  = local.distributed_vpc_count
  route_table_id         = aws_route_table.distributed_public_az1[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.distributed[count.index].id
}

resource "aws_route" "distributed_public_to_igw_az2" {
  count                  = local.distributed_vpc_count
  route_table_id         = aws_route_table.distributed_public_az2[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.distributed[count.index].id
}

# Associate public subnets with route tables
resource "aws_route_table_association" "distributed_public_az1" {
  count          = local.distributed_vpc_count
  subnet_id      = aws_subnet.distributed_public_az1[count.index].id
  route_table_id = aws_route_table.distributed_public_az1[count.index].id
}

resource "aws_route_table_association" "distributed_public_az2" {
  count          = local.distributed_vpc_count
  subnet_id      = aws_subnet.distributed_public_az2[count.index].id
  route_table_id = aws_route_table.distributed_public_az2[count.index].id
}

#
# Route Tables for Private Subnets
# NOTE: Routes to GWLBE will be added by autoscale_template module
#
resource "aws_route_table" "distributed_private_az1" {
  count  = local.distributed_vpc_count
  vpc_id = aws_vpc.distributed[count.index].id

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-private-az1-rtb"
    Environment = var.env
  }
}

resource "aws_route_table" "distributed_private_az2" {
  count  = local.distributed_vpc_count
  vpc_id = aws_vpc.distributed[count.index].id

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-private-az2-rtb"
    Environment = var.env
  }
}

# Associate private subnets with route tables
resource "aws_route_table_association" "distributed_private_az1" {
  count          = local.distributed_vpc_count
  subnet_id      = aws_subnet.distributed_private_az1[count.index].id
  route_table_id = aws_route_table.distributed_private_az1[count.index].id
}

resource "aws_route_table_association" "distributed_private_az2" {
  count          = local.distributed_vpc_count
  subnet_id      = aws_subnet.distributed_private_az2[count.index].id
  route_table_id = aws_route_table.distributed_private_az2[count.index].id
}

#
# Security Group for test instances
#
resource "aws_security_group" "distributed_instances" {
  count       = local.distributed_instance_count
  name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-instance-sg"
  description = "Security group for distributed VPC test instances"
  vpc_id      = aws_vpc.distributed[count.index].id

  ingress {
    description = "Allow SSH from management CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.management_cidr_sg
  }

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.management_cidr_sg
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.management_cidr_sg
  }

  ingress {
    description = "Allow ICMP from anywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.management_cidr_sg
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-instance-sg"
    Environment = var.env
  }
}

#
# Test EC2 Instances in Private Subnets
#
data "aws_ami" "distributed_ubuntu" {
  count       = local.distributed_instance_count > 0 ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "distributed_test_az1" {
  count                       = local.distributed_instance_count
  ami                         = data.aws_ami.distributed_ubuntu[0].id
  instance_type               = var.distributed_linux_instance_type
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.distributed_private_az1[count.index].id
  vpc_security_group_ids      = [aws_security_group.distributed_instances[count.index].id]
  private_ip                  = cidrhost(aws_subnet.distributed_private_az1[count.index].cidr_block, var.distributed_linux_host_ip)
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/config_templates/spoke-instance-userdata.tpl", {
    type              = "distributed-${count.index + 1}"
    region            = var.aws_region
    availability_zone = var.availability_zone_1
  })

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-instance-az1"
    Environment = var.env
  }
}

resource "aws_instance" "distributed_test_az2" {
  count                       = local.distributed_instance_count
  ami                         = data.aws_ami.distributed_ubuntu[0].id
  instance_type               = var.distributed_linux_instance_type
  key_name                    = var.keypair
  subnet_id                   = aws_subnet.distributed_private_az2[count.index].id
  vpc_security_group_ids      = [aws_security_group.distributed_instances[count.index].id]
  private_ip                  = cidrhost(aws_subnet.distributed_private_az2[count.index].cidr_block, var.distributed_linux_host_ip)
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/config_templates/spoke-instance-userdata.tpl", {
    type              = "distributed-${count.index + 1}"
    region            = var.aws_region
    availability_zone = var.availability_zone_2
  })

  tags = {
    Name        = "${var.cp}-${var.env}-distributed-${count.index + 1}-instance-az2"
    Environment = var.env
  }
}
