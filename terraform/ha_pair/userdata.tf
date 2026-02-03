#====================================================================================================
# USER DATA TEMPLATES FOR FORTIGATE INSTANCES
#====================================================================================================

# Locals for determining management interface gateway
locals {
  # Management interface is port3 if no dedicated management, otherwise port4
  mgmt_interface = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? "port4" : "port3"

  # Gateway for HA management interface (first IP in subnet)
  primary_mgmt_gateway   = cidrhost(data.aws_subnet.ha_sync_subnet_az1.cidr_block, 1)
  secondary_mgmt_gateway = cidrhost(data.aws_subnet.ha_sync_subnet_az2.cidr_block, 1)

  # Peer IPs for unicast HA heartbeat
  primary_port3_ip   = aws_network_interface.primary_port3.private_ip
  secondary_port3_ip = aws_network_interface.secondary_port3.private_ip
}

# Primary FortiGate User Data
data "template_file" "primary_userdata" {
  template = file("${path.module}/config_templates/primary-fortigate-userdata.tpl")

  vars = {
    # Basic settings
    fgt_id             = "${var.cp}-${var.env}-fortigate-primary"
    fgt_admin_password = var.fortigate_admin_password

    # HA Configuration
    ha_group_name   = var.ha_group_name
    ha_password     = var.ha_password
    ha_priority     = "255"  # Primary has higher priority
    ha_mgmt_if      = local.mgmt_interface
    ha_mgmt_gateway = local.primary_mgmt_gateway
    ha_peer_ip      = local.secondary_port3_ip

    # Port1 (Untrusted) Configuration
    port1_ip      = aws_network_interface.primary_port1.private_ip
    port1_mask    = cidrnetmask(data.aws_subnet.inspection_public_subnet_az1.cidr_block)
    port1_gateway = cidrhost(data.aws_subnet.inspection_public_subnet_az1.cidr_block, 1)

    # Port2 (Trusted) Configuration
    port2_ip      = aws_network_interface.primary_port2.private_ip
    port2_mask    = cidrnetmask(data.aws_subnet.inspection_private_subnet_az1.cidr_block)
    port2_gateway = cidrhost(data.aws_subnet.inspection_private_subnet_az1.cidr_block, 1)

    # Port3 (HA Sync) Configuration
    port3_ip   = local.primary_port3_ip
    port3_mask = cidrnetmask(data.aws_subnet.ha_sync_subnet_az1.cidr_block)

    # Port4 (Dedicated Management) Configuration - if enabled
    port4_ip      = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? aws_network_interface.primary_port4[0].private_ip : ""
    port4_mask    = var.enable_dedicated_management_vpc ? cidrnetmask(data.aws_subnet.management_public_subnet_az1[0].cidr_block) : (var.enable_dedicated_management_eni ? cidrnetmask(data.aws_subnet.inspection_management_subnet_az1[0].cidr_block) : "")
    port4_gateway = var.enable_dedicated_management_vpc ? cidrhost(data.aws_subnet.management_public_subnet_az1[0].cidr_block, 1) : (var.enable_dedicated_management_eni ? cidrhost(data.aws_subnet.inspection_management_subnet_az1[0].cidr_block, 1) : "")

    # Management Settings
    enable_dedicated_mgmt = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni

    # FortiManager/FortiAnalyzer
    enable_fortimanager = var.enable_fortimanager
    fortimanager_ip     = var.fortimanager_ip
    enable_fortianalyzer = var.enable_fortianalyzer
    fortianalyzer_ip     = var.fortianalyzer_ip

    # Licensing
    license_type    = var.license_type
    license_file    = var.fgt_primary_license_file
    fortiflex_token = var.fortiflex_token

    # AWS Region
    aws_region = var.aws_region
  }
}

# Secondary FortiGate User Data
data "template_file" "secondary_userdata" {
  template = file("${path.module}/config_templates/secondary-fortigate-userdata.tpl")

  vars = {
    # Basic settings
    fgt_id             = "${var.cp}-${var.env}-fortigate-secondary"
    fgt_admin_password = var.fortigate_admin_password

    # HA Configuration
    ha_group_name   = var.ha_group_name
    ha_password     = var.ha_password
    ha_priority     = "1"  # Secondary has lower priority
    ha_mgmt_if      = local.mgmt_interface
    ha_mgmt_gateway = local.secondary_mgmt_gateway
    ha_peer_ip      = local.primary_port3_ip

    # Port1 (Untrusted) Configuration
    port1_ip      = aws_network_interface.secondary_port1.private_ip
    port1_mask    = cidrnetmask(data.aws_subnet.inspection_public_subnet_az2.cidr_block)
    port1_gateway = cidrhost(data.aws_subnet.inspection_public_subnet_az2.cidr_block, 1)

    # Port2 (Trusted) Configuration
    port2_ip      = aws_network_interface.secondary_port2.private_ip
    port2_mask    = cidrnetmask(data.aws_subnet.inspection_private_subnet_az2.cidr_block)
    port2_gateway = cidrhost(data.aws_subnet.inspection_private_subnet_az2.cidr_block, 1)

    # Port3 (HA Sync) Configuration
    port3_ip   = local.secondary_port3_ip
    port3_mask = cidrnetmask(data.aws_subnet.ha_sync_subnet_az2.cidr_block)

    # Port4 (Dedicated Management) Configuration - if enabled
    port4_ip      = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni ? aws_network_interface.secondary_port4[0].private_ip : ""
    port4_mask    = var.enable_dedicated_management_vpc ? cidrnetmask(data.aws_subnet.management_public_subnet_az2[0].cidr_block) : (var.enable_dedicated_management_eni ? cidrnetmask(data.aws_subnet.inspection_management_subnet_az2[0].cidr_block) : "")
    port4_gateway = var.enable_dedicated_management_vpc ? cidrhost(data.aws_subnet.management_public_subnet_az2[0].cidr_block, 1) : (var.enable_dedicated_management_eni ? cidrhost(data.aws_subnet.inspection_management_subnet_az2[0].cidr_block, 1) : "")

    # Management Settings
    enable_dedicated_mgmt = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni

    # FortiManager/FortiAnalyzer
    enable_fortimanager = var.enable_fortimanager
    fortimanager_ip     = var.fortimanager_ip
    enable_fortianalyzer = var.enable_fortianalyzer
    fortianalyzer_ip     = var.fortianalyzer_ip

    # Licensing
    license_type    = var.license_type
    license_file    = var.fgt_secondary_license_file
    fortiflex_token = var.fortiflex_token

    # AWS Region
    aws_region = var.aws_region
  }
}
