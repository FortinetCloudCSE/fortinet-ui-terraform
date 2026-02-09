#====================================================================================================
# SECURITY GROUPS
#====================================================================================================

# Security Group for Public/Untrusted Interfaces (port1)
resource "aws_security_group" "public_sg" {
  name        = "${var.cp}-${var.env}-fortigate-public-sg"
  description = "Security group for FortiGate public/untrusted interfaces"
  vpc_id      = data.aws_vpc.inspection_vpc.id

  # Allow all inbound traffic (FortiGate will filter)
  ingress {
    description = "Allow all inbound traffic to FortiGate"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-public-sg"
    Environment = var.env
    Terraform   = "true"
  }
}

# Security Group for Private/Trusted Interfaces (port2)
resource "aws_security_group" "private_sg" {
  name        = "${var.cp}-${var.env}-fortigate-private-sg"
  description = "Security group for FortiGate private/trusted interfaces"
  vpc_id      = data.aws_vpc.inspection_vpc.id

  # Allow all inbound traffic from inspection VPC
  ingress {
    description = "Allow all traffic from inspection VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.inspection_vpc.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-private-sg"
    Environment = var.env
    Terraform   = "true"
  }
}

# Security Group for HA Sync Interface (port3)
resource "aws_security_group" "ha_sync_sg" {
  name        = "${var.cp}-${var.env}-fortigate-ha-sync-sg"
  description = "Security group for FortiGate HA sync interfaces"
  vpc_id      = data.aws_vpc.inspection_vpc.id

  # Allow HTTPS for AWS API access
  ingress {
    description = "HTTPS for AWS API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic between HA sync subnets for heartbeat/sync
  ingress {
    description = "Allow HA heartbeat and sync traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      data.aws_subnet.ha_sync_subnet_az1.cidr_block,
      data.aws_subnet.ha_sync_subnet_az2.cidr_block
    ]
  }

  # Allow management access if not using dedicated management interface
  dynamic "ingress" {
    for_each = (!var.enable_dedicated_management_vpc && !var.enable_dedicated_management_eni) ? [1] : []
    content {
      description = "HTTPS management access"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  dynamic "ingress" {
    for_each = (!var.enable_dedicated_management_vpc && !var.enable_dedicated_management_eni) ? [1] : []
    content {
      description = "SSH management access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.fortigate_management_cidr
    }
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-ha-sync-sg"
    Environment = var.env
    Terraform   = "true"
  }
}

# Security Group for Dedicated Management Interface (port4) - if enabled
resource "aws_security_group" "management_sg" {
  count       = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? 1 : 0
  name        = "${var.cp}-${var.env}-fortigate-management-sg"
  description = "Security group for FortiGate dedicated management interfaces"
  vpc_id      = var.enable_dedicated_management_vpc ? data.aws_vpc.management_vpc[0].id : data.aws_vpc.inspection_vpc.id

  # HTTPS access
  ingress {
    description = "HTTPS management access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.fortigate_management_cidr
  }

  # HTTP access
  ingress {
    description = "HTTP management access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.fortigate_management_cidr
  }

  # SSH access
  ingress {
    description = "SSH management access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.fortigate_management_cidr
  }

  # FortiManager/FortiAnalyzer communication
  ingress {
    description = "FortiManager/FortiAnalyzer communication"
    from_port   = 541
    to_port     = 541
    protocol    = "tcp"
    cidr_blocks = var.enable_dedicated_management_vpc ? [data.aws_vpc.management_vpc[0].cidr_block] : [data.aws_vpc.inspection_vpc.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-management-sg"
    Environment = var.env
    Terraform   = "true"
  }
}
