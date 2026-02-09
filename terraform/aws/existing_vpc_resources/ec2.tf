locals {
  linux_east_az1_ip_address = cidrhost(local.east_public_subnet_cidr_az1, var.linux_host_ip)
}
locals {
  linux_east_az2_ip_address = cidrhost(local.east_public_subnet_cidr_az2, var.linux_host_ip)
}

locals {
  linux_west_az1_ip_address = cidrhost(local.west_public_subnet_cidr_az1, var.linux_host_ip)
}
locals {
  linux_west_az2_ip_address = cidrhost(local.west_public_subnet_cidr_az2, var.linux_host_ip)
}

data "aws_subnet" "subnet-east-public-az1" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.subnet-east-public-az1 ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-east-public-az1-subnet"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "subnet-east-public-az2" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.subnet-east-public-az2 ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-east-public-az2-subnet"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "subnet-west-public-az1" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.subnet-west-public-az1 ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-west-public-az1-subnet"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
data "aws_subnet" "subnet-west-public-az2" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.subnet-west-public-az2 ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-west-public-az2-subnet"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "vpc-east" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.vpc-east ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-east-vpc"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "vpc-west" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on = [ module.vpc-west ]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-west-vpc"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

#
# Optional Linux Instances from here down
#
# Linux Instance that are added on to the East and West VPCs for testing EAST->West Traffic
#
# Endpoint AMI to use for Linux Instances. Just added this on the end, since traffic generating linux instances
# would not make it to a production template.
#
locals {
  web_userdata_az1 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? templatefile("${path.module}/config_templates/spoke-instance-userdata.tpl", {
    region            = var.aws_region
    availability_zone = var.availability_zone_1
  }) : ""
  web_userdata_az2 = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? templatefile("${path.module}/config_templates/spoke-instance-userdata.tpl", {
    region            = var.aws_region
    availability_zone = var.availability_zone_2
  }) : ""
}

data "aws_ami" "ubuntu" {
  count = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-20250603*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

#
# EC2 Endpoint Resources
#

resource "time_sleep" "wait_for_spoke_networking" {
  count           = var.enable_jump_box ? 1 : 0
  depends_on      = [module.vpc-transit-gateway-attachment-east, module.vpc-transit-gateway-attachment-west]
  create_duration = "300s"  # 5 minutes
}

#
# East Linux Instance for Generating East->West Traffic
#

module "east_instance_public_az1" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on                  = [module.vpc-east, module.vpc-transit-gateway-attachment-east, time_sleep.wait_for_spoke_networking]
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-east-public-az1-instance"
  enable_public_ips           = false
  availability_zone           = local.availability_zone_1
  public_subnet_id            = data.aws_subnet.subnet-east-public-az1[0].id
  public_ip_address           = local.linux_east_az1_ip_address
  aws_ami                     = data.aws_ami.ubuntu[0].id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = aws_security_group.ec2-linux-east-vpc-sg[0].id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile[0].id
  userdata_rendered           = local.web_userdata_az1
}

module "east_instance_public_az2" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on                  = [module.vpc-east, module.vpc-transit-gateway-attachment-east, time_sleep.wait_for_spoke_networking]
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-east-public-az2-instance"
  enable_public_ips           = false
  availability_zone           = local.availability_zone_2
  public_subnet_id            = data.aws_subnet.subnet-east-public-az2[0].id
  public_ip_address           = local.linux_east_az2_ip_address
  aws_ami                     = data.aws_ami.ubuntu[0].id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = aws_security_group.ec2-linux-east-vpc-sg[0].id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile[0].id
  userdata_rendered           = local.web_userdata_az2
}

#
# West Linux Instance for Generating West->East Traffic
#
module "west_instance_public_az1" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on                  = [module.vpc-west, module.vpc-transit-gateway-attachment-west, time_sleep.wait_for_spoke_networking]
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-west-public-az1-instance"
  enable_public_ips           = false
  availability_zone           = local.availability_zone_1
  public_subnet_id            = data.aws_subnet.subnet-west-public-az1[0].id
  public_ip_address           = local.linux_west_az1_ip_address
  aws_ami                     = data.aws_ami.ubuntu[0].id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = aws_security_group.ec2-linux-west-vpc-sg[0].id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile[0].id
  userdata_rendered           = local.web_userdata_az1
}

module "west_instance_public_az2" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  depends_on                  = [module.vpc-west, module.vpc-transit-gateway-attachment-west, time_sleep.wait_for_spoke_networking]
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-west-public-az2-instance"
  enable_public_ips           = false
  availability_zone           = local.availability_zone_2
  public_subnet_id            = data.aws_subnet.subnet-west-public-az2[0].id
  public_ip_address           = local.linux_west_az2_ip_address
  aws_ami                     = data.aws_ami.ubuntu[0].id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = aws_security_group.ec2-linux-west-vpc-sg[0].id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile[0].id
  userdata_rendered           = local.web_userdata_az2
}

#
# Security Groups are VPC specific, so an "ALLOW ALL" for each VPC
#
resource "aws_security_group" "ec2-linux-east-vpc-sg" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  description                 = "Security Group for Linux Instances in the East Spoke VPC"
  vpc_id                      = data.aws_vpc.vpc-east[0].id
  ingress {
    description = "Allow SSH from Management and Inspection VPCs"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow HTTP from Management and Inspection VPCs"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow FTP from Management and Inspection VPCs"
    from_port = 21
    to_port = 21
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow FTP PASV ports from Management and Inspection VPCs"
    from_port = 10090
    to_port = 10100
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow ICMP from Management and Inspection VPCs"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow Syslog from anywhere IPv4"
    from_port = 514
    to_port = 514
    protocol = "udp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "Allow All East West Traffic. Let the firewall control it"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ var.vpc_cidr_west ]
  }
  egress {
    description = "Allow egress ALL"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
resource "aws_security_group" "ec2-linux-west-vpc-sg" {
  count                       = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  description                 = "Security Group for Linux Instances in the West Spoke VPC"
  vpc_id                      = data.aws_vpc.vpc-west[0].id
  ingress {
    description = "Allow SSH from Management and Inspection VPCs"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow HTTP from Management and Inspection VPCs"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection  ]
  }
  ingress {
    description = "Allow FTP from Management and Inspection VPCs"
    from_port = 21
    to_port = 21
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow FTP PASV ports from Management and Inspection VPCs"
    from_port = 10090
    to_port = 10100
    protocol = "tcp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow ICMP from Management and Inspection VPCs"
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [ var.vpc_cidr_management, var.vpc_cidr_ns_inspection ]
  }
  ingress {
    description = "Allow Syslog from anywhere IPv4"
    from_port = 514
    to_port = 514
    protocol = "udp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "Allow All East West Traffic. Let the firewall control it"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ var.vpc_cidr_east ]
  }
  egress {
    description = "Allow egress ALL"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

#
# IAM Profile for linux instance
#
module "linux_iam_profile" {
  source        = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance_iam_role"
  count         = (var.enable_build_existing_subnets && var.enable_linux_spoke_instances) ? 1 : 0
  iam_role_name = "${var.cp}-${var.env}-${random_string.random.result}-linux-instance_role"
}

#====================================================================================================
# FORTITESTER INSTANCES
#====================================================================================================
# FortiTester deployment for East-West traffic testing:
#   - FortiTester 1 (AZ1): Port1 (mgmt) in Management VPC AZ1, Port2 in East AZ1, Port3 in West AZ1
#   - FortiTester 2 (AZ2): Port1 (mgmt) in Management VPC AZ2, Port2 in West AZ2, Port3 in East AZ2
# Management interface has public IP for direct access.

locals {
  # Management VPC subnet CIDRs for FortiTester
  mgmt_public_subnet_cidr_az1 = cidrsubnet(var.vpc_cidr_management, var.subnet_bits, 0)
  mgmt_public_subnet_cidr_az2 = cidrsubnet(var.vpc_cidr_management, var.subnet_bits, 1)

  # FortiTester 1 (AZ1): Mgmt VPC -> East -> West
  fortitester_1_port1_ip = cidrhost(local.mgmt_public_subnet_cidr_az1, var.fortitester_host_ip)
  fortitester_1_port2_ip = cidrhost(local.east_public_subnet_cidr_az1, var.fortitester_host_ip)
  fortitester_1_port3_ip = cidrhost(local.west_public_subnet_cidr_az1, var.fortitester_host_ip)

  # FortiTester 2 (AZ2): Mgmt VPC -> West -> East
  fortitester_2_port1_ip = cidrhost(local.mgmt_public_subnet_cidr_az2, var.fortitester_host_ip)
  fortitester_2_port2_ip = cidrhost(local.west_public_subnet_cidr_az2, var.fortitester_host_ip)
  fortitester_2_port3_ip = cidrhost(local.east_public_subnet_cidr_az2, var.fortitester_host_ip)

  # Determine if any FortiTester is enabled
  any_fortitester_enabled = var.enable_fortitester_1 || var.enable_fortitester_2
}

#
# FortiTester Security Groups
#

# Management VPC security group for FortiTester port1 (management interface)
# Uses the same CIDRs as the jump box/FortiManager/FortiAnalyzer security groups
resource "aws_security_group" "fortitester-mgmt-sg" {
  count       = (var.enable_build_management_vpc && local.any_fortitester_enabled) ? 1 : 0
  name        = "${var.cp}-${var.env}-fortitester-mgmt-sg"
  description = "Security Group for FortiTester management interface in Management VPC"
  vpc_id      = module.vpc-management[0].vpc_id

  ingress {
    description = "Allow HTTPS from management CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.management_cidr_sg
  }
  ingress {
    description = "Allow SSH from management CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.management_cidr_sg
  }
  ingress {
    description = "Allow ICMP from management CIDRs"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.management_cidr_sg
  }
  ingress {
    description = "Allow all from East VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_east]
  }
  ingress {
    description = "Allow all from West VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr_west]
  }
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-mgmt-sg"
  }
}

# East VPC security group for FortiTester traffic interfaces - allow all traffic
resource "aws_security_group" "fortitester-east-sg" {
  count       = (var.enable_build_existing_subnets && local.any_fortitester_enabled) ? 1 : 0
  name        = "${var.cp}-${var.env}-fortitester-east-sg"
  description = "Security Group for FortiTester traffic interfaces in East VPC - all traffic"
  vpc_id      = data.aws_vpc.vpc-east[0].id

  ingress {
    description = "Allow all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-east-sg"
  }
}

# West VPC security group for FortiTester traffic interfaces - allow all traffic
resource "aws_security_group" "fortitester-west-sg" {
  count       = (var.enable_build_existing_subnets && local.any_fortitester_enabled) ? 1 : 0
  name        = "${var.cp}-${var.env}-fortitester-west-sg"
  description = "Security Group for FortiTester traffic interfaces in West VPC - all traffic"
  vpc_id      = data.aws_vpc.vpc-west[0].id

  ingress {
    description = "Allow all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-west-sg"
  }
}

# Data source for management VPC subnets
data "aws_subnet" "mgmt-public-az1" {
  count      = (var.enable_build_management_vpc && local.any_fortitester_enabled) ? 1 : 0
  depends_on = [module.vpc-management]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-management-public-az1-subnet"]
  }
}

data "aws_subnet" "mgmt-public-az2" {
  count      = (var.enable_build_management_vpc && local.any_fortitester_enabled) ? 1 : 0
  depends_on = [module.vpc-management]
  filter {
    name   = "tag:Name"
    values = ["${var.cp}-${var.env}-management-public-az2-subnet"]
  }
}

#
# FortiTester 1: Port1 (mgmt) in Mgmt VPC AZ1, Port2 in East AZ1, Port3 in West AZ1
#
resource "aws_network_interface" "fortitester_1_port1" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  subnet_id         = data.aws_subnet.mgmt-public-az1[0].id
  security_groups   = [aws_security_group.fortitester-mgmt-sg[0].id]
  private_ips       = [local.fortitester_1_port1_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-1-port1-mgmt-az1"
  }
}

resource "aws_network_interface" "fortitester_1_port2" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  subnet_id         = data.aws_subnet.subnet-east-public-az1[0].id
  security_groups   = [aws_security_group.fortitester-east-sg[0].id]
  private_ips       = [local.fortitester_1_port2_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-1-port2-east-az1"
  }
}

resource "aws_network_interface" "fortitester_1_port3" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  subnet_id         = data.aws_subnet.subnet-west-public-az1[0].id
  security_groups   = [aws_security_group.fortitester-west-sg[0].id]
  private_ips       = [local.fortitester_1_port3_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-1-port3-west-az1"
  }
}

# Elastic IP for FortiTester 1 management interface
resource "aws_eip" "fortitester_1_eip" {
  count  = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-1-eip"
  }
}

resource "aws_eip_association" "fortitester_1_eip" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  network_interface_id = aws_network_interface.fortitester_1_port1[0].id
  allocation_id        = aws_eip.fortitester_1_eip[0].id
}

resource "aws_instance" "fortitester_1" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  depends_on        = [module.vpc-management, module.vpc-east, module.vpc-west, module.vpc-transit-gateway-attachment-east, module.vpc-transit-gateway-attachment-west, time_sleep.wait_for_spoke_networking]
  ami               = "ami-0f9225f6aa0df1860"
  instance_type     = var.fortitester_instance_type
  availability_zone = local.availability_zone_1
  key_name          = var.keypair

  network_interface {
    network_interface_id = aws_network_interface.fortitester_1_port1[0].id
    device_index         = 0
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-1"
  }
}

# Attach port2 and port3 after instance creation
resource "aws_network_interface_attachment" "fortitester_1_port2" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  instance_id          = aws_instance.fortitester_1[0].id
  network_interface_id = aws_network_interface.fortitester_1_port2[0].id
  device_index         = 1
}

resource "aws_network_interface_attachment" "fortitester_1_port3" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_1) ? 1 : 0
  instance_id          = aws_instance.fortitester_1[0].id
  network_interface_id = aws_network_interface.fortitester_1_port3[0].id
  device_index         = 2
}

#
# FortiTester 2: Port1 (mgmt) in Mgmt VPC AZ2, Port2 in West AZ2, Port3 in East AZ2
#
resource "aws_network_interface" "fortitester_2_port1" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  subnet_id         = data.aws_subnet.mgmt-public-az2[0].id
  security_groups   = [aws_security_group.fortitester-mgmt-sg[0].id]
  private_ips       = [local.fortitester_2_port1_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-2-port1-mgmt-az2"
  }
}

resource "aws_network_interface" "fortitester_2_port2" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  subnet_id         = data.aws_subnet.subnet-west-public-az2[0].id
  security_groups   = [aws_security_group.fortitester-west-sg[0].id]
  private_ips       = [local.fortitester_2_port2_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-2-port2-west-az2"
  }
}

resource "aws_network_interface" "fortitester_2_port3" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  subnet_id         = data.aws_subnet.subnet-east-public-az2[0].id
  security_groups   = [aws_security_group.fortitester-east-sg[0].id]
  private_ips       = [local.fortitester_2_port3_ip]
  source_dest_check = false

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-2-port3-east-az2"
  }
}

# Elastic IP for FortiTester 2 management interface
resource "aws_eip" "fortitester_2_eip" {
  count  = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-2-eip"
  }
}

resource "aws_eip_association" "fortitester_2_eip" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  network_interface_id = aws_network_interface.fortitester_2_port1[0].id
  allocation_id        = aws_eip.fortitester_2_eip[0].id
}

resource "aws_instance" "fortitester_2" {
  count             = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  depends_on        = [module.vpc-management, module.vpc-east, module.vpc-west, module.vpc-transit-gateway-attachment-east, module.vpc-transit-gateway-attachment-west, time_sleep.wait_for_spoke_networking]
  ami               = "ami-0f9225f6aa0df1860"
  instance_type     = var.fortitester_instance_type
  availability_zone = local.availability_zone_2
  key_name          = var.keypair

  network_interface {
    network_interface_id = aws_network_interface.fortitester_2_port1[0].id
    device_index         = 0
  }

  tags = {
    Name = "${var.cp}-${var.env}-fortitester-2"
  }
}

# Attach port2 and port3 after instance creation
resource "aws_network_interface_attachment" "fortitester_2_port2" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  instance_id          = aws_instance.fortitester_2[0].id
  network_interface_id = aws_network_interface.fortitester_2_port2[0].id
  device_index         = 1
}

resource "aws_network_interface_attachment" "fortitester_2_port3" {
  count                = (var.enable_build_management_vpc && var.enable_build_existing_subnets && var.enable_fortitester_2) ? 1 : 0
  instance_id          = aws_instance.fortitester_2[0].id
  network_interface_id = aws_network_interface.fortitester_2_port3[0].id
  device_index         = 2
}
