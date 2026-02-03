#====================================================================================================
# ELASTIC IPS
#====================================================================================================

# Cluster EIP for primary FortiGate port1 (moves on failover)
resource "aws_eip" "cluster_eip" {
  count  = var.access_internet_mode == "eip" ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-cluster-eip"
    Environment = var.env
    Terraform   = "true"
  }
}

# Management EIP for primary FortiGate (if enabled)
resource "aws_eip" "primary_mgmt_eip" {
  count  = var.enable_management_eip ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-primary-mgmt-eip"
    Environment = var.env
    Terraform   = "true"
  }
}

# Management EIP for secondary FortiGate (if enabled)
resource "aws_eip" "secondary_mgmt_eip" {
  count  = var.enable_management_eip ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.cp}-${var.env}-fortigate-secondary-mgmt-eip"
    Environment = var.env
    Terraform   = "true"
  }
}

#====================================================================================================
# EIP ASSOCIATIONS
#====================================================================================================

# Associate cluster EIP with primary FortiGate port1 (initial association)
resource "aws_eip_association" "cluster_eip_assoc" {
  count                = var.access_internet_mode == "eip" ? 1 : 0
  allocation_id        = aws_eip.cluster_eip[0].id
  network_interface_id = aws_network_interface.primary_port1.id
}

# Associate management EIP with primary FortiGate HA sync/mgmt interface
resource "aws_eip_association" "primary_mgmt_eip_assoc" {
  count                = var.enable_management_eip ? 1 : 0
  allocation_id        = aws_eip.primary_mgmt_eip[0].id
  network_interface_id = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? aws_network_interface.primary_port4[0].id : aws_network_interface.primary_port3.id
}

# Associate management EIP with secondary FortiGate HA sync/mgmt interface
resource "aws_eip_association" "secondary_mgmt_eip_assoc" {
  count                = var.enable_management_eip ? 1 : 0
  allocation_id        = aws_eip.secondary_mgmt_eip[0].id
  network_interface_id = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? aws_network_interface.secondary_port4[0].id : aws_network_interface.secondary_port3.id
}
