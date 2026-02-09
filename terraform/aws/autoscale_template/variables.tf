variable "aws_region" {
  description = "The AWS region to use"
}
variable "availability_zone_1" {
  description = "Availability Zone 1 for VPC"
}
variable "availability_zone_2" {
  description = "Availability Zone 2 for VPC"
}
variable "fortigate_gui_port" {
  description = "Fortigate GUI Port"
  default = 443
}
variable "firewall_policy_mode" {
  description = "Firewall Policy Mode"
  type = string
  default = "2-arm"
}
variable "keypair" {
  description = "Keypair for instances that support keypairs"
}
variable "fortigate_management_cidr" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access FortiGate management interfaces"
  default     = []
}
variable "cp" {
  description = "Customer Prefix to apply to all resources"
}
variable "env" {
  description = "The Tag Environment to differentiate prod/test/dev"
}
variable "enable_dedicated_management_vpc" {
  description = "Boolean to allow creation of dedicated management interface in management VPC"
  type        = bool
}
variable "enable_dedicated_management_eni" {
  description = "Boolean to allow creation of dedicated management subnets and ENI in the inspection VPC"
  type        = bool
}
variable "primary_scalein_protection" {
  description = "Boolean to set the scale-in protection for the primary instance in the autoscale group"
  type        = bool
  default     = true
}
variable "asg_health_check_grace_period" {
  description = "Time in seconds after instance launch before health checks start"
  type        = number
  default     = 700
}
variable "enable_east_west_inspection" {
  description = "Boolean to allow creation of a separate autoscale group for east/west inspection"
  type        = bool
}

variable "allow_cross_zone_load_balancing" {
  description = "Allow gateway load balancer to use healthy instances in a different zone"
  type        = bool
}
variable "asg_module_prefix" {
  description = "Module Prefix for East/West Autoscale Group"
  type        = string
  default     = ""
}
variable "endpoint_name_az1" {
  description = "Name of the gwlb endpoint to route to in AZ1"
  type        = string
  default     = ""
}
variable "endpoint_name_az2" {
  description = "Name of the gwlb endpoint to route to in AZ2"
  type        = string
  default     = ""
}
variable "gwlb_healthy_threshold" {
  description = "Number of consecutive successful health checks before considering target healthy"
  type        = number
  default     = 5
}
variable "gwlb_health_check_interval" {
  description = "Time between health checks in seconds"
  type        = number
  default     = 60
}
variable "gwlb_health_check_port" {
  description = "Port used for GWLB health checks"
  type        = number
  default     = 8008
}
variable "gwlb_health_check_protocol" {
  description = "Protocol used for GWLB health checks (HTTP, HTTPS, TCP)"
  type        = string
  default     = "HTTP"
}
variable "gwlb_health_check_timeout" {
  description = "Time to wait for health check response in seconds"
  type        = number
  default     = 5
}
variable "gwlb_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before considering target unhealthy"
  type        = number
  default     = 3
}
variable "fgt_instance_type" {
  description = "Instance type for all of the Fortigates in the ASG's"
  type        = string
  default     = ""
}
variable "fortios_version" {
  description = "FortiGate OS Version of all instances in the Autoscale Groups"
  type        = string
  default     = ""
}
variable "fortigate_asg_password" {
  description = "Password for the Fortigate ASG"
}
variable "asg_license_directory" {
  description = "License Directory for North/South Autoscale Group"
  type        = string
  default     = ""
}
variable "fortiflex_username" {
  description = "Fortiflex Username to make FortiFlex API Calls"
  type        = string
  default     = ""
}
variable "fortiflex_password" {
    description = "Fortiflex Password to make FortiFlex API Calls"
    type        = string
    default     = ""
}
variable fortiflex_sn_list {
    description = "List of Serial Numbers for FortiFlex"
    type = list(string)
    default = []
}
variable fortiflex_configid_list {
    description = "Config ID for FortiFlex"
    type = list(string)
    default = []
}
variable "base_config_file" {
  description = "Initial Config File for Autoscale Group"
  type        = string
  default     = "fgt-conf.cfg"
}
variable "autoscale_license_model" {
  description = "License model: hybrid (BYOL baseline + on_demand burst), byol (BYOL only), on_demand (PAYG only)"
  type        = string
  default     = "hybrid"
  validation {
    condition     = contains(["hybrid", "byol", "on_demand"], var.autoscale_license_model)
    error_message = "autoscale_license_model must be one of: hybrid, byol, on_demand"
  }
}
variable "asg_scale_out_threshold" {
  description = "CPU percentage that triggers scale-out"
  type        = number
  default     = 80
  validation {
    condition     = var.asg_scale_out_threshold >= 50 && var.asg_scale_out_threshold <= 95
    error_message = "Scale-out threshold must be between 50 and 95."
  }
}
variable "asg_scale_in_threshold" {
  description = "CPU percentage that triggers scale-in"
  type        = number
  default     = 20
  validation {
    condition     = var.asg_scale_in_threshold >= 10 && var.asg_scale_in_threshold <= 50
    error_message = "Scale-in threshold must be between 10 and 50."
  }
}
variable "asg_byol_asg_min_size" {
    description = "Minimum size for the BYOL ASG"
    type        = number
    default     = 1
}
variable "asg_byol_asg_max_size" {
    description = "Maximum size for the BYOL ASG"
    type        = number
    default     = 2
}
variable "asg_byol_asg_desired_size" {
    description = "Desired size for the BYOL ASG"
    type        = number
    default     = 1
}
variable "asg_ondemand_asg_min_size" {
    description = "Minimum size for the On Demand ASG"
    type        = number
    default     = 0
}
variable "asg_ondemand_asg_max_size" {
    description = "Maximum size for the OnDemand ASG"
    type        = number
    default     = 2
}
variable "asg_ondemand_asg_desired_size" {
    description = "Desired size for the OnDemand ASG"
    type        = number
    default     = 0
}
variable "acl" {
  description = "The acl for linux instances"
}
variable "enable_fortimanager_integration" {
  description = "Boolean to enable FortiManager integration"
  type        = bool
  default     = false
}
variable "fortimanager_ip" {
  description = "IP address of the FortiManager"
  type        = string
  default     = ""
}
variable "fortimanager_sn" {
  description = "Serial Number of the FortiManager"
  type        = string
  default     = ""
}
variable "fortimanager_vrf_select" {
  description = "VRF to use to reach the Fortianager"
  type        = number
  default     = 0
}
variable "enable_distributed_inspection" {
  description = "Enable distributed egress by discovering VPCs tagged with purpose=distributed_egress and configuring GWLB endpoints"
  type        = bool
  default     = false
}


