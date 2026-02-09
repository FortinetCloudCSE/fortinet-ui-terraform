#====================================================================================================
# GCP Project Settings
#====================================================================================================

variable "gcp_project" {
  type        = string
  description = "GCP project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for resource deployment"
  default     = "us-central1"
}

variable "gcp_zone_1" {
  type        = string
  description = "Primary availability zone"
}

variable "gcp_zone_2" {
  type        = string
  description = "Secondary availability zone"
}

#====================================================================================================
# Naming Convention
#====================================================================================================

variable "cp" {
  type        = string
  description = "Customer prefix for resource naming"
  default     = "acme"
}

variable "env" {
  type        = string
  description = "Environment name (test, prod, dev)"
  default     = "test"
}

#====================================================================================================
# Inspection VPC Network
#====================================================================================================

variable "vpc_cidr_inspection" {
  type        = string
  description = "CIDR block for the inspection VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_bits" {
  type        = number
  description = "Number of additional bits for subnet calculation"
  default     = 8
}

variable "inspection_public_subnet_az1" {
  type        = string
  description = "CIDR for public (untrust) subnet in zone 1"
  default     = "10.0.1.0/24"
}

variable "inspection_public_subnet_az2" {
  type        = string
  description = "CIDR for public (untrust) subnet in zone 2"
  default     = "10.0.2.0/24"
}

variable "inspection_private_subnet_az1" {
  type        = string
  description = "CIDR for private (trust) subnet in zone 1"
  default     = "10.0.3.0/24"
}

variable "inspection_private_subnet_az2" {
  type        = string
  description = "CIDR for private (trust) subnet in zone 2"
  default     = "10.0.4.0/24"
}

variable "inspection_ilb_subnet_az1" {
  type        = string
  description = "CIDR for internal load balancer subnet in zone 1"
  default     = "10.0.5.0/24"
}

variable "inspection_ilb_subnet_az2" {
  type        = string
  description = "CIDR for internal load balancer subnet in zone 2"
  default     = "10.0.6.0/24"
}

variable "inspection_hasync_subnet_az1" {
  type        = string
  description = "CIDR for HA sync subnet in zone 1"
  default     = "10.0.7.0/24"
}

variable "inspection_hasync_subnet_az2" {
  type        = string
  description = "CIDR for HA sync subnet in zone 2"
  default     = "10.0.8.0/24"
}

#====================================================================================================
# Management VPC Network
#====================================================================================================

variable "enable_management_vpc" {
  type        = bool
  description = "Create a dedicated management VPC"
  default     = true
}

variable "vpc_cidr_management" {
  type        = string
  description = "CIDR block for the management VPC"
  default     = "10.10.0.0/16"
}

variable "management_subnet_az1" {
  type        = string
  description = "CIDR for management subnet in zone 1"
  default     = "10.10.1.0/24"
}

variable "management_subnet_az2" {
  type        = string
  description = "CIDR for management subnet in zone 2"
  default     = "10.10.2.0/24"
}

#====================================================================================================
# Spoke VPC Networks
#====================================================================================================

variable "enable_spoke_vpcs" {
  type        = bool
  description = "Create east and west spoke VPCs"
  default     = true
}

variable "vpc_cidr_east" {
  type        = string
  description = "CIDR block for the east spoke VPC"
  default     = "192.168.1.0/24"
}

variable "vpc_cidr_west" {
  type        = string
  description = "CIDR block for the west spoke VPC"
  default     = "192.168.2.0/24"
}

#====================================================================================================
# Instance Configuration
#====================================================================================================

variable "enable_instances" {
  type        = bool
  description = "Create jump box and spoke test instances (disable for network-only deployment)"
  default     = false
}

variable "ssh_username" {
  type        = string
  description = "Username for SSH key authentication"
  default     = "admin"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "management_cidr" {
  type        = string
  description = "IP/CIDR allowed for management access"
  default     = "0.0.0.0/0"
}

variable "jumpbox_machine_type" {
  type        = string
  description = "Machine type for jump box instance"
  default     = "e2-standard-4"
}

#====================================================================================================
# FortiManager / FortiAnalyzer
#====================================================================================================

variable "enable_fortimanager" {
  type        = bool
  description = "Deploy FortiManager in management VPC"
  default     = false
}

variable "fortimanager_machine_type" {
  type        = string
  description = "Machine type for FortiManager"
  default     = "e2-standard-4"
}

variable "enable_fortianalyzer" {
  type        = bool
  description = "Deploy FortiAnalyzer in management VPC"
  default     = false
}

variable "fortianalyzer_machine_type" {
  type        = string
  description = "Machine type for FortiAnalyzer"
  default     = "e2-standard-4"
}
