#!/bin/bash

# Generate Network Diagram Script
# Creates an SVG network diagram and markdown documentation based on deployed infrastructure
#
# Usage:
#   ./generate_network_diagram.sh                # Full regeneration of SVG and MD
#   ./generate_network_diagram.sh --fortigates-only  # Only update FortiGate IPs in existing MD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Parse arguments
FORTIGATES_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --fortigates-only)
            FORTIGATES_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --fortigates-only  Only update FortiGate instance IPs in existing network_diagram.md"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get terraform directory and tfvars file
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

# Output directory (repository root logs folder)
REPO_ROOT="$(cd "${TERRAFORM_DIR}/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/logs"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Output files
SVG_FILE="${OUTPUT_DIR}/network_diagram.svg"
MD_FILE="${OUTPUT_DIR}/network_diagram.md"

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_ONLY=$(date '+%Y-%m-%d')

print_section "GENERATING NETWORK DIAGRAM"

if [ ! -f "$TFVARS_FILE" ]; then
    print_fail "terraform.tfvars not found: $TFVARS_FILE"
    exit 1
fi

# Read configuration
AWS_REGION=$(get_tfvar "aws_region" "$TFVARS_FILE")
AZ1=$(get_tfvar "availability_zone_1" "$TFVARS_FILE")
AZ2=$(get_tfvar "availability_zone_2" "$TFVARS_FILE")
CP=$(get_tfvar "cp" "$TFVARS_FILE")
ENV=$(get_tfvar "env" "$TFVARS_FILE")
PREFIX="${CP}-${ENV}"

# VPC CIDRs
VPC_CIDR_MANAGEMENT=$(get_tfvar "vpc_cidr_management" "$TFVARS_FILE")
VPC_CIDR_INSPECTION=$(get_tfvar "vpc_cidr_inspection" "$TFVARS_FILE")
VPC_CIDR_EAST=$(get_tfvar "vpc_cidr_east" "$TFVARS_FILE")
VPC_CIDR_WEST=$(get_tfvar "vpc_cidr_west" "$TFVARS_FILE")

# Deployment mode
ENABLE_AUTOSCALE=$(get_tfvar "enable_autoscale_deployment" "$TFVARS_FILE")
ENABLE_HA_PAIR=$(get_tfvar "enable_ha_pair_deployment" "$TFVARS_FILE")

# Distributed VPCs
ENABLE_DISTRIBUTED=$(get_tfvar "enable_distributed_egress_vpcs" "$TFVARS_FILE")
DISTRIBUTED_COUNT=$(get_tfvar "distributed_egress_vpc_count" "$TFVARS_FILE")
DISTRIBUTED_VPC_1_CIDR=$(get_tfvar "distributed_egress_vpc_1_cidr" "$TFVARS_FILE")

# FortiTester settings
ENABLE_FORTITESTER_1=$(get_tfvar "enable_fortitester_1" "$TFVARS_FILE")
ENABLE_FORTITESTER_2=$(get_tfvar "enable_fortitester_2" "$TFVARS_FILE")

# Read FortiManager settings from autoscale_template tfvars (if exists)
AUTOSCALE_TFVARS_FILE="${TERRAFORM_DIR}/../autoscale_template/terraform.tfvars"
if [ -f "$AUTOSCALE_TFVARS_FILE" ]; then
    ENABLE_FMG_INTEGRATION=$(get_tfvar "enable_fortimanager_integration" "$AUTOSCALE_TFVARS_FILE")
    FORTIMANAGER_IP=$(get_tfvar "fortimanager_ip" "$AUTOSCALE_TFVARS_FILE")
    FORTIMANAGER_SN=$(get_tfvar "fortimanager_sn" "$AUTOSCALE_TFVARS_FILE")
else
    ENABLE_FMG_INTEGRATION="false"
    FORTIMANAGER_IP=""
    FORTIMANAGER_SN=""
fi

print_info "Region: $AWS_REGION"
print_info "Resource Prefix: $PREFIX"
print_info "Output Directory: $OUTPUT_DIR"

#=============================================================================
# FORTIGATES-ONLY MODE: Quick update of just FortiGate IPs in existing MD file
#=============================================================================
if [ "$FORTIGATES_ONLY" = true ]; then
    print_section "UPDATING FORTIGATE IPS ONLY"

    if [ ! -f "$MD_FILE" ]; then
        print_fail "network_diagram.md not found: $MD_FILE"
        print_info "Run without --fortigates-only first to generate the full diagram"
        exit 1
    fi

    # Get inspection VPC ID for the third query
    INSPECTION_VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${PREFIX}-inspection-vpc" \
        --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

    print_info "Querying FortiGate ASG instances..."

    # Query FortiGate instances (same logic as full generation)
    FORTIGATE_INSTANCES_JSON=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
                  "Name=tag:Name,Values=*fortigate*" \
        --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
        --output json 2>/dev/null)

    FORTIGATE_INSTANCES_JSON2=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
                  "Name=tag:Name,Values=*fgt*asg*" \
        --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
        --output json 2>/dev/null)

    if [ -n "$INSPECTION_VPC_ID" ] && [ "$INSPECTION_VPC_ID" != "None" ]; then
        FORTIGATE_INSTANCES_JSON3=$(aws ec2 describe-instances --region "$AWS_REGION" \
            --filters "Name=instance-state-name,Values=running" \
                      "Name=vpc-id,Values=${INSPECTION_VPC_ID}" \
                      "Name=tag:Name,Values=*fgt*" \
            --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
            --output json 2>/dev/null)
    else
        FORTIGATE_INSTANCES_JSON3="[]"
    fi

    # Build FortiGate table
    FORTIGATE_COUNT=0
    FORTIGATE_MD_TABLE=""

    # Process query results
    for json_var in "$FORTIGATE_INSTANCES_JSON" "$FORTIGATE_INSTANCES_JSON2" "$FORTIGATE_INSTANCES_JSON3"; do
        if [ -n "$json_var" ] && [ "$json_var" != "[]" ] && [ "$FORTIGATE_COUNT" -eq 0 ]; then
            while IFS= read -r line; do
                FGT_NAME=$(echo "$line" | jq -r '.[0]' 2>/dev/null)
                FGT_ID=$(echo "$line" | jq -r '.[1]' 2>/dev/null)
                FGT_PRIVATE=$(echo "$line" | jq -r '.[2]' 2>/dev/null)
                FGT_PUBLIC=$(echo "$line" | jq -r '.[3]' 2>/dev/null)
                FGT_ROLE=$(echo "$line" | jq -r '.[4]' 2>/dev/null)

                if [ -n "$FGT_NAME" ] && [ "$FGT_NAME" != "null" ]; then
                    [ "$FGT_PUBLIC" == "null" ] && FGT_PUBLIC="N/A"
                    [ "$FGT_ROLE" == "null" ] && FGT_ROLE="-"
                    FORTIGATE_MD_TABLE="${FORTIGATE_MD_TABLE}| ${FGT_NAME} | ${FGT_ID} | ${FGT_ROLE} | ${FGT_PRIVATE} | ${FGT_PUBLIC} |\n"
                    FORTIGATE_COUNT=$((FORTIGATE_COUNT + 1))
                fi
            done < <(echo "$json_var" | jq -c '.[]' 2>/dev/null)
        fi
    done

    if [ "$FORTIGATE_COUNT" -gt 0 ]; then
        print_pass "Found $FORTIGATE_COUNT FortiGate instance(s)"

        # Create the new FortiGate section content
        NEW_FGT_SECTION="### FortiGate AutoScale Group Instances

| Instance Name | Instance ID | Role | Private IP | Public IP (Management) |
|--------------|-------------|------|------------|------------------------|
$(echo -e "$FORTIGATE_MD_TABLE")> **Note:** FortiGate management interfaces are accessible via their public IPs. Use \\\`admin\\\` as username with the configured password. The **Primary** instance holds the configuration that is synced to Secondary instances."

        # Use awk to replace the FortiGate section in the MD file
        # Find from "### FortiGate AutoScale Group Instances" to the next "###" or "---"
        awk -v new_section="$NEW_FGT_SECTION" '
        /^### FortiGate AutoScale Group Instances/ {
            print new_section
            in_fgt_section = 1
            next
        }
        in_fgt_section && /^(###|---)/ {
            in_fgt_section = 0
        }
        !in_fgt_section {
            print
        }
        ' "$MD_FILE" > "${MD_FILE}.tmp" && mv "${MD_FILE}.tmp" "$MD_FILE"

        print_pass "Updated FortiGate section in: $MD_FILE"
    else
        print_info "No FortiGate ASG instances found"
    fi

    echo ""
    exit 0
fi

# Collect VPC IDs
MGMT_VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-management-vpc" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

INSPECTION_VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-vpc" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

EAST_VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-vpc" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

WEST_VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-vpc" \
    --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

# Get TGW ID
TGW_ID=$(aws ec2 describe-transit-gateways --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-tgw" \
    --query 'TransitGateways[0].TransitGatewayId' --output text 2>/dev/null)

# Function to get subnet info
get_subnet_info() {
    local vpc_id="$1"
    local subnet_name_pattern="$2"

    aws ec2 describe-subnets --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=*${subnet_name_pattern}*" \
        --query 'Subnets[0].[SubnetId,CidrBlock]' --output text 2>/dev/null
}

# Collect instance information
print_info "Collecting instance information..."

# Function to get instance info by name pattern
get_instance_private_ip() {
    local instance_name="$1"
    aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${instance_name}" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text 2>/dev/null
}

get_instance_public_ip() {
    local instance_name="$1"
    aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${instance_name}" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null
}

get_instance_id() {
    local instance_name="$1"
    aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${instance_name}" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null
}

# Get subnet CIDRs for each VPC
# Management VPC
MGMT_PUBLIC_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-management-public-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
MGMT_PUBLIC_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-management-public-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
MGMT_PRIVATE_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-management-private-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
MGMT_PRIVATE_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-management-private-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)

# Inspection VPC
INSP_PUBLIC_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-public-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_PUBLIC_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-public-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_GWLBE_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-gwlbe-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_GWLBE_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-gwlbe-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_PRIVATE_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-private-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_PRIVATE_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-private-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_NATGW_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-natgw-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_NATGW_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-natgw-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_TGW_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-tgw-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
INSP_TGW_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-inspection-tgw-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)

# GWLB Endpoints (created by autoscale_template)
# Note: These use truncated prefix like "dis-p-asg" instead of full "dis-poc"
GWLBE_AZ1_ID=$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" \
    --filters "Name=vpc-endpoint-type,Values=GatewayLoadBalancer" \
              "Name=tag:Name,Values=*gwlbe_az1*" \
    --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null)
GWLBE_AZ2_ID=$(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" \
    --filters "Name=vpc-endpoint-type,Values=GatewayLoadBalancer" \
              "Name=tag:Name,Values=*gwlbe_az2*" \
    --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null)
[ "$GWLBE_AZ1_ID" == "None" ] && GWLBE_AZ1_ID=""
[ "$GWLBE_AZ2_ID" == "None" ] && GWLBE_AZ2_ID=""

# East VPC
EAST_PUBLIC_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-public-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
EAST_PUBLIC_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-public-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
EAST_TGW_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-tgw-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
EAST_TGW_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-tgw-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)

# West VPC
WEST_PUBLIC_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-public-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
WEST_PUBLIC_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-public-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
WEST_TGW_AZ1_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-tgw-az1-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)
WEST_TGW_AZ2_CIDR=$(aws ec2 describe-subnets --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-tgw-az2-subnet" \
    --query 'Subnets[0].CidrBlock' --output text 2>/dev/null)

# Get instance IPs using direct AWS queries (avoiding bash associative arrays for macOS compatibility)
JUMP_BOX_NAME="${PREFIX}-management-jump-box-instance"
JUMP_BOX_PRIVATE=$(get_instance_private_ip "$JUMP_BOX_NAME")
JUMP_BOX_PUBLIC=$(get_instance_public_ip "$JUMP_BOX_NAME")
JUMP_BOX_ID=$(get_instance_id "$JUMP_BOX_NAME")
[ "$JUMP_BOX_PUBLIC" == "None" ] && JUMP_BOX_PUBLIC=""
[ "$JUMP_BOX_ID" == "None" ] && JUMP_BOX_ID=""

EAST_AZ1_NAME="${PREFIX}-east-public-az1-instance"
EAST_AZ1_PRIVATE=$(get_instance_private_ip "$EAST_AZ1_NAME")

EAST_AZ2_NAME="${PREFIX}-east-public-az2-instance"
EAST_AZ2_PRIVATE=$(get_instance_private_ip "$EAST_AZ2_NAME")

WEST_AZ1_NAME="${PREFIX}-west-public-az1-instance"
WEST_AZ1_PRIVATE=$(get_instance_private_ip "$WEST_AZ1_NAME")

WEST_AZ2_NAME="${PREFIX}-west-public-az2-instance"
WEST_AZ2_PRIVATE=$(get_instance_private_ip "$WEST_AZ2_NAME")

# Distributed VPC instances
DIST1_AZ1_NAME="${PREFIX}-distributed-1-instance-az1"
DIST1_AZ1_PRIVATE=$(get_instance_private_ip "$DIST1_AZ1_NAME")
DIST1_AZ1_PUBLIC=$(get_instance_public_ip "$DIST1_AZ1_NAME")
DIST1_AZ1_ID=$(get_instance_id "$DIST1_AZ1_NAME")
[ "$DIST1_AZ1_PUBLIC" == "None" ] && DIST1_AZ1_PUBLIC=""
[ "$DIST1_AZ1_ID" == "None" ] && DIST1_AZ1_ID=""

DIST1_AZ2_NAME="${PREFIX}-distributed-1-instance-az2"
DIST1_AZ2_PRIVATE=$(get_instance_private_ip "$DIST1_AZ2_NAME")
DIST1_AZ2_PUBLIC=$(get_instance_public_ip "$DIST1_AZ2_NAME")
DIST1_AZ2_ID=$(get_instance_id "$DIST1_AZ2_NAME")
[ "$DIST1_AZ2_PUBLIC" == "None" ] && DIST1_AZ2_PUBLIC=""
[ "$DIST1_AZ2_ID" == "None" ] && DIST1_AZ2_ID=""

# FortiTester instances
FORTITESTER_1_NAME="${PREFIX}-fortitester-1"
FORTITESTER_1_PRIVATE=$(get_instance_private_ip "$FORTITESTER_1_NAME")
FORTITESTER_1_PUBLIC=$(get_instance_public_ip "$FORTITESTER_1_NAME")
FORTITESTER_1_ID=$(get_instance_id "$FORTITESTER_1_NAME")
[ "$FORTITESTER_1_PUBLIC" == "None" ] && FORTITESTER_1_PUBLIC=""
[ "$FORTITESTER_1_ID" == "None" ] && FORTITESTER_1_ID=""

FORTITESTER_2_NAME="${PREFIX}-fortitester-2"
FORTITESTER_2_PRIVATE=$(get_instance_private_ip "$FORTITESTER_2_NAME")
FORTITESTER_2_PUBLIC=$(get_instance_public_ip "$FORTITESTER_2_NAME")
FORTITESTER_2_ID=$(get_instance_id "$FORTITESTER_2_NAME")
[ "$FORTITESTER_2_PUBLIC" == "None" ] && FORTITESTER_2_PUBLIC=""
[ "$FORTITESTER_2_ID" == "None" ] && FORTITESTER_2_ID=""

# Get FortiTester ENI IPs for port2 and port3
# FortiTester 1: Port1 in Mgmt AZ1, Port2 in East AZ1, Port3 in West AZ1
# FortiTester 2: Port1 in Mgmt AZ2, Port2 in West AZ2, Port3 in East AZ2
if [ -n "$FORTITESTER_1_PRIVATE" ] && [ "$FORTITESTER_1_PRIVATE" != "None" ]; then
    # Get instance ID for FortiTester 1
    FT1_INSTANCE_ID=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${FORTITESTER_1_NAME}" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
    if [ -n "$FT1_INSTANCE_ID" ] && [ "$FT1_INSTANCE_ID" != "None" ]; then
        # Get all ENI IPs for this instance
        FT1_ENIS=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
            --filters "Name=attachment.instance-id,Values=${FT1_INSTANCE_ID}" \
            --query 'NetworkInterfaces[*].[Attachment.DeviceIndex,PrivateIpAddress]' --output text 2>/dev/null)
        FORTITESTER_1_PORT2_IP=$(echo "$FT1_ENIS" | awk '$1==1 {print $2}')
        FORTITESTER_1_PORT3_IP=$(echo "$FT1_ENIS" | awk '$1==2 {print $2}')
    fi
fi

if [ -n "$FORTITESTER_2_PRIVATE" ] && [ "$FORTITESTER_2_PRIVATE" != "None" ]; then
    # Get instance ID for FortiTester 2
    FT2_INSTANCE_ID=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${FORTITESTER_2_NAME}" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
    if [ -n "$FT2_INSTANCE_ID" ] && [ "$FT2_INSTANCE_ID" != "None" ]; then
        # Get all ENI IPs for this instance
        FT2_ENIS=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
            --filters "Name=attachment.instance-id,Values=${FT2_INSTANCE_ID}" \
            --query 'NetworkInterfaces[*].[Attachment.DeviceIndex,PrivateIpAddress]' --output text 2>/dev/null)
        FORTITESTER_2_PORT2_IP=$(echo "$FT2_ENIS" | awk '$1==1 {print $2}')
        FORTITESTER_2_PORT3_IP=$(echo "$FT2_ENIS" | awk '$1==2 {print $2}')
    fi
fi

# Query FortiGate ASG instances (if deployed)
# FortiGates are typically tagged with names containing "fortigate" or "fgt" and belong to an ASG
# Note: The upstream autoscale module may truncate the prefix in instance names
# Note: FortiGates have public IPs on their management ENI, not the primary ENI
#       We query NetworkInterfaces[*].Association.PublicIp to find any public IP
# Note: We also query the "Autoscale Role" tag to identify Primary/Secondary
print_info "Checking for FortiGate ASG instances..."
FORTIGATE_INSTANCES_JSON=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:Name,Values=*fortigate*" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
    --output json 2>/dev/null)

# Also check for instances with fgt_asg pattern (common naming from autoscale module)
# The module may use truncated prefix like "dis-p" instead of full "dis-poc"
FORTIGATE_INSTANCES_JSON2=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:Name,Values=*fgt*asg*" \
    --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
    --output json 2>/dev/null)

# Third check: look for instances in the inspection VPC that are FortiGates
# This catches FortiGates regardless of naming convention
if [ -n "$INSPECTION_VPC_ID" ] && [ "$INSPECTION_VPC_ID" != "None" ]; then
    FORTIGATE_INSTANCES_JSON3=$(aws ec2 describe-instances --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
                  "Name=vpc-id,Values=${INSPECTION_VPC_ID}" \
                  "Name=tag:Name,Values=*fgt*" \
        --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,NetworkInterfaces[*].Association.PublicIp|[?@]|[0],Tags[?Key=='Autoscale Role'].Value|[0]]" \
        --output json 2>/dev/null)
else
    FORTIGATE_INSTANCES_JSON3="[]"
fi

# Parse FortiGate instance data into a simple format for the markdown
FORTIGATE_COUNT=0
FORTIGATE_MD_TABLE=""

# Process first query results
if [ -n "$FORTIGATE_INSTANCES_JSON" ] && [ "$FORTIGATE_INSTANCES_JSON" != "[]" ]; then
    while IFS= read -r line; do
        FGT_NAME=$(echo "$line" | jq -r '.[0]' 2>/dev/null)
        FGT_ID=$(echo "$line" | jq -r '.[1]' 2>/dev/null)
        FGT_PRIVATE=$(echo "$line" | jq -r '.[2]' 2>/dev/null)
        FGT_PUBLIC=$(echo "$line" | jq -r '.[3]' 2>/dev/null)
        FGT_ROLE=$(echo "$line" | jq -r '.[4]' 2>/dev/null)

        if [ -n "$FGT_NAME" ] && [ "$FGT_NAME" != "null" ]; then
            [ "$FGT_PUBLIC" == "null" ] && FGT_PUBLIC="N/A"
            [ "$FGT_ROLE" == "null" ] && FGT_ROLE="-"
            FORTIGATE_MD_TABLE="${FORTIGATE_MD_TABLE}| ${FGT_NAME} | ${FGT_ID} | ${FGT_ROLE} | ${FGT_PRIVATE} | ${FGT_PUBLIC} |
"
            FORTIGATE_COUNT=$((FORTIGATE_COUNT + 1))
        fi
    done < <(echo "$FORTIGATE_INSTANCES_JSON" | jq -c '.[]' 2>/dev/null)
fi

# Process second query results (avoid duplicates by checking if already found)
if [ -n "$FORTIGATE_INSTANCES_JSON2" ] && [ "$FORTIGATE_INSTANCES_JSON2" != "[]" ] && [ "$FORTIGATE_COUNT" -eq 0 ]; then
    while IFS= read -r line; do
        FGT_NAME=$(echo "$line" | jq -r '.[0]' 2>/dev/null)
        FGT_ID=$(echo "$line" | jq -r '.[1]' 2>/dev/null)
        FGT_PRIVATE=$(echo "$line" | jq -r '.[2]' 2>/dev/null)
        FGT_PUBLIC=$(echo "$line" | jq -r '.[3]' 2>/dev/null)
        FGT_ROLE=$(echo "$line" | jq -r '.[4]' 2>/dev/null)

        if [ -n "$FGT_NAME" ] && [ "$FGT_NAME" != "null" ]; then
            [ "$FGT_PUBLIC" == "null" ] && FGT_PUBLIC="N/A"
            [ "$FGT_ROLE" == "null" ] && FGT_ROLE="-"
            FORTIGATE_MD_TABLE="${FORTIGATE_MD_TABLE}| ${FGT_NAME} | ${FGT_ID} | ${FGT_ROLE} | ${FGT_PRIVATE} | ${FGT_PUBLIC} |
"
            FORTIGATE_COUNT=$((FORTIGATE_COUNT + 1))
        fi
    done < <(echo "$FORTIGATE_INSTANCES_JSON2" | jq -c '.[]' 2>/dev/null)
fi

# Process third query results (inspection VPC search - avoid duplicates)
if [ -n "$FORTIGATE_INSTANCES_JSON3" ] && [ "$FORTIGATE_INSTANCES_JSON3" != "[]" ] && [ "$FORTIGATE_COUNT" -eq 0 ]; then
    while IFS= read -r line; do
        FGT_NAME=$(echo "$line" | jq -r '.[0]' 2>/dev/null)
        FGT_ID=$(echo "$line" | jq -r '.[1]' 2>/dev/null)
        FGT_PRIVATE=$(echo "$line" | jq -r '.[2]' 2>/dev/null)
        FGT_PUBLIC=$(echo "$line" | jq -r '.[3]' 2>/dev/null)
        FGT_ROLE=$(echo "$line" | jq -r '.[4]' 2>/dev/null)

        if [ -n "$FGT_NAME" ] && [ "$FGT_NAME" != "null" ]; then
            [ "$FGT_PUBLIC" == "null" ] && FGT_PUBLIC="N/A"
            [ "$FGT_ROLE" == "null" ] && FGT_ROLE="-"
            FORTIGATE_MD_TABLE="${FORTIGATE_MD_TABLE}| ${FGT_NAME} | ${FGT_ID} | ${FGT_ROLE} | ${FGT_PRIVATE} | ${FGT_PUBLIC} |
"
            FORTIGATE_COUNT=$((FORTIGATE_COUNT + 1))
        fi
    done < <(echo "$FORTIGATE_INSTANCES_JSON3" | jq -c '.[]' 2>/dev/null)
fi

if [ "$FORTIGATE_COUNT" -gt 0 ]; then
    print_pass "Found $FORTIGATE_COUNT FortiGate instance(s)"
    FGT_SVG_STATUS="(${FORTIGATE_COUNT} instance(s))"
    FGT_SVG_STATUS_COLOR="#00FF00"
    FGT_LEGEND_TEXT="FortiGate ASG (deployed)"
    FGT_DEPLOY_STATUS="ASG deployed: ${FORTIGATE_COUNT} instance(s)"
    FGT_DEPLOY_STATUS_COLOR="#00FF00"
else
    print_info "No FortiGate ASG instances found (autoscale template not yet deployed)"
    FGT_SVG_STATUS="(Not Deployed)"
    FGT_SVG_STATUS_COLOR="#888"
    FGT_LEGEND_TEXT="FortiGate ASG (not deployed)"
    FGT_DEPLOY_STATUS="ASG not deployed yet"
    FGT_DEPLOY_STATUS_COLOR="#888"
fi

# Check TGW route table status for East/West
EAST_TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-east-tgw-rtb" \
    --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' --output text 2>/dev/null)

EAST_TGW_DEFAULT_ROUTE="No default route"
if [ -n "$EAST_TGW_RT_ID" ] && [ "$EAST_TGW_RT_ID" != "None" ]; then
    EAST_TGW_TARGET=$(aws ec2 search-transit-gateway-routes --region "$AWS_REGION" \
        --transit-gateway-route-table-id "$EAST_TGW_RT_ID" \
        --filters "Name=type,Values=static" \
        --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
        --output text 2>/dev/null)
    [ -n "$EAST_TGW_TARGET" ] && EAST_TGW_DEFAULT_ROUTE="$EAST_TGW_TARGET"
fi

WEST_TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PREFIX}-west-tgw-rtb" \
    --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' --output text 2>/dev/null)

WEST_TGW_DEFAULT_ROUTE="No default route"
if [ -n "$WEST_TGW_RT_ID" ] && [ "$WEST_TGW_RT_ID" != "None" ]; then
    WEST_TGW_TARGET=$(aws ec2 search-transit-gateway-routes --region "$AWS_REGION" \
        --transit-gateway-route-table-id "$WEST_TGW_RT_ID" \
        --filters "Name=type,Values=static" \
        --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
        --output text 2>/dev/null)
    [ -n "$WEST_TGW_TARGET" ] && WEST_TGW_DEFAULT_ROUTE="$WEST_TGW_TARGET"
fi

# Determine deployment mode text
DEPLOY_MODE="Autoscale"
[ "$ENABLE_HA_PAIR" = "true" ] && DEPLOY_MODE="HA Pair"

# Determine route status color/text
ROUTE_STATUS_COLOR="#FF4444"
ROUTE_STATUS_TEXT="Pending ASG"
if [ "$EAST_TGW_DEFAULT_ROUTE" != "No default route" ]; then
    ROUTE_STATUS_COLOR="#00FF00"
    ROUTE_STATUS_TEXT="Active"
fi

print_info "Generating SVG diagram..."

# Generate SVG
cat > "$SVG_FILE" << SVGEOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2200 1400" font-family="Arial, sans-serif">
  <defs>
    <!-- Gradients -->
    <linearGradient id="greenGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#2E8B2E;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1B660F;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="blueGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#1E90FF;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#147EBA;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="purpleGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#9966CC;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#8C4FFF;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="orangeGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FF8C00;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#ED7100;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="redGradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FF4444;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#EE3124;stop-opacity:1" />
    </linearGradient>
  </defs>

  <!-- Background -->
  <rect width="2200" height="1400" fill="#1a1a2e"/>

  <!-- Title -->
  <text x="1100" y="55" text-anchor="middle" fill="white" font-size="32" font-weight="bold">${PREFIX} Infrastructure - ${AWS_REGION} (AZ: ${AZ1}, ${AZ2})</text>
  <text x="1100" y="90" text-anchor="middle" fill="#888" font-size="18">Generated: ${TIMESTAMP} | Template: existing_vpc_resources</text>

  <!-- Internet Gateway Icons -->
  <!-- Management VPC IGW -->
  <rect x="280" y="115" width="120" height="48" rx="5" fill="#232F3E" stroke="#FF9900" stroke-width="2"/>
  <text x="340" y="146" text-anchor="middle" fill="#FF9900" font-size="18" font-weight="bold">IGW</text>
  <line x1="340" y1="163" x2="340" y2="190" stroke="#FF9900" stroke-width="2" stroke-dasharray="4,2"/>

  <!-- Inspection VPC IGW -->
  <rect x="1680" y="115" width="120" height="48" rx="5" fill="#232F3E" stroke="#FF9900" stroke-width="2"/>
  <text x="1740" y="146" text-anchor="middle" fill="#FF9900" font-size="18" font-weight="bold">IGW</text>
  <line x1="1740" y1="163" x2="1740" y2="190" stroke="#FF9900" stroke-width="2" stroke-dasharray="4,2"/>

  <!-- ==================== MANAGEMENT VPC ==================== -->
  <rect x="60" y="190" width="600" height="450" rx="10" fill="none" stroke="#3B48CC" stroke-width="3"/>
  <text x="85" y="230" fill="white" font-size="24" font-weight="bold">Management VPC</text>
  <text x="85" y="260" fill="#888" font-size="17">${MGMT_VPC_ID} | ${VPC_CIDR_MANAGEMENT}</text>

  <!-- Management Public Subnets -->
  <rect x="90" y="290" width="250" height="145" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="215" y="325" text-anchor="middle" fill="white" font-size="18" font-weight="bold">Public AZ1</text>
  <text x="215" y="352" text-anchor="middle" fill="white" font-size="16">${MGMT_PUBLIC_AZ1_CIDR}</text>
  <!-- Jump Box -->
  <rect x="115" y="368" width="200" height="62" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="215" y="392" text-anchor="middle" fill="#FF9900" font-size="16">Jump Box</text>
  <text x="215" y="412" text-anchor="middle" fill="white" font-size="15">${JUMP_BOX_PRIVATE}</text>
  <text x="215" y="428" text-anchor="middle" fill="#00FF00" font-size="14">${JUMP_BOX_PUBLIC}</text>

  <rect x="370" y="290" width="250" height="145" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="495" y="325" text-anchor="middle" fill="white" font-size="18" font-weight="bold">Public AZ2</text>
  <text x="495" y="352" text-anchor="middle" fill="white" font-size="16">${MGMT_PUBLIC_AZ2_CIDR}</text>

  <!-- Management Private Subnets -->
  <rect x="90" y="460" width="250" height="85" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="215" y="500" text-anchor="middle" fill="white" font-size="18" font-weight="bold">Private AZ1</text>
  <text x="215" y="528" text-anchor="middle" fill="white" font-size="16">${MGMT_PRIVATE_AZ1_CIDR}</text>

  <rect x="370" y="460" width="250" height="85" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="495" y="500" text-anchor="middle" fill="white" font-size="18" font-weight="bold">Private AZ2</text>
  <text x="495" y="528" text-anchor="middle" fill="white" font-size="16">${MGMT_PRIVATE_AZ2_CIDR}</text>

  <!-- Management TGW Connection indicator -->
  <rect x="240" y="570" width="140" height="42" rx="3" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="310" y="598" text-anchor="middle" fill="white" font-size="16">TGW Attach</text>

  <!-- ==================== INSPECTION VPC ==================== -->
  <!-- Layout: FortiGate ASG (left) | Public, GWLBE, Private (middle) | NAT GW (right) | TGW Attach (bottom) -->
  <rect x="720" y="190" width="1420" height="600" rx="10" fill="none" stroke="#3B48CC" stroke-width="3"/>
  <text x="750" y="230" fill="white" font-size="24" font-weight="bold">Inspection VPC</text>
  <text x="750" y="260" fill="#888" font-size="17">${INSPECTION_VPC_ID} | ${VPC_CIDR_INSPECTION}</text>

  <!-- FortiGate ASG Box - LEFT SIDE -->
  <rect x="760" y="290" width="250" height="330" rx="5" fill="none" stroke="#EE3124" stroke-width="2" stroke-dasharray="5,5"/>
  <text x="885" y="330" text-anchor="middle" fill="#EE3124" font-size="22" font-weight="bold">FortiGate ASG</text>
  <text x="885" y="362" text-anchor="middle" fill="${FGT_SVG_STATUS_COLOR}" font-size="17">${FGT_SVG_STATUS}</text>
  <text x="885" y="394" text-anchor="middle" fill="#888" font-size="16">Mode: ${DEPLOY_MODE}</text>
  <!-- Port labels -->
  <text x="885" y="438" text-anchor="middle" fill="#2E8B2E" font-size="16">port1: Public</text>
  <text x="885" y="465" text-anchor="middle" fill="#ED7100" font-size="16">port2: GWLBE</text>
  <text x="885" y="492" text-anchor="middle" fill="#147EBA" font-size="16">port3: Mgmt VPC</text>
  <!-- GWLB indicator -->
  <rect x="800" y="520" width="170" height="42" rx="3" fill="#ED7100" opacity="0.8"/>
  <text x="885" y="548" text-anchor="middle" fill="white" font-size="16">GWLB</text>

  <!-- Public Subnets - Middle Column Row 1 -->
  <rect x="1050" y="290" width="210" height="100" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="1155" y="325" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ1</text>
  <text x="1155" y="352" text-anchor="middle" fill="white" font-size="15">${INSP_PUBLIC_AZ1_CIDR}</text>
  <text x="1155" y="378" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> NAT GW</text>

  <rect x="1280" y="290" width="210" height="100" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="1385" y="325" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ2</text>
  <text x="1385" y="352" text-anchor="middle" fill="white" font-size="15">${INSP_PUBLIC_AZ2_CIDR}</text>
  <text x="1385" y="378" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> NAT GW</text>

  <!-- GWLBE Subnets - Middle Column Row 2 -->
  <rect x="1050" y="408" width="210" height="100" rx="5" fill="url(#orangeGradient)" opacity="0.8"/>
  <text x="1155" y="438" text-anchor="middle" fill="white" font-size="17" font-weight="bold">GWLBE AZ1</text>
  <text x="1155" y="465" text-anchor="middle" fill="white" font-size="15">${INSP_GWLBE_AZ1_CIDR}</text>
  <text x="1155" y="492" text-anchor="middle" fill="#FFE4B5" font-size="13">${GWLBE_AZ1_ID:-not deployed}</text>

  <rect x="1280" y="408" width="210" height="100" rx="5" fill="url(#orangeGradient)" opacity="0.8"/>
  <text x="1385" y="438" text-anchor="middle" fill="white" font-size="17" font-weight="bold">GWLBE AZ2</text>
  <text x="1385" y="465" text-anchor="middle" fill="white" font-size="15">${INSP_GWLBE_AZ2_CIDR}</text>
  <text x="1385" y="492" text-anchor="middle" fill="#FFE4B5" font-size="13">${GWLBE_AZ2_ID:-not deployed}</text>

  <!-- Private Subnets - Middle Column Row 3 -->
  <rect x="1050" y="526" width="210" height="100" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="1155" y="558" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Private AZ1</text>
  <text x="1155" y="585" text-anchor="middle" fill="white" font-size="15">${INSP_PRIVATE_AZ1_CIDR}</text>
  <text x="1155" y="612" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> GWLBE</text>

  <rect x="1280" y="526" width="210" height="100" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="1385" y="558" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Private AZ2</text>
  <text x="1385" y="585" text-anchor="middle" fill="white" font-size="15">${INSP_PRIVATE_AZ2_CIDR}</text>
  <text x="1385" y="612" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> GWLBE</text>

  <!-- NAT GW Subnets - RIGHT SIDE -->
  <rect x="1540" y="290" width="210" height="100" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="1645" y="325" text-anchor="middle" fill="white" font-size="17" font-weight="bold">NAT GW AZ1</text>
  <text x="1645" y="352" text-anchor="middle" fill="white" font-size="15">${INSP_NATGW_AZ1_CIDR}</text>
  <text x="1645" y="378" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> IGW</text>

  <rect x="1770" y="290" width="210" height="100" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="1875" y="325" text-anchor="middle" fill="white" font-size="17" font-weight="bold">NAT GW AZ2</text>
  <text x="1875" y="352" text-anchor="middle" fill="white" font-size="15">${INSP_NATGW_AZ2_CIDR}</text>
  <text x="1875" y="378" text-anchor="middle" fill="#FF9900" font-size="14">0.0.0.0/0 -> IGW</text>

  <!-- Inspection VPC TGW Attach indicator -->
  <rect x="1200" y="650" width="140" height="42" rx="3" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="1270" y="678" text-anchor="middle" fill="white" font-size="16">TGW Attach</text>

  <!-- ENI Connection Lines from FortiGate ASG (dotted) -->
  <!-- port1 to Public subnets (green) -->
  <line x1="1010" y1="438" x2="1050" y2="340" stroke="#2E8B2E" stroke-width="2" stroke-dasharray="4,3"/>
  <!-- port2 to GWLBE subnets (orange) -->
  <line x1="1010" y1="465" x2="1050" y2="458" stroke="#ED7100" stroke-width="2" stroke-dasharray="4,3"/>
  <!-- port3 to Management VPC (blue) - goes left -->
  <path d="M 760 492 L 700 492 L 700 400 L 660 400" stroke="#147EBA" stroke-width="2" stroke-dasharray="4,3" fill="none"/>

  <!-- ==================== TRANSIT GATEWAY ==================== -->
  <rect x="60" y="840" width="2080" height="100" rx="10" fill="url(#purpleGradient)" opacity="0.9"/>
  <text x="1100" y="885" text-anchor="middle" fill="white" font-size="26" font-weight="bold">Transit Gateway: ${PREFIX}-tgw</text>
  <text x="1100" y="918" text-anchor="middle" fill="white" font-size="18">${TGW_ID}</text>

  <!-- TGW Connection Lines -->
  <line x1="310" y1="612" x2="310" y2="840" stroke="#8C4FFF" stroke-width="2"/>
  <line x1="1270" y1="692" x2="1270" y2="840" stroke="#8C4FFF" stroke-width="2"/>

  <!-- ==================== EAST SPOKE VPC ==================== -->
  <rect x="620" y="990" width="500" height="370" rx="10" fill="none" stroke="#3B48CC" stroke-width="3"/>
  <text x="645" y="1030" fill="white" font-size="22" font-weight="bold">East Spoke VPC</text>
  <text x="645" y="1060" fill="#888" font-size="16">${EAST_VPC_ID} | ${VPC_CIDR_EAST}</text>

  <!-- East Public Subnets -->
  <rect x="650" y="1085" width="220" height="120" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="760" y="1118" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ1</text>
  <text x="760" y="1145" text-anchor="middle" fill="white" font-size="15">${EAST_PUBLIC_AZ1_CIDR}</text>
  <rect x="675" y="1160" width="170" height="38" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="760" y="1185" text-anchor="middle" fill="white" font-size="15">${EAST_AZ1_PRIVATE}</text>

  <rect x="890" y="1085" width="220" height="120" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="1000" y="1118" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ2</text>
  <text x="1000" y="1145" text-anchor="middle" fill="white" font-size="15">${EAST_PUBLIC_AZ2_CIDR}</text>
  <rect x="915" y="1160" width="170" height="38" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="1000" y="1185" text-anchor="middle" fill="white" font-size="15">${EAST_AZ2_PRIVATE}</text>

  <!-- East TGW Subnets -->
  <rect x="650" y="1220" width="220" height="80" rx="5" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="760" y="1255" text-anchor="middle" fill="white" font-size="17" font-weight="bold">TGW AZ1</text>
  <text x="760" y="1282" text-anchor="middle" fill="white" font-size="15">${EAST_TGW_AZ1_CIDR}</text>

  <rect x="890" y="1220" width="220" height="80" rx="5" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="1000" y="1255" text-anchor="middle" fill="white" font-size="17" font-weight="bold">TGW AZ2</text>
  <text x="1000" y="1282" text-anchor="middle" fill="white" font-size="15">${EAST_TGW_AZ2_CIDR}</text>

  <!-- East TGW Connection -->
  <line x1="870" y1="940" x2="870" y2="990" stroke="#8C4FFF" stroke-width="2"/>

  <!-- East Route Status -->
  <rect x="650" y="1310" width="460" height="40" rx="3" fill="#00FF00" opacity="0.3"/>
  <text x="880" y="1337" text-anchor="middle" fill="#FF6666" font-size="15">Route: 0.0.0.0/0 -> TGW | TGW RT: ${EAST_TGW_DEFAULT_ROUTE}</text>

  <!-- ==================== WEST SPOKE VPC ==================== -->
  <rect x="1160" y="990" width="500" height="370" rx="10" fill="none" stroke="#3B48CC" stroke-width="3"/>
  <text x="1185" y="1030" fill="white" font-size="22" font-weight="bold">West Spoke VPC</text>
  <text x="1185" y="1060" fill="#888" font-size="16">${WEST_VPC_ID} | ${VPC_CIDR_WEST}</text>

  <!-- West Public Subnets -->
  <rect x="1190" y="1085" width="220" height="120" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="1300" y="1118" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ1</text>
  <text x="1300" y="1145" text-anchor="middle" fill="white" font-size="15">${WEST_PUBLIC_AZ1_CIDR}</text>
  <rect x="1215" y="1160" width="170" height="38" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="1300" y="1185" text-anchor="middle" fill="white" font-size="15">${WEST_AZ1_PRIVATE}</text>

  <rect x="1430" y="1085" width="220" height="120" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="1540" y="1118" text-anchor="middle" fill="white" font-size="17" font-weight="bold">Public AZ2</text>
  <text x="1540" y="1145" text-anchor="middle" fill="white" font-size="15">${WEST_PUBLIC_AZ2_CIDR}</text>
  <rect x="1455" y="1160" width="170" height="38" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="1540" y="1185" text-anchor="middle" fill="white" font-size="15">${WEST_AZ2_PRIVATE}</text>

  <!-- West TGW Subnets -->
  <rect x="1190" y="1220" width="220" height="80" rx="5" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="1300" y="1255" text-anchor="middle" fill="white" font-size="17" font-weight="bold">TGW AZ1</text>
  <text x="1300" y="1282" text-anchor="middle" fill="white" font-size="15">${WEST_TGW_AZ1_CIDR}</text>

  <rect x="1430" y="1220" width="220" height="80" rx="5" fill="url(#purpleGradient)" opacity="0.8"/>
  <text x="1540" y="1255" text-anchor="middle" fill="white" font-size="17" font-weight="bold">TGW AZ2</text>
  <text x="1540" y="1282" text-anchor="middle" fill="white" font-size="15">${WEST_TGW_AZ2_CIDR}</text>

  <!-- West TGW Connection -->
  <line x1="1410" y1="940" x2="1410" y2="990" stroke="#8C4FFF" stroke-width="2"/>

  <!-- West Route Status -->
  <rect x="1190" y="1310" width="460" height="40" rx="3" fill="#00FF00" opacity="0.3"/>
  <text x="1420" y="1337" text-anchor="middle" fill="#FF6666" font-size="15">Route: 0.0.0.0/0 -> TGW | TGW RT: ${WEST_TGW_DEFAULT_ROUTE}</text>

SVGEOF

# Add Distributed VPC section if enabled
if [ "$ENABLE_DISTRIBUTED" = "true" ] && [ -n "$DISTRIBUTED_COUNT" ] && [ "$DISTRIBUTED_COUNT" -ge 1 ]; then
cat >> "$SVG_FILE" << DISTEOF

  <!-- ==================== DISTRIBUTED VPC 1 ==================== -->
  <rect x="450" y="890" width="500" height="190" rx="10" fill="none" stroke="#3B48CC" stroke-width="3"/>
  <text x="460" y="915" fill="white" font-size="14" font-weight="bold">Distributed VPC 1</text>
  <text x="460" y="932" fill="#888" font-size="11">${DISTRIBUTED_VPC_1_CIDR} | NOT attached to TGW</text>

  <!-- Distributed IGW -->
  <rect x="880" y="870" width="60" height="25" rx="5" fill="#232F3E" stroke="#FF9900" stroke-width="2"/>
  <text x="910" y="887" text-anchor="middle" fill="#FF9900" font-size="9" font-weight="bold">IGW</text>
  <line x1="910" y1="895" x2="910" y2="910" stroke="#FF9900" stroke-width="2" stroke-dasharray="4,2"/>

  <!-- Distributed Public Subnets -->
  <rect x="470" y="945" width="220" height="55" rx="5" fill="url(#greenGradient)" opacity="0.8"/>
  <text x="580" y="965" text-anchor="middle" fill="white" font-size="10" font-weight="bold">Public Subnets (AZ1, AZ2)</text>
  <text x="580" y="980" text-anchor="middle" fill="white" font-size="9">GWLBE ingress point</text>

  <!-- Distributed GWLBE Subnets -->
  <rect x="710" y="945" width="220" height="55" rx="5" fill="url(#orangeGradient)" opacity="0.8"/>
  <text x="820" y="965" text-anchor="middle" fill="white" font-size="10" font-weight="bold">GWLBE Subnets (AZ1, AZ2)</text>
  <text x="820" y="980" text-anchor="middle" fill="white" font-size="9">Traffic hairpin to FortiGates</text>

  <!-- Distributed Private Subnets with instances -->
  <rect x="470" y="1010" width="460" height="55" rx="5" fill="url(#blueGradient)" opacity="0.8"/>
  <text x="700" y="1028" text-anchor="middle" fill="white" font-size="10" font-weight="bold">Private Subnets (AZ1, AZ2)</text>
  <!-- Instance AZ1 -->
  <rect x="500" y="1035" width="140" height="22" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="570" y="1050" text-anchor="middle" fill="white" font-size="7">${DIST1_AZ1_PRIVATE}</text>
  <text x="570" y="1033" text-anchor="middle" fill="#00FF00" font-size="7">${DIST1_AZ1_PUBLIC}</text>
  <!-- Instance AZ2 -->
  <rect x="760" y="1035" width="140" height="22" rx="3" fill="#232F3E" stroke="#FF9900" stroke-width="1"/>
  <text x="830" y="1050" text-anchor="middle" fill="white" font-size="7">${DIST1_AZ2_PRIVATE}</text>
  <text x="830" y="1033" text-anchor="middle" fill="#00FF00" font-size="7">${DIST1_AZ2_PUBLIC}</text>

DISTEOF
fi

# Add FortiTester section if any FortiTesters are deployed
if [ -n "$FORTITESTER_1_PRIVATE" ] && [ "$FORTITESTER_1_PRIVATE" != "None" ]; then
cat >> "$SVG_FILE" << FTESTER1EOF

  <!-- ==================== FORTITESTER 1 (AZ1) ==================== -->
  <!-- FortiTester 1 spans: Mgmt VPC AZ1 (port1), East AZ1 (port2), West AZ1 (port3) -->
  <rect x="60" y="660" width="600" height="120" rx="5" fill="#232F3E" stroke="#00BFFF" stroke-width="2"/>
  <text x="85" y="690" fill="#00BFFF" font-size="18" font-weight="bold">FortiTester 1 (AZ1)</text>
  <text x="85" y="715" fill="white" font-size="14">Port1 (Mgmt): ${FORTITESTER_1_PRIVATE}</text>
  <text x="85" y="735" fill="#00FF00" font-size="14">Public: ${FORTITESTER_1_PUBLIC:-N/A}</text>
  <text x="280" y="715" fill="white" font-size="14">Port2 (East): ${FORTITESTER_1_PORT2_IP:-N/A}</text>
  <text x="450" y="715" fill="white" font-size="14">Port3 (West): ${FORTITESTER_1_PORT3_IP:-N/A}</text>
  <!-- Connection lines to subnets -->
  <line x1="160" y1="660" x2="160" y2="435" stroke="#00BFFF" stroke-width="1" stroke-dasharray="3,2"/>
  <line x1="330" y1="760" x2="760" y2="1160" stroke="#00BFFF" stroke-width="1" stroke-dasharray="3,2"/>
  <line x1="500" y1="760" x2="1300" y2="1160" stroke="#00BFFF" stroke-width="1" stroke-dasharray="3,2"/>
FTESTER1EOF
fi

if [ -n "$FORTITESTER_2_PRIVATE" ] && [ "$FORTITESTER_2_PRIVATE" != "None" ]; then
cat >> "$SVG_FILE" << FTESTER2EOF

  <!-- ==================== FORTITESTER 2 (AZ2) ==================== -->
  <!-- FortiTester 2 spans: Mgmt VPC AZ2 (port1), West AZ2 (port2), East AZ2 (port3) -->
  <rect x="60" y="795" width="600" height="120" rx="5" fill="#232F3E" stroke="#00BFFF" stroke-width="2"/>
  <text x="85" y="825" fill="#00BFFF" font-size="18" font-weight="bold">FortiTester 2 (AZ2)</text>
  <text x="85" y="850" fill="white" font-size="14">Port1 (Mgmt): ${FORTITESTER_2_PRIVATE}</text>
  <text x="85" y="870" fill="#00FF00" font-size="14">Public: ${FORTITESTER_2_PUBLIC:-N/A}</text>
  <text x="280" y="850" fill="white" font-size="14">Port2 (West): ${FORTITESTER_2_PORT2_IP:-N/A}</text>
  <text x="450" y="850" fill="white" font-size="14">Port3 (East): ${FORTITESTER_2_PORT3_IP:-N/A}</text>
FTESTER2EOF
fi

# Add legend
cat >> "$SVG_FILE" << LEGENDEOF

  <!-- ==================== LEGEND ==================== -->
  <rect x="60" y="990" width="530" height="370" rx="5" fill="#232F3E" opacity="0.9"/>
  <text x="85" y="1030" fill="white" font-size="22" font-weight="bold">Legend</text>

  <!-- Subnet Types -->
  <rect x="85" y="1065" width="32" height="24" fill="url(#greenGradient)"/>
  <text x="130" y="1085" fill="white" font-size="17">Public Subnet</text>

  <rect x="85" y="1105" width="32" height="24" fill="url(#blueGradient)"/>
  <text x="130" y="1125" fill="white" font-size="17">Private/NAT GW Subnet</text>

  <rect x="85" y="1145" width="32" height="24" fill="url(#purpleGradient)"/>
  <text x="130" y="1165" fill="white" font-size="17">TGW Subnet</text>

  <rect x="85" y="1185" width="32" height="24" fill="url(#orangeGradient)"/>
  <text x="130" y="1205" fill="white" font-size="17">GWLB/GWLBE Subnet</text>

  <rect x="85" y="1225" width="32" height="24" fill="none" stroke="#EE3124" stroke-width="1" stroke-dasharray="3,2"/>
  <text x="130" y="1245" fill="white" font-size="17">${FGT_LEGEND_TEXT}</text>

  <rect x="85" y="1265" width="32" height="24" fill="#232F3E" stroke="#00BFFF" stroke-width="1"/>
  <text x="130" y="1285" fill="white" font-size="17">FortiTester</text>

  <!-- ENI Connection Legend -->
  <text x="340" y="1085" fill="white" font-size="17" font-weight="bold">ENI Connections:</text>
  <line x1="340" y1="1112" x2="395" y2="1112" stroke="#2E8B2E" stroke-width="2" stroke-dasharray="4,3"/>
  <text x="408" y="1118" fill="#2E8B2E" font-size="16">port1 (Public)</text>
  <line x1="340" y1="1145" x2="395" y2="1145" stroke="#ED7100" stroke-width="2" stroke-dasharray="4,3"/>
  <text x="408" y="1151" fill="#ED7100" font-size="16">port2 (GWLBE)</text>
  <line x1="340" y1="1178" x2="395" y2="1178" stroke="#147EBA" stroke-width="2" stroke-dasharray="4,3"/>
  <text x="408" y="1184" fill="#147EBA" font-size="16">port3 (Mgmt VPC)</text>

  <!-- IP Legend -->
  <text x="85" y="1285" fill="white" font-size="17" font-weight="bold">IP Addresses:</text>
  <text x="85" y="1312" fill="white" font-size="17">Private IP (white)</text>
  <text x="85" y="1339" fill="#00FF00" font-size="17">Public IP (green)</text>

  <!-- Status -->
  <text x="340" y="1220" fill="white" font-size="17" font-weight="bold">Deployment:</text>
  <text x="340" y="1247" fill="#00FF00" font-size="16">East/West TGW: Attached</text>
  <text x="340" y="1274" fill="${FGT_DEPLOY_STATUS_COLOR}" font-size="16">${FGT_DEPLOY_STATUS}</text>

  <!-- Instance Summary -->
  <text x="340" y="1312" fill="white" font-size="17" font-weight="bold">Public IPs:</text>
  <text x="340" y="1339" fill="#00FF00" font-size="16">Jump Box: ${JUMP_BOX_PUBLIC}</text>

</svg>
LEGENDEOF

print_pass "SVG diagram created: $SVG_FILE"

# Generate Markdown file
print_info "Generating Markdown documentation..."

# Determine FortiGate deployment status for markdown
if [ "$FORTIGATE_COUNT" -gt 0 ]; then
    FGT_STATUS_TEXT="The FortiGate AutoScale Group is deployed with ${FORTIGATE_COUNT} instance(s) running."
else
    FGT_STATUS_TEXT="The FortiGate AutoScale Group has not yet been deployed."
fi

cat > "$MD_FILE" << MDEOF
# Network Diagram - ${PREFIX} Infrastructure

**Generated:** ${TIMESTAMP}
**Template:** \`existing_vpc_resources\`
**Region:** ${AWS_REGION} (AZs: ${AZ1}, ${AZ2})

---

## Infrastructure Overview

This diagram shows the current state of the \`${PREFIX}\` infrastructure deployed using the \`existing_vpc_resources\` template. ${FGT_STATUS_TEXT}

![Network Diagram](network_diagram.svg)

---

## Resource Summary

### VPCs

| VPC | CIDR | VPC ID | Status |
|-----|------|--------|--------|
| Management VPC | ${VPC_CIDR_MANAGEMENT} | ${MGMT_VPC_ID} | Deployed |
| Inspection VPC | ${VPC_CIDR_INSPECTION} | ${INSPECTION_VPC_ID} | Deployed |
| East Spoke VPC | ${VPC_CIDR_EAST} | ${EAST_VPC_ID} | Deployed |
| West Spoke VPC | ${VPC_CIDR_WEST} | ${WEST_VPC_ID} | Deployed |
MDEOF

if [ "$ENABLE_DISTRIBUTED" = "true" ]; then
cat >> "$MD_FILE" << DISTMDEOF
| Distributed VPC 1 | ${DISTRIBUTED_VPC_1_CIDR} | - | Deployed |
DISTMDEOF
fi

cat >> "$MD_FILE" << MDEOF2

### Transit Gateway

| Resource | ID | Name |
|----------|-----|------|
| Transit Gateway | ${TGW_ID} | ${PREFIX}-tgw |

### Instances with Public IPs

| Instance Name | Instance ID | Private IP | Public IP |
|--------------|-------------|------------|-----------|
| ${JUMP_BOX_NAME} | ${JUMP_BOX_ID} | ${JUMP_BOX_PRIVATE} | ${JUMP_BOX_PUBLIC} |
MDEOF2

if [ "$ENABLE_DISTRIBUTED" = "true" ] && [ -n "$DIST1_AZ1_PUBLIC" ]; then
cat >> "$MD_FILE" << DISTINSTEOF
| ${DIST1_AZ1_NAME} | ${DIST1_AZ1_ID} | ${DIST1_AZ1_PRIVATE} | ${DIST1_AZ1_PUBLIC} |
| ${DIST1_AZ2_NAME} | ${DIST1_AZ2_ID} | ${DIST1_AZ2_PRIVATE} | ${DIST1_AZ2_PUBLIC} |
DISTINSTEOF
fi

# Add FortiTester instances to public IP table
if [ -n "$FORTITESTER_1_PUBLIC" ] && [ "$FORTITESTER_1_PUBLIC" != "None" ]; then
cat >> "$MD_FILE" << FT1INSTEOF
| ${FORTITESTER_1_NAME} | ${FORTITESTER_1_ID} | ${FORTITESTER_1_PRIVATE} | ${FORTITESTER_1_PUBLIC} |
FT1INSTEOF
fi

if [ -n "$FORTITESTER_2_PUBLIC" ] && [ "$FORTITESTER_2_PUBLIC" != "None" ]; then
cat >> "$MD_FILE" << FT2INSTEOF
| ${FORTITESTER_2_NAME} | ${FORTITESTER_2_ID} | ${FORTITESTER_2_PRIVATE} | ${FORTITESTER_2_PUBLIC} |
FT2INSTEOF
fi

# Add FortiGate ASG instances section if any were found
if [ "$FORTIGATE_COUNT" -gt 0 ]; then
cat >> "$MD_FILE" << FGTMDEOF

### FortiGate AutoScale Group Instances

| Instance Name | Instance ID | Role | Private IP | Public IP (Management) |
|--------------|-------------|------|------------|------------------------|
${FORTIGATE_MD_TABLE}
> **Note:** FortiGate management interfaces are accessible via their public IPs. Use \`admin\` as username with the configured password. The **Primary** instance holds the configuration that is synced to Secondary instances.
FGTMDEOF
else
cat >> "$MD_FILE" << NOFGTEOF

### FortiGate AutoScale Group Instances

*No FortiGate ASG instances deployed yet. Deploy the \`autoscale_template\` to create the FortiGate Auto Scaling Group.*
NOFGTEOF
fi

# Add FortiManager section if integration is enabled
if [ "$ENABLE_FMG_INTEGRATION" == "true" ] && [ -n "$FORTIMANAGER_IP" ]; then
cat >> "$MD_FILE" << FMGEOF

### FortiManager Integration

| Setting | Value |
|---------|-------|
| Integration Enabled | Yes |
| FortiManager IP | ${FORTIMANAGER_IP} |
| FortiManager Serial | ${FORTIMANAGER_SN:-N/A} |

> **Note:** FortiGates in the AutoScale Group are configured to register with this FortiManager. Access FortiManager at \`https://${FORTIMANAGER_IP}\`
FMGEOF
fi

# Add FortiTester detailed section
if [ -n "$FORTITESTER_1_PRIVATE" ] && [ "$FORTITESTER_1_PRIVATE" != "None" ] || [ -n "$FORTITESTER_2_PRIVATE" ] && [ "$FORTITESTER_2_PRIVATE" != "None" ]; then
cat >> "$MD_FILE" << FTESTERMDEOF

### FortiTester Instances

FortiTesters are deployed with 3 network interfaces each for traffic generation testing across VPCs.

| FortiTester | Instance ID | Port1 (Mgmt VPC) | Port2 | Port3 | Public IP |
|-------------|-------------|------------------|-------|-------|-----------|
FTESTERMDEOF

if [ -n "$FORTITESTER_1_PRIVATE" ] && [ "$FORTITESTER_1_PRIVATE" != "None" ]; then
cat >> "$MD_FILE" << FT1DETAILEOF
| FortiTester 1 (AZ1) | ${FORTITESTER_1_ID:-N/A} | ${FORTITESTER_1_PRIVATE} | East: ${FORTITESTER_1_PORT2_IP:-N/A} | West: ${FORTITESTER_1_PORT3_IP:-N/A} | ${FORTITESTER_1_PUBLIC:-N/A} |
FT1DETAILEOF
fi

if [ -n "$FORTITESTER_2_PRIVATE" ] && [ "$FORTITESTER_2_PRIVATE" != "None" ]; then
cat >> "$MD_FILE" << FT2DETAILEOF
| FortiTester 2 (AZ2) | ${FORTITESTER_2_ID:-N/A} | ${FORTITESTER_2_PRIVATE} | West: ${FORTITESTER_2_PORT2_IP:-N/A} | East: ${FORTITESTER_2_PORT3_IP:-N/A} | ${FORTITESTER_2_PUBLIC:-N/A} |
FT2DETAILEOF
fi

cat >> "$MD_FILE" << FTESTERNOTEEOF

> **Note:** FortiTesters span multiple VPCs for traffic generation testing:
> - **FortiTester 1**: Port1 in Management VPC AZ1, Port2 in East VPC AZ1, Port3 in West VPC AZ1
> - **FortiTester 2**: Port1 in Management VPC AZ2, Port2 in West VPC AZ2, Port3 in East VPC AZ2
>
> Access FortiTesters via HTTPS at their public IPs. Default credentials: **admin** / **Instance ID** (e.g., i-0abc123def456...)
FTESTERNOTEEOF
fi

cat >> "$MD_FILE" << MDEOF3

### Spoke VPC Instances (No Public IPs)

| Instance Name | Private IP |
|--------------|------------|
| ${EAST_AZ1_NAME} | ${EAST_AZ1_PRIVATE} |
| ${EAST_AZ2_NAME} | ${EAST_AZ2_PRIVATE} |
| ${WEST_AZ1_NAME} | ${WEST_AZ1_PRIVATE} |
| ${WEST_AZ2_NAME} | ${WEST_AZ2_PRIVATE} |

---

## Routing Status

### Default Route (0.0.0.0/0) Summary

| Route Table | Target | Status |
|-------------|--------|--------|
| Management VPC Public | IGW | OK |
| Inspection VPC NAT GW AZ1 | IGW | OK |
| Inspection VPC NAT GW AZ2 | IGW | OK |
| East VPC Public | TGW | OK |
| West VPC Public | TGW | OK |
| East TGW Attachment RT | **${EAST_TGW_DEFAULT_ROUTE}** | ${ROUTE_STATUS_TEXT} |
| West TGW Attachment RT | **${WEST_TGW_DEFAULT_ROUTE}** | ${ROUTE_STATUS_TEXT} |
| Management TGW Attachment RT | No default route | Expected |

### Notes

- East and West spoke VPCs route 0.0.0.0/0 to TGW at the VPC level
- TGW route tables for East/West do **not** have default routes yet
- Default routes will be added to TGW route tables after \`autoscale_template\` deployment
- This routes spoke traffic through the FortiGate inspection VPC

---

## Next Steps

1. Deploy \`autoscale_template\` to create FortiGate Auto Scaling Group
2. ASG deployment will automatically:
   - Create GWLB and endpoints
   - Update TGW route tables with default routes pointing to Inspection VPC
   - Enable traffic inspection for East/West spoke VPCs

---

*Source: Generated by verify_all.sh*
MDEOF3

print_pass "Markdown documentation created: $MD_FILE"

echo ""
print_info "Network diagram files generated:"
echo "  - SVG: $SVG_FILE"
echo "  - MD:  $MD_FILE"
echo ""
