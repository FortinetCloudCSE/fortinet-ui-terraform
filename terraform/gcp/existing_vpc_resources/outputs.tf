#====================================================================================================
# OUTPUTS
#====================================================================================================

# Inspection VPC
output "inspection_vpc_name" {
  value       = google_compute_network.inspection.name
  description = "Inspection VPC network name"
}

output "inspection_vpc_self_link" {
  value       = google_compute_network.inspection.self_link
  description = "Inspection VPC network self link"
}

output "inspection_public_subnet_az1" {
  value       = google_compute_subnetwork.inspection_public_az1.name
  description = "Inspection public subnet AZ1 name"
}

output "inspection_public_subnet_az2" {
  value       = google_compute_subnetwork.inspection_public_az2.name
  description = "Inspection public subnet AZ2 name"
}

output "inspection_private_subnet_az1" {
  value       = google_compute_subnetwork.inspection_private_az1.name
  description = "Inspection private subnet AZ1 name"
}

output "inspection_private_subnet_az2" {
  value       = google_compute_subnetwork.inspection_private_az2.name
  description = "Inspection private subnet AZ2 name"
}

output "inspection_ilb_subnet_az1" {
  value       = google_compute_subnetwork.inspection_ilb_az1.name
  description = "Inspection ILB subnet AZ1 name"
}

output "inspection_ilb_subnet_az2" {
  value       = google_compute_subnetwork.inspection_ilb_az2.name
  description = "Inspection ILB subnet AZ2 name"
}

output "inspection_hasync_subnet_az1" {
  value       = google_compute_subnetwork.inspection_hasync_az1.name
  description = "Inspection HA sync subnet AZ1 name"
}

output "inspection_hasync_subnet_az2" {
  value       = google_compute_subnetwork.inspection_hasync_az2.name
  description = "Inspection HA sync subnet AZ2 name"
}

# Management VPC
output "management_vpc_name" {
  value       = var.enable_management_vpc ? google_compute_network.management[0].name : null
  description = "Management VPC network name"
}

output "management_vpc_self_link" {
  value       = var.enable_management_vpc ? google_compute_network.management[0].self_link : null
  description = "Management VPC network self link"
}

output "management_subnet_az1" {
  value       = var.enable_management_vpc ? google_compute_subnetwork.management_az1[0].name : null
  description = "Management subnet AZ1 name"
}

output "management_subnet_az2" {
  value       = var.enable_management_vpc ? google_compute_subnetwork.management_az2[0].name : null
  description = "Management subnet AZ2 name"
}

output "jump_box_public_ip" {
  value       = var.enable_management_vpc && var.enable_instances ? google_compute_instance.jump_box[0].network_interface[0].access_config[0].nat_ip : null
  description = "Jump box public IP address"
}

output "jump_box_private_ip" {
  value       = var.enable_management_vpc && var.enable_instances ? google_compute_instance.jump_box[0].network_interface[0].network_ip : null
  description = "Jump box private IP address"
}

# Spoke VPCs
output "east_vpc_name" {
  value       = var.enable_spoke_vpcs ? google_compute_network.east[0].name : null
  description = "East spoke VPC network name"
}

output "east_vpc_self_link" {
  value       = var.enable_spoke_vpcs ? google_compute_network.east[0].self_link : null
  description = "East spoke VPC network self link"
}

output "east_linux_public_ip" {
  value       = var.enable_spoke_vpcs && var.enable_instances ? google_compute_instance.east_linux[0].network_interface[0].access_config[0].nat_ip : null
  description = "East spoke Linux instance public IP"
}

output "east_linux_private_ip" {
  value       = var.enable_spoke_vpcs && var.enable_instances ? google_compute_instance.east_linux[0].network_interface[0].network_ip : null
  description = "East spoke Linux instance private IP"
}

output "west_vpc_name" {
  value       = var.enable_spoke_vpcs ? google_compute_network.west[0].name : null
  description = "West spoke VPC network name"
}

output "west_vpc_self_link" {
  value       = var.enable_spoke_vpcs ? google_compute_network.west[0].self_link : null
  description = "West spoke VPC network self link"
}

output "west_linux_public_ip" {
  value       = var.enable_spoke_vpcs && var.enable_instances ? google_compute_instance.west_linux[0].network_interface[0].access_config[0].nat_ip : null
  description = "West spoke Linux instance public IP"
}

output "west_linux_private_ip" {
  value       = var.enable_spoke_vpcs && var.enable_instances ? google_compute_instance.west_linux[0].network_interface[0].network_ip : null
  description = "West spoke Linux instance private IP"
}

# Summary
output "resource_prefix" {
  value       = "${var.cp}-${var.env}"
  description = "Resource naming prefix used across all resources"
}

output "gcp_project" {
  value       = var.gcp_project
  description = "GCP project ID"
}

output "gcp_region" {
  value       = var.gcp_region
  description = "GCP region"
}

output "zones" {
  value = {
    zone_1 = local.zone_1
    zone_2 = local.zone_2
  }
  description = "GCP zones used for deployment"
}
