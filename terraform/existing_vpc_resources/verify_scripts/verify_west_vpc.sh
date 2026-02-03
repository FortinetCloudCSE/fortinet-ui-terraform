#!/bin/bash

# Verify West VPC Resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Get the terraform directory (parent of verify_scripts)
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

print_section "WEST VPC VERIFICATION"

# Read tfvars
read_tfvars "$TFVARS_FILE"

# Check if existing subnets are enabled
if ! is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
    print_skip "West VPC is not enabled (enable_build_existing_subnets = false)"
    print_summary
    exit 0
fi

# Get basic configuration
AWS_REGION=$(get_tfvar "aws_region" "$TFVARS_FILE")
AZ1=$(get_tfvar "availability_zone_1" "$TFVARS_FILE")
AZ2=$(get_tfvar "availability_zone_2" "$TFVARS_FILE")
CP=$(get_tfvar "cp" "$TFVARS_FILE")
ENV=$(get_tfvar "env" "$TFVARS_FILE")

# Full AZ names
FULL_AZ1="${AWS_REGION}${AZ1}"
FULL_AZ2="${AWS_REGION}${AZ2}"

print_info "Region: $AWS_REGION"
print_info "Availability Zones: $FULL_AZ1, $FULL_AZ2"
print_info "Prefix: ${CP}-${ENV}"

VPC_CIDR_WEST=$(get_tfvar "vpc_cidr_west" "$TFVARS_FILE")
VPC_NAME="${CP}-${ENV}-west-vpc"

print_info "Expected West VPC CIDR: $VPC_CIDR_WEST"

# 1. Verify VPC exists
print_info "Checking if West VPC exists..."
VPC_ID=$(verify_vpc_exists "$VPC_NAME" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "West VPC exists: $VPC_ID"
else
    print_fail "West VPC does not exist: $VPC_NAME"
    print_summary
    exit 1
fi

# 2. Verify VPC CIDR
print_info "Verifying VPC CIDR..."
if verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_WEST" "$AWS_REGION"; then
    print_pass "VPC CIDR matches: $VPC_CIDR_WEST"
else
    result=$(verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_WEST" "$AWS_REGION")
    print_fail "VPC CIDR mismatch: $result"
fi

# 3. Verify subnets exist
print_info "Verifying subnets..."

# Public subnets
for AZ_NUM in 1 2; do
    if [ $AZ_NUM -eq 1 ]; then
        FULL_AZ="$FULL_AZ1"
    else
        FULL_AZ="$FULL_AZ2"
    fi

    PUBLIC_SUBNET_NAME="${CP}-${ENV}-west-public-az${AZ_NUM}-subnet"
    SUBNET_ID=$(verify_subnet_exists "$PUBLIC_SUBNET_NAME" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "Public subnet AZ${AZ_NUM} exists: $SUBNET_ID"
        if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
            print_pass "Public subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
        else
            print_fail "Public subnet AZ${AZ_NUM} AZ mismatch"
        fi
    else
        print_fail "Public subnet AZ${AZ_NUM} does not exist: $PUBLIC_SUBNET_NAME"
    fi
done

# TGW subnets
for AZ_NUM in 1 2; do
    if [ $AZ_NUM -eq 1 ]; then
        FULL_AZ="$FULL_AZ1"
    else
        FULL_AZ="$FULL_AZ2"
    fi

    TGW_SUBNET_NAME="${CP}-${ENV}-west-tgw-az${AZ_NUM}-subnet"
    SUBNET_ID=$(verify_subnet_exists "$TGW_SUBNET_NAME" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "TGW subnet AZ${AZ_NUM} exists: $SUBNET_ID"
        if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
            print_pass "TGW subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
        else
            print_fail "TGW subnet AZ${AZ_NUM} AZ mismatch"
        fi
    else
        print_fail "TGW subnet AZ${AZ_NUM} does not exist: $TGW_SUBNET_NAME"
    fi
done

# 4. Verify main route table
print_info "Verifying main route table..."

MAIN_RT_ID=$(aws ec2 describe-route-tables \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${CP}-${ENV}-west-vpc-main-route-table" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null)

if [ "$MAIN_RT_ID" != "None" ] && [ -n "$MAIN_RT_ID" ]; then
    print_pass "Main route table exists: $MAIN_RT_ID"

    # Verify local route
    if verify_route_exists "$MAIN_RT_ID" "$VPC_CIDR_WEST" "$AWS_REGION"; then
        print_pass "Local route to VPC CIDR exists: $VPC_CIDR_WEST"
    else
        print_fail "Local route to VPC CIDR not found: $VPC_CIDR_WEST"
    fi

    # Verify default route to TGW
    if verify_route_exists "$MAIN_RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
        TARGET=$(get_route_target "$MAIN_RT_ID" "0.0.0.0/0" "$AWS_REGION")
        if [[ "$TARGET" == tgw-* ]]; then
            print_pass "Default route (0.0.0.0/0) points to Transit Gateway: $TARGET"
        else
            print_fail "Default route exists but does not point to TGW: $TARGET"
        fi
    else
        print_fail "Default route (0.0.0.0/0) not found in main route table"
    fi

    # If management VPC is enabled, check for management route
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
        VPC_CIDR_MANAGEMENT=$(get_tfvar "vpc_cidr_management" "$TFVARS_FILE")
        if verify_route_exists "$MAIN_RT_ID" "$VPC_CIDR_MANAGEMENT" "$AWS_REGION"; then
            TARGET=$(get_route_target "$MAIN_RT_ID" "$VPC_CIDR_MANAGEMENT" "$AWS_REGION")
            if [[ "$TARGET" == tgw-* ]]; then
                print_pass "Route to management VPC ($VPC_CIDR_MANAGEMENT) points to TGW: $TARGET"
            else
                print_fail "Route to management VPC exists but not to TGW: $TARGET"
            fi
        else
            print_fail "Route to management VPC CIDR not found: $VPC_CIDR_MANAGEMENT"
        fi
    else
        print_skip "Management VPC route check skipped (enable_build_management_vpc = false)"
    fi
else
    print_fail "Main route table not found"
fi

# 5. Verify TGW attachment
print_info "Verifying TGW attachment..."

TGW_NAME=$(get_tfvar "attach_to_tgw_name" "$TFVARS_FILE")
TGW_ID=$(get_tgw_id_by_name "$TGW_NAME" "$AWS_REGION")

if [ $? -eq 0 ]; then
    print_pass "Transit Gateway exists: $TGW_ID"

    # Check for attachment
    ATTACHMENT_ID=$(verify_tgw_attachment "$VPC_ID" "$TGW_ID" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "TGW attachment exists: $ATTACHMENT_ID"

        # Verify appliance mode support
        APPLIANCE_MODE=$(aws ec2 describe-transit-gateway-vpc-attachments \
            --region "$AWS_REGION" \
            --transit-gateway-attachment-ids "$ATTACHMENT_ID" \
            --query 'TransitGatewayVpcAttachments[0].Options.ApplianceModeSupport' \
            --output text 2>/dev/null)

        if [ "$APPLIANCE_MODE" == "enable" ]; then
            print_pass "Appliance mode support is enabled"
        else
            print_fail "Appliance mode support is not enabled: $APPLIANCE_MODE"
        fi
    else
        print_fail "TGW attachment not found for west VPC"
    fi
else
    print_fail "Transit Gateway not found: $TGW_NAME"
fi

# 6. Verify TGW route table for West VPC
print_info "Verifying TGW route table for West VPC..."

TGW_RT_NAME="${CP}-${ENV}-west-tgw-rtb"
TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${TGW_RT_NAME}" \
    --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
    --output text 2>/dev/null)

if [ "$TGW_RT_ID" != "None" ] && [ -n "$TGW_RT_ID" ]; then
    print_pass "TGW route table exists: $TGW_RT_ID ($TGW_RT_NAME)"

    # Verify route table is associated with west attachment
    ASSOCIATED=$(aws ec2 get-transit-gateway-route-table-associations \
        --region "$AWS_REGION" \
        --transit-gateway-route-table-id "$TGW_RT_ID" \
        --filters "Name=transit-gateway-attachment-id,Values=${ATTACHMENT_ID}" \
        --query 'Associations[0].State' \
        --output text 2>/dev/null)

    if [ "$ASSOCIATED" == "associated" ]; then
        print_pass "TGW route table is associated with West VPC attachment"
    else
        print_fail "TGW route table is not associated with West VPC attachment: $ASSOCIATED"
    fi

    # Verify default route in TGW route table
    # Note: Default route can point to EITHER Management VPC (before autoscale deployment)
    # OR Inspection VPC (after autoscale deployment). Both are valid states.
    print_info "Verifying default route in TGW route table..."

    # Get default route target
    DEFAULT_ROUTE_TARGET=$(aws ec2 search-transit-gateway-routes \
        --region "$AWS_REGION" \
        --transit-gateway-route-table-id "$TGW_RT_ID" \
        --filters "Name=type,Values=static" \
        --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
        --output text 2>/dev/null)

    # Get Management VPC attachment ID
    MGMT_VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${CP}-${ENV}-management-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)

    MGMT_ATTACHMENT=$(aws ec2 describe-transit-gateway-attachments \
        --region "$AWS_REGION" \
        --filters "Name=resource-type,Values=vpc" "Name=resource-id,Values=${MGMT_VPC_ID}" \
        --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' \
        --output text 2>/dev/null)

    # Get Inspection VPC attachment ID
    INSP_VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${CP}-${ENV}-inspection-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)

    INSP_ATTACHMENT=$(aws ec2 describe-transit-gateway-attachments \
        --region "$AWS_REGION" \
        --filters "Name=resource-type,Values=vpc" "Name=resource-id,Values=${INSP_VPC_ID}" \
        --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' \
        --output text 2>/dev/null)

    if [ -z "$DEFAULT_ROUTE_TARGET" ] || [ "$DEFAULT_ROUTE_TARGET" == "None" ]; then
        print_fail "Default route (0.0.0.0/0) not found in TGW route table"
    elif [ "$DEFAULT_ROUTE_TARGET" == "$MGMT_ATTACHMENT" ]; then
        print_pass "Default route points to Management VPC: $DEFAULT_ROUTE_TARGET (pre-autoscale state - spoke instances NAT through jump box)"
    elif [ "$DEFAULT_ROUTE_TARGET" == "$INSP_ATTACHMENT" ]; then
        print_pass "Default route points to Inspection VPC: $DEFAULT_ROUTE_TARGET (post-autoscale state - traffic inspected by FortiGates)"
    else
        print_fail "Default route points to unknown attachment: $DEFAULT_ROUTE_TARGET (expected Management: $MGMT_ATTACHMENT or Inspection: $INSP_ATTACHMENT)"
    fi
else
    print_fail "TGW route table not found: $TGW_RT_NAME"
fi

# 7. Verify EC2 instances if enabled
if is_tfvar_true "enable_linux_spoke_instances" "$TFVARS_FILE"; then
    print_info "Verifying EC2 instances..."

    LINUX_HOST_IP=$(get_tfvar "linux_host_ip" "$TFVARS_FILE")
    ACL=$(get_tfvar "acl" "$TFVARS_FILE")

    for AZ_NUM in 1 2; do
        INSTANCE_NAME="${CP}-${ENV}-west-public-az${AZ_NUM}-instance"
        INSTANCE_ID=$(verify_ec2_instance "$INSTANCE_NAME" "$AWS_REGION")

        if [ $? -eq 0 ]; then
            print_pass "EC2 instance AZ${AZ_NUM} exists: $INSTANCE_ID"

            # Verify private IP
            ACTUAL_PRIVATE_IP=$(get_instance_private_ip "$INSTANCE_ID" "$AWS_REGION")

            # Get the subnet CIDR to calculate expected IP
            if [ $AZ_NUM -eq 1 ]; then
                SUBNET_NAME="${CP}-${ENV}-west-public-az1-subnet"
            else
                SUBNET_NAME="${CP}-${ENV}-west-public-az2-subnet"
            fi

            SUBNET_CIDR=$(aws ec2 describe-subnets \
                --region "$AWS_REGION" \
                --filters "Name=tag:Name,Values=${SUBNET_NAME}" \
                --query 'Subnets[0].CidrBlock' \
                --output text 2>/dev/null)

            if [ -n "$SUBNET_CIDR" ] && [ "$SUBNET_CIDR" != "None" ]; then
                RESULT=$(verify_instance_ip_in_subnet "$ACTUAL_PRIVATE_IP" "$SUBNET_CIDR" "$LINUX_HOST_IP")
                EXIT_CODE=$?
                if [ $EXIT_CODE -eq 0 ]; then
                    print_pass "Instance AZ${AZ_NUM} private IP matches expected: $ACTUAL_PRIVATE_IP (host #$LINUX_HOST_IP in $SUBNET_CIDR)"
                else
                    print_fail "Instance AZ${AZ_NUM} private IP mismatch: $RESULT"
                fi
            else
                print_info "Instance AZ${AZ_NUM} private IP: $ACTUAL_PRIVATE_IP (subnet CIDR not found, skipping validation)"
            fi

            # Verify NO public IP (West VPC has no IGW, only TGW connectivity)
            ACTUAL_PUBLIC_IP=$(get_instance_public_ip "$INSTANCE_ID" "$AWS_REGION")
            if [ "$ACTUAL_PUBLIC_IP" == "None" ] || [ -z "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "Instance AZ${AZ_NUM} does not have public IP (correct - no IGW in spoke VPC)"
            else
                print_fail "Instance AZ${AZ_NUM} should not have public IP but has: $ACTUAL_PUBLIC_IP (spoke VPC has no IGW)"
            fi
        else
            print_fail "EC2 instance AZ${AZ_NUM} not found: $INSTANCE_NAME"
        fi
    done

    # Verify security groups are attached to instances
    print_info "Verifying security groups are attached to instances..."
    for AZ_NUM in 1 2; do
        INSTANCE_NAME="${CP}-${ENV}-west-public-az${AZ_NUM}-instance"
        INSTANCE_ID=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=running" \
            --query 'Reservations[0].Instances[0].InstanceId' \
            --output text 2>/dev/null)

        if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
            SG_IDS=$(aws ec2 describe-instances \
                --region "$AWS_REGION" \
                --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
                --output text 2>/dev/null)

            if [ -n "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
                SG_COUNT=$(echo "$SG_IDS" | wc -w | xargs)
                print_pass "Instance AZ${AZ_NUM} has ${SG_COUNT} security group(s) attached: $SG_IDS"
            else
                print_fail "Instance AZ${AZ_NUM} has no security groups attached"
            fi
        fi
    done
else
    print_skip "EC2 instances check skipped (enable_linux_spoke_instances = false)"
fi

# Print summary and exit
print_summary
exit $?
