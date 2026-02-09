#====================================================================================================
# REGION AND AVAILABILITY ZONES
#====================================================================================================
variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-west-1"
}

variable "availability_zone_1" {
  description = "First availability zone (letter only, appended to region)"
  type        = string
  default     = "a"
}

variable "availability_zone_2" {
  description = "Second availability zone (letter only, appended to region)"
  type        = string
  default     = "b"
}

#====================================================================================================
# RESOURCE IDENTIFICATION
#====================================================================================================
variable "cp" {
  description = "Customer prefix for resource naming"
  type        = string
  default     = "acme"
}

variable "env" {
  description = "Environment name for resource naming"
  type        = string
  default     = "test"
}

#====================================================================================================
# SECURITY VARIABLES
#====================================================================================================
variable "keypair" {
  description = "EC2 keypair name for SSH access"
  type        = string
}

variable "fortigate_admin_password" {
  description = "Password for FortiGate admin user"
  type        = string
  sensitive   = true
}

#====================================================================================================
# FORTIGATE HA CONFIGURATION
#====================================================================================================
variable "ha_group_name" {
  description = "FGCP HA cluster group name"
  type        = string
  default     = "ha-cluster"
}

variable "ha_password" {
  description = "Password for HA heartbeat communication"
  type        = string
  sensitive   = true
}

variable "fortigate_instance_type" {
  description = "EC2 instance type for FortiGate instances"
  type        = string
  default     = "c5n.xlarge"
}

variable "fortios_version" {
  description = "FortiOS version to deploy"
  type        = string
  default     = "7.4.5"
}

#====================================================================================================
# LICENSING CONFIGURATION
#====================================================================================================
variable "license_type" {
  description = "FortiGate licensing model (payg, byol, fortiflex)"
  type        = string
  default     = "payg"
  validation {
    condition     = contains(["payg", "byol", "fortiflex"], var.license_type)
    error_message = "License type must be 'payg', 'byol', or 'fortiflex'."
  }
}

variable "fgt_primary_license_file" {
  description = "Path to license file for primary FortiGate"
  type        = string
  default     = ""
}

variable "fgt_secondary_license_file" {
  description = "Path to license file for secondary FortiGate"
  type        = string
  default     = ""
}

variable "fortiflex_token" {
  description = "FortiFlex token for VM licensing"
  type        = string
  default     = ""
  sensitive   = true
}

#====================================================================================================
# MANAGEMENT CONFIGURATION
#====================================================================================================
variable "enable_dedicated_management_vpc" {
  description = "Use dedicated management VPC for FortiGate management interfaces"
  type        = bool
  default     = false
}

variable "enable_dedicated_management_eni" {
  description = "Use dedicated management subnets within inspection VPC"
  type        = bool
  default     = false
}

variable "enable_management_eip" {
  description = "Associate Elastic IPs with management interfaces"
  type        = bool
  default     = true
}

variable "fortigate_management_cidr" {
  description = "CIDR blocks allowed to access FortiGate management interfaces"
  type        = any  # Accepts string or list(string)
  default     = []
}

#====================================================================================================
# FORTIMANAGER/FORTIANALYZER INTEGRATION
#====================================================================================================
variable "enable_fortimanager" {
  description = "Register FortiGate HA pair with FortiManager"
  type        = bool
  default     = false
}

variable "fortimanager_ip" {
  description = "Private IP address of FortiManager instance"
  type        = string
  default     = ""
}

variable "enable_fortianalyzer" {
  description = "Configure FortiGate HA pair to send logs to FortiAnalyzer"
  type        = bool
  default     = false
}

variable "fortianalyzer_ip" {
  description = "Private IP address of FortiAnalyzer instance"
  type        = string
  default     = ""
}

#====================================================================================================
# INTERNET ACCESS MODE
#====================================================================================================
variable "access_internet_mode" {
  description = "Method for FortiGate internet egress (eip or nat_gw)"
  type        = string
  default     = "eip"
  validation {
    condition     = contains(["eip", "nat_gw"], var.access_internet_mode)
    error_message = "Internet access mode must be 'eip' or 'nat_gw'."
  }
}

#====================================================================================================
# TRANSIT GATEWAY INTEGRATION
#====================================================================================================
variable "enable_tgw_attachment" {
  description = "Attach inspection VPC to Transit Gateway"
  type        = bool
  default     = false
}

variable "attach_to_tgw_name" {
  description = "Name of Transit Gateway to integrate with"
  type        = string
  default     = ""
}

variable "update_tgw_routes" {
  description = "Update east/west TGW route tables to point default route to inspection VPC"
  type        = bool
  default     = true
}
