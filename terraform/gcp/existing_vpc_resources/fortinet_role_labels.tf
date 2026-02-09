#====================================================================================================
# FORTINET-ROLE RESOURCE DISCOVERY
#====================================================================================================
# GCP resource discovery strategy:
#
# Unlike AWS where we use Fortinet-Role tags on all resources, GCP has limitations:
# - google_compute_network: Does NOT support labels
# - google_compute_subnetwork: Does NOT support labels
# - google_compute_instance: Supports labels
# - google_compute_firewall: Does NOT support labels
# - google_compute_disk: Supports labels
#
# Strategy: Use consistent naming convention for all resources.
# Resources are discovered by name pattern: {cp}-{env}-{resource-type}
# The backend API discovers GCP resources by name filter instead of label filter.
#
# Naming Convention:
# | Resource                          | Name                                             |
# |-----------------------------------|--------------------------------------------------|
# | Inspection VPC                    | {cp}-{env}-inspection-vpc                        |
# | Inspection Public Subnet AZ1      | {cp}-{env}-inspection-public-az1                |
# | Inspection Public Subnet AZ2      | {cp}-{env}-inspection-public-az2                |
# | Inspection Private Subnet AZ1     | {cp}-{env}-inspection-private-az1               |
# | Inspection Private Subnet AZ2     | {cp}-{env}-inspection-private-az2               |
# | Inspection ILB Subnet AZ1         | {cp}-{env}-inspection-ilb-az1                   |
# | Inspection ILB Subnet AZ2         | {cp}-{env}-inspection-ilb-az2                   |
# | Inspection HA Sync Subnet AZ1     | {cp}-{env}-inspection-hasync-az1                |
# | Inspection HA Sync Subnet AZ2     | {cp}-{env}-inspection-hasync-az2                |
# | Management VPC                    | {cp}-{env}-management-vpc                        |
# | Management Subnet AZ1             | {cp}-{env}-management-az1                        |
# | Management Subnet AZ2             | {cp}-{env}-management-az2                        |
# | East VPC                          | {cp}-{env}-east-vpc                              |
# | East Subnet                       | {cp}-{env}-east-subnet                           |
# | West VPC                          | {cp}-{env}-west-vpc                              |
# | West Subnet                       | {cp}-{env}-west-subnet                           |
#
# For resources that DO support labels (instances), we add fortinet_role labels
# for additional discovery capabilities.

locals {
  # Sanitize cp and env for GCP labels (lowercase, hyphens to underscores)
  label_cp  = replace(lower(var.cp), "-", "_")
  label_env = replace(lower(var.env), "-", "_")
}
