#====================================================================================================
# DATA SOURCES - DISCOVER EXISTING VPC RESOURCES
#====================================================================================================

# Locals for constructing resource names based on cp and env
locals {
  availability_zone_1       = "${var.aws_region}${var.availability_zone_1}"
  availability_zone_2       = "${var.aws_region}${var.availability_zone_2}"
  inspection_vpc            = "${var.cp}-${var.env}-inspection-vpc"
  management_vpc            = "${var.cp}-${var.env}-management-vpc"
  inspection_public_az1     = "${var.cp}-${var.env}-inspection-public-az1-subnet"
  inspection_public_az2     = "${var.cp}-${var.env}-inspection-public-az2-subnet"
  inspection_private_az1    = "${var.cp}-${var.env}-inspection-private-az1-subnet"
  inspection_private_az2    = "${var.cp}-${var.env}-inspection-private-az2-subnet"
  management_public_az1     = "${var.cp}-${var.env}-management-public-az1-subnet"
  management_public_az2     = "${var.cp}-${var.env}-management-public-az2-subnet"
  inspection_management_az1 = "${var.cp}-${var.env}-inspection-management-az1-subnet"
  inspection_management_az2 = "${var.cp}-${var.env}-inspection-management-az2-subnet"
  ha_sync_az1               = "${var.cp}-${var.env}-ha-sync-az1-subnet"
  ha_sync_az2               = "${var.cp}-${var.env}-ha-sync-az2-subnet"
}

# Discover Inspection VPC (required)
data "aws_vpc" "inspection_vpc" {
  filter {
    name   = "tag:Name"
    values = [local.inspection_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Management VPC (if dedicated management VPC is enabled)
data "aws_vpc" "management_vpc" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [local.management_vpc]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Inspection VPC Public Subnets (for port1 - untrusted)
data "aws_subnet" "inspection_public_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = [local.inspection_public_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnet" "inspection_public_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = [local.inspection_public_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Inspection VPC Private Subnets (for port2 - trusted)
data "aws_subnet" "inspection_private_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = [local.inspection_private_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnet" "inspection_private_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = [local.inspection_private_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Management VPC Subnets (for port4 if dedicated management VPC)
data "aws_subnet" "management_public_subnet_az1" {
  count = var.enable_dedicated_management_vpc ? 1 : 0
  filter {
    name   = "tag:Name"
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
    name   = "tag:Name"
    values = [local.management_public_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Inspection VPC Management Subnets (for port4 if dedicated management ENI in inspection VPC)
data "aws_subnet" "inspection_management_subnet_az1" {
  count = var.enable_dedicated_management_eni ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [local.inspection_management_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnet" "inspection_management_subnet_az2" {
  count = var.enable_dedicated_management_eni ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [local.inspection_management_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover HA Sync Subnets (created by existing_vpc_resources)
data "aws_subnet" "ha_sync_subnet_az1" {
  filter {
    name   = "tag:Name"
    values = [local.ha_sync_az1]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_subnet" "ha_sync_subnet_az2" {
  filter {
    name   = "tag:Name"
    values = [local.ha_sync_az2]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Internet Gateway for Inspection VPC
data "aws_internet_gateway" "inspection_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.inspection_vpc.id]
  }
}

# Discover Transit Gateway (if enabled)
data "aws_ec2_transit_gateway" "tgw" {
  count = var.enable_tgw_attachment ? 1 : 0
  filter {
    name   = "tag:Name"
    values = [var.attach_to_tgw_name]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover Transit Gateway Attachment (if exists)
data "aws_ec2_transit_gateway_vpc_attachment" "inspection_tgw_attachment" {
  count = var.enable_tgw_attachment ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-inspection-tgw-attachment"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Discover FortiManager instance (if enabled)
data "aws_instance" "fortimanager" {
  count = var.enable_fortimanager ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-fortimanager"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Discover FortiAnalyzer instance (if enabled)
data "aws_instance" "fortianalyzer" {
  count = var.enable_fortianalyzer ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-fortianalyzer"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Discover NAT Gateway (if using NAT GW mode for internet access)
data "aws_nat_gateway" "inspection_nat_gw_az1" {
  count = var.access_internet_mode == "nat_gw" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-inspection-nat-gw-az1"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_nat_gateway" "inspection_nat_gw_az2" {
  count = var.access_internet_mode == "nat_gw" ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-inspection-nat-gw-az2"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# Get AMI for FortiGate based on license type and version
data "aws_ami" "fortigate_ami" {
  most_recent = true
  owners      = ["679593333241"] # Fortinet AWS account

  filter {
    name   = "name"
    values = [
      var.license_type == "payg" ? "FortiGate-VM64-AWSONDEMAND*${var.fortios_version}*" :
      "FortiGate-VM64-AWS*${var.fortios_version}*"
    ]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
