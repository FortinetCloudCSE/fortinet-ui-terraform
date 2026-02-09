#====================================================================================================
# OUTPUTS
#====================================================================================================

# FortiGate Instance IDs
output "fortigate_primary_instance_id" {
  description = "EC2 instance ID of primary FortiGate"
  value       = aws_instance.fortigate_primary.id
}

output "fortigate_secondary_instance_id" {
  description = "EC2 instance ID of secondary FortiGate"
  value       = aws_instance.fortigate_secondary.id
}

# FortiGate Private IPs
output "fortigate_primary_port1_private_ip" {
  description = "Private IP of primary FortiGate port1 (untrusted)"
  value       = aws_network_interface.primary_port1.private_ip
}

output "fortigate_primary_port2_private_ip" {
  description = "Private IP of primary FortiGate port2 (trusted)"
  value       = aws_network_interface.primary_port2.private_ip
}

output "fortigate_secondary_port1_private_ip" {
  description = "Private IP of secondary FortiGate port1 (untrusted)"
  value       = aws_network_interface.secondary_port1.private_ip
}

output "fortigate_secondary_port2_private_ip" {
  description = "Private IP of secondary FortiGate port2 (trusted)"
  value       = aws_network_interface.secondary_port2.private_ip
}

# FortiGate Management Access
output "fortigate_primary_management_ip" {
  description = "Management IP for primary FortiGate (EIP if enabled, otherwise private IP)"
  value       = var.enable_management_eip ? aws_eip.primary_mgmt_eip[0].public_ip : aws_network_interface.primary_port3.private_ip
}

output "fortigate_secondary_management_ip" {
  description = "Management IP for secondary FortiGate (EIP if enabled, otherwise private IP)"
  value       = var.enable_management_eip ? aws_eip.secondary_mgmt_eip[0].public_ip : aws_network_interface.secondary_port3.private_ip
}

output "fortigate_cluster_eip" {
  description = "Cluster EIP for active FortiGate (moves on failover)"
  value       = var.access_internet_mode == "eip" ? aws_eip.cluster_eip[0].public_ip : "N/A - Using NAT Gateway mode"
}

# Management URLs
output "fortigate_primary_management_url" {
  description = "HTTPS URL for primary FortiGate management"
  value       = var.enable_management_eip ? "https://${aws_eip.primary_mgmt_eip[0].public_ip}" : "https://${aws_network_interface.primary_port3.private_ip}"
}

output "fortigate_secondary_management_url" {
  description = "HTTPS URL for secondary FortiGate management"
  value       = var.enable_management_eip ? "https://${aws_eip.secondary_mgmt_eip[0].public_ip}" : "https://${aws_network_interface.secondary_port3.private_ip}"
}

# Network Interface IDs (for route table configuration)
output "fortigate_primary_port1_eni_id" {
  description = "ENI ID of primary FortiGate port1 (for route table targets)"
  value       = aws_network_interface.primary_port1.id
}

output "fortigate_primary_port2_eni_id" {
  description = "ENI ID of primary FortiGate port2 (for route table targets)"
  value       = aws_network_interface.primary_port2.id
}

output "fortigate_secondary_port1_eni_id" {
  description = "ENI ID of secondary FortiGate port1 (for route table targets)"
  value       = aws_network_interface.secondary_port1.id
}

output "fortigate_secondary_port2_eni_id" {
  description = "ENI ID of secondary FortiGate port2 (for route table targets)"
  value       = aws_network_interface.secondary_port2.id
}

# HA Configuration Information
output "ha_group_name" {
  description = "HA cluster group name"
  value       = var.ha_group_name
}

output "ha_sync_subnet_az1_id" {
  description = "HA sync subnet ID in AZ1"
  value       = data.aws_subnet.ha_sync_subnet_az1.id
}

output "ha_sync_subnet_az2_id" {
  description = "HA sync subnet ID in AZ2"
  value       = data.aws_subnet.ha_sync_subnet_az2.id
}

# VPC Endpoint
output "vpc_endpoint_id" {
  description = "VPC endpoint ID for EC2 API"
  value       = aws_vpc_endpoint.ec2_api_endpoint.id
}

# Cluster EIP Allocation ID (for HA failover reference)
output "cluster_eip_allocation_id" {
  description = "Allocation ID of cluster EIP (used by FortiGate for failover)"
  value       = var.access_internet_mode == "eip" ? aws_eip.cluster_eip[0].id : "N/A"
}

# Configuration Summary
output "configuration_summary" {
  description = "Summary of HA pair configuration"
  value = {
    primary_instance_id     = aws_instance.fortigate_primary.id
    secondary_instance_id   = aws_instance.fortigate_secondary.id
    primary_az              = local.availability_zone_1
    secondary_az            = local.availability_zone_2
    internet_access_mode    = var.access_internet_mode
    license_type            = var.license_type
    dedicated_management    = var.enable_dedicated_management_vpc || var.enable_dedicated_management_eni
    management_eip_enabled  = var.enable_management_eip
    fortimanager_enabled    = var.enable_fortimanager
    fortianalyzer_enabled   = var.enable_fortianalyzer
  }
}
