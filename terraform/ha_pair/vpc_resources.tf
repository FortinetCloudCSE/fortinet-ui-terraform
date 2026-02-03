#====================================================================================================
# VPC INTERFACE ENDPOINT FOR EC2 API
#====================================================================================================
# This endpoint allows FortiGates to make AWS API calls privately for HA failover operations
# It is deployed into the HA sync subnets (created by existing_vpc_resources)

# Security group for VPC endpoint
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.cp}-${var.env}-vpc-endpoint-sg"
  description = "Security group for VPC interface endpoint (EC2 API)"
  vpc_id      = data.aws_vpc.inspection_vpc.id

  ingress {
    description = "HTTPS from HA sync subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_subnet.ha_sync_subnet_az1.cidr_block,
      data.aws_subnet.ha_sync_subnet_az2.cidr_block
    ]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-vpc-endpoint-sg"
    Environment = var.env
    Terraform   = "true"
  }
}

# VPC Interface Endpoint for EC2 API
resource "aws_vpc_endpoint" "ec2_api_endpoint" {
  vpc_id              = data.aws_vpc.inspection_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [
    data.aws_subnet.ha_sync_subnet_az1.id,
    data.aws_subnet.ha_sync_subnet_az2.id
  ]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.cp}-${var.env}-ec2-api-endpoint"
    Environment = var.env
    Terraform   = "true"
  }
}
