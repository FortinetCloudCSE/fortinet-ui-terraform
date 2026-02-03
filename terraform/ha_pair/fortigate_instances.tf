#====================================================================================================
# NETWORK INTERFACES - PRIMARY FORTIGATE
#====================================================================================================

# Primary FortiGate - Port1 (Untrusted/Public) in AZ1
resource "aws_network_interface" "primary_port1" {
  subnet_id         = data.aws_subnet.inspection_public_subnet_az1.id
  security_groups   = [aws_security_group.public_sg.id]
  source_dest_check = false

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary-port1"
    Environment = var.env
    Terraform   = "true"
  }
}

# Primary FortiGate - Port2 (Trusted/Private) in AZ1
resource "aws_network_interface" "primary_port2" {
  subnet_id         = data.aws_subnet.inspection_private_subnet_az1.id
  security_groups   = [aws_security_group.private_sg.id]
  source_dest_check = false

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary-port2"
    Environment = var.env
    Terraform   = "true"
  }
}

# Primary FortiGate - Port3 (HA Sync / Combined HA Sync+Mgmt) in AZ1
resource "aws_network_interface" "primary_port3" {
  subnet_id       = data.aws_subnet.ha_sync_subnet_az1.id
  security_groups = [aws_security_group.ha_sync_sg.id]

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary-port3"
    Environment = var.env
    Terraform   = "true"
  }
}

# Primary FortiGate - Port4 (Dedicated Management) - only if enabled
resource "aws_network_interface" "primary_port4" {
  count = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? 1 : 0

  subnet_id = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az1[0].id : data.aws_subnet.inspection_management_subnet_az1[0].id
  security_groups = [aws_security_group.management_sg[0].id]

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary-port4"
    Environment = var.env
    Terraform   = "true"
  }
}

#====================================================================================================
# NETWORK INTERFACES - SECONDARY FORTIGATE
#====================================================================================================

# Secondary FortiGate - Port1 (Untrusted/Public) in AZ2
resource "aws_network_interface" "secondary_port1" {
  subnet_id         = data.aws_subnet.inspection_public_subnet_az2.id
  security_groups   = [aws_security_group.public_sg.id]
  source_dest_check = false

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary-port1"
    Environment = var.env
    Terraform   = "true"
  }
}

# Secondary FortiGate - Port2 (Trusted/Private) in AZ2
resource "aws_network_interface" "secondary_port2" {
  subnet_id         = data.aws_subnet.inspection_private_subnet_az2.id
  security_groups   = [aws_security_group.private_sg.id]
  source_dest_check = false

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary-port2"
    Environment = var.env
    Terraform   = "true"
  }
}

# Secondary FortiGate - Port3 (HA Sync / Combined HA Sync+Mgmt) in AZ2
resource "aws_network_interface" "secondary_port3" {
  subnet_id       = data.aws_subnet.ha_sync_subnet_az2.id
  security_groups = [aws_security_group.ha_sync_sg.id]

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary-port3"
    Environment = var.env
    Terraform   = "true"
  }
}

# Secondary FortiGate - Port4 (Dedicated Management) - only if enabled
resource "aws_network_interface" "secondary_port4" {
  count = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? 1 : 0

  subnet_id = var.enable_dedicated_management_vpc ? data.aws_subnet.management_public_subnet_az2[0].id : data.aws_subnet.inspection_management_subnet_az2[0].id
  security_groups = [aws_security_group.management_sg[0].id]

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary-port4"
    Environment = var.env
    Terraform   = "true"
  }
}

#====================================================================================================
# FORTIGATE EC2 INSTANCES
#====================================================================================================

# Primary FortiGate Instance (Master)
resource "aws_instance" "fortigate_primary" {
  ami                  = data.aws_ami.fortigate_ami.id
  instance_type        = var.fortigate_instance_type
  availability_zone    = local.availability_zone_1
  key_name             = var.keypair
  iam_instance_profile = aws_iam_instance_profile.fortigate_ha_profile.name
  user_data            = data.template_file.primary_userdata.rendered

  root_block_device {
    volume_type = "gp3"
    volume_size = 2
  }

  # Attach network interfaces in order
  network_interface {
    network_interface_id = aws_network_interface.primary_port1.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.primary_port2.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.primary_port3.id
    device_index         = 2
  }

  dynamic "network_interface" {
    for_each = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? [1] : []
    content {
      network_interface_id = aws_network_interface.primary_port4[0].id
      device_index         = 3
    }
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary"
    Environment = var.env
    Terraform   = "true"
  }
}

# Secondary FortiGate Instance (Slave)
resource "aws_instance" "fortigate_secondary" {
  ami                  = data.aws_ami.fortigate_ami.id
  instance_type        = var.fortigate_instance_type
  availability_zone    = local.availability_zone_2
  key_name             = var.keypair
  iam_instance_profile = aws_iam_instance_profile.fortigate_ha_profile.name
  user_data            = data.template_file.secondary_userdata.rendered

  root_block_device {
    volume_type = "gp3"
    volume_size = 2
  }

  # Attach network interfaces in order
  network_interface {
    network_interface_id = aws_network_interface.secondary_port1.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.secondary_port2.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.secondary_port3.id
    device_index         = 2
  }

  dynamic "network_interface" {
    for_each = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? [1] : []
    content {
      network_interface_id = aws_network_interface.secondary_port4[0].id
      device_index         = 3
    }
  }

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary"
    Environment = var.env
    Terraform   = "true"
  }
}
