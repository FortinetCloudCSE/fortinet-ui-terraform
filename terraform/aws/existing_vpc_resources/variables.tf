variable "aws_region" {
  description = "The AWS region to use"
}
variable "availability_zone_1" {
  description = "Availability Zone 1 for VPC"
}
variable "availability_zone_2" {
  description = "Availability Zone 2 for VPC"
}
variable "cp" {
  description = "Customer Prefix to apply to all resources"
}
variable "env" {
  description = "The Tag Environment to differentiate prod/test/dev"
}
variable subnet_bits {
  description = "Number of bits in the network portion of the subnet CIDR"
}
variable spoke_subnet_bits {
  description = "Number of bits in the network portion of the subnet CIDR in spoke VPCs"
}
variable "keypair" {
  description = "Keypair for instances that support keypairs"
}
variable "management_cidr_sg" {
    description = "List of CIDRs for IP allowlist to restrict security group access"
    type        = list(string)
    default     = ["0.0.0.0/0"]
}
variable "enable_autoscale_deployment" {
  description = "Create subnets for AutoScale template with GWLB"
  type        = bool
  default     = true
}
variable "enable_ha_pair_deployment" {
  description = "Create subnets for HA Pair template with FGCP"
  type        = bool
  default     = false
}
variable "access_internet_mode" {
  description = "Variable that defines how the fortigates in the autoscale group will access the internet. 'nat_gw' or 'eip'"
  type = string
  default = "nat_gw"
}
variable "vpc_cidr_management" {
    description = "CIDR for the management VPC"
}
variable "vpc_cidr_inspection" {
    description = "CIDR for the whole NS inspection VPC"
}
variable "vpc_cidr_ns_inspection" {
    description = "CIDR for the inspection VPC"
}
variable "enable_tgw_attachment" {
  description = "Allow Inspection VPC to attach to an existing TGW"
  type        = bool
}
variable "create_tgw_routes_for_existing" {
  description = "Boolean to allow creation of TGW routes for the existing_vpc_resources template"
  type        = bool
}
variable "create_management_subnet_in_inspection_vpc" {
  description = "Boolean to allow creation of dedicated management subnets in the inspection VPC"
  type        = bool
}
variable "enable_fortimanager" {
  description = "Boolean to allow creation of FortiManager in Inspection VPC"
  type        = bool
  default     = false
}
variable "enable_fortimanager_public_ip" {
  description = "Boolean to allow creation of FortiManager public IP in Inspection VPC"
  type        = bool
  default     = false
}
variable "fortimanager_instance_type" {
  description = "Instance type for fortimanager"
  type        = string
  default     = "m5.xlarge"
}
variable "fortimanager_os_version" {
  description = "Fortimanager OS Version for the AMI Search String"
  type        = string
  default     = "7.6.1"
}
variable "fortimanager_host_ip" {
  description = "Fortimanager IP Address"
  type        = number
  default     = 14
}
variable "fortimanager_license_file" {
  description = "Full path for FortiManager License"
  type        = string
  default     = ""
}
variable "fortimanager_vm_name" {
  description = "FortiManager VM Name"
  type        = string
  default     = ""
}
variable "fortimanager_admin_password" {
  description = "FortiManager Admin Password"
  type        = string
  default     = ""
}
variable "enable_fortianalyzer" {
  description = "Boolean to allow creation of FortiAnalyzer in Inspection VPC"
  type        = bool
  default     = false
}
variable "enable_fortianalyzer_public_ip" {
  description = "Boolean to allow creation of FortiAnalyzer public IP in Inspection VPC"
  type        = bool
  default     = false
}
variable "fortianalyzer_host_ip" {
  description = "Fortianalyzer IP Address"
  type        = number
  default     = 13
}
variable "fortianalyzer_instance_type" {
  description = "Instance type for fortianalyzer"
  type        = string
  default     = "m5.xlarge"
}
variable "fortianalyzer_os_version" {
  description = "Fortianalyzer OS Version for the AMI Search String"
  type        = string
  default     = "7.6.1"
}
variable "fortianalyzer_license_file" {
  description = "Full path for FortiAnalyzer License"
  type        = string
  default     = ""
}
variable "fortianalyzer_vm_name" {
  description = "fortianalyzer VM Name"
  type        = string
  default     = ""
}
variable "fortianalyzer_admin_password" {
  description = "fortianalyzer Admin Password"
  type        = string
  default     = ""
}
variable "enable_jump_box" {
  description = "Boolean to allow creation of Linux Jump Box in Inspection VPC"
  type        = bool
}
variable "enable_jump_box_public_ip" {
  description = "Boolean to allow creation of Linux Jump Box public IP in Inspection VPC"
  type        = bool
}
variable "linux_instance_type" {
  description = "Linux Endpoint Instance Type"
}
variable "linux_host_ip" {
  description = "Fortigate Host IP for all subnets"
}
variable "enable_build_existing_subnets" {
  description = "Enable building the existing subnets behind the TGW"
  type        = bool
}
variable "enable_build_management_vpc" {
  description = "Enable building the management vpc"
  type        = bool
}
variable "enable_management_tgw_attachment" {
  description = "Allow Management VPC to attach to an existing TGW"
  type        = bool
}
variable "enable_linux_spoke_instances" {
  description = "Boolean to allow creation of Linux Spoke Instances in East and West VPCs"
  type        = bool
}
variable "attach_to_tgw_name" {
  description = "Name of the TGW to attach to"
  type        = string
  default     = ""
}
variable "vpc_cidr_east" {
    description = "CIDR for the whole east VPC"
}
variable "vpc_cidr_spoke" {
    description = "Super-Net CIDR for the spoke VPC's"
}
variable "vpc_cidr_west" {
    description = "CIDR for the whole west VPC"
}
variable "acl" {
  description = "The acl for linux instances"
}
variable "enable_ha_sync_subnets" {
  description = "Enable creation of HA sync subnets for FortiGate HA pair"
  type        = bool
  default     = false
}
variable "enable_distributed_egress_vpcs" {
  description = "Enable creation of distributed egress VPCs with GWLB endpoints"
  type        = bool
  default     = false
}

variable "distributed_egress_vpc_count" {
  description = "Number of distributed egress VPCs to create (1-3)"
  type        = number
  default     = 1
  validation {
    condition     = var.distributed_egress_vpc_count >= 1 && var.distributed_egress_vpc_count <= 3
    error_message = "distributed_egress_vpc_count must be between 1 and 3"
  }
}

variable "distributed_egress_subnet_bits" {
  description = "Number of bits in the network portion of distributed egress VPC subnets"
  type        = number
  default     = 4
}

variable "distributed_egress_vpc_1_cidr" {
  description = "CIDR block for distributed egress VPC 1"
  type        = string
  default     = "192.168.2.0/24"
}

variable "distributed_egress_vpc_2_cidr" {
  description = "CIDR block for distributed egress VPC 2"
  type        = string
  default     = "192.168.3.0/24"
}

variable "distributed_egress_vpc_3_cidr" {
  description = "CIDR block for distributed egress VPC 3"
  type        = string
  default     = "192.168.4.0/24"
}

variable "enable_distributed_linux_instances" {
  description = "Enable Linux instances in distributed VPCs for testing"
  type        = bool
  default     = true
}

variable "distributed_linux_instance_type" {
  description = "Instance type for Linux instances in distributed VPCs"
  type        = string
  default     = "t3.micro"
}

variable "distributed_linux_host_ip" {
  description = "Last octet of Linux instance private IPs in distributed VPCs"
  type        = number
  default     = 11
}

#====================================================================================================
# FORTITESTER CONFIGURATION
#====================================================================================================
# FortiTester pair deployment:
#   - FortiTester 1: Port1 in East AZ1, Port2 in West AZ1 (for AZ1 traffic testing)
#   - FortiTester 2: Port1 in West AZ2, Port2 in East AZ2 (for AZ2 traffic testing)

variable "enable_fortitester_1" {
  description = "Enable FortiTester 1 (East AZ1 <-> West AZ1)"
  type        = bool
  default     = false
}

variable "enable_fortitester_2" {
  description = "Enable FortiTester 2 (West AZ2 <-> East AZ2)"
  type        = bool
  default     = false
}

variable "fortitester_instance_type" {
  description = "FortiTester EC2 instance type"
  type        = string
  default     = "c5.xlarge"
}

variable "fortitester_os_version" {
  description = "FortiTester OS version for AMI search"
  type        = string
  default     = "7.1.0"
}

variable "fortitester_host_ip" {
  description = "Last octet of FortiTester private IPs (both port1 and port2)"
  type        = number
  default     = 6
}

variable "fortitester_admin_password" {
  description = "FortiTester admin password"
  type        = string
  default     = "Texas4me!"
}


