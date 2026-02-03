#!/bin/bash

# Verify Management VPC Resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Get the terraform directory (parent of verify_scripts)
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

print_section "MANAGEMENT VPC VERIFICATION"

# Read tfvars
read_tfvars "$TFVARS_FILE"

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

# Check if management VPC is enabled
if ! is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
    print_skip "Management VPC is not enabled (enable_build_management_vpc = false)"
    print_summary
    exit 0
fi

VPC_CIDR_MANAGEMENT=$(get_tfvar "vpc_cidr_management" "$TFVARS_FILE")
VPC_NAME="${CP}-${ENV}-management-vpc"

print_info "Expected Management VPC CIDR: $VPC_CIDR_MANAGEMENT"

# 1. Verify VPC exists
print_info "Checking if Management VPC exists..."
VPC_ID=$(verify_vpc_exists "$VPC_NAME" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "Management VPC exists: $VPC_ID"
else
    print_fail "Management VPC does not exist: $VPC_NAME"
    print_summary
    exit 1
fi

# 2. Verify VPC CIDR
print_info "Verifying VPC CIDR..."
if verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_MANAGEMENT" "$AWS_REGION"; then
    print_pass "VPC CIDR matches: $VPC_CIDR_MANAGEMENT"
else
    result=$(verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_MANAGEMENT" "$AWS_REGION")
    print_fail "VPC CIDR mismatch: $result"
fi

# 3. Verify Internet Gateway
print_info "Verifying Internet Gateway..."
IGW_ID=$(verify_igw "$VPC_ID" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "Internet Gateway exists and is attached: $IGW_ID"
else
    print_fail "Internet Gateway not found or not attached"
fi

# 4. Verify subnets exist
print_info "Verifying subnets..."

# Public subnets
PUBLIC_SUBNET_AZ1_NAME="${CP}-${ENV}-management-public-az1-subnet"
PUBLIC_SUBNET_AZ2_NAME="${CP}-${ENV}-management-public-az2-subnet"

PUBLIC_SUBNET_AZ1_ID=$(verify_subnet_exists "$PUBLIC_SUBNET_AZ1_NAME" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "Public subnet AZ1 exists: $PUBLIC_SUBNET_AZ1_ID"

    # Verify AZ
    if verify_subnet_az "$PUBLIC_SUBNET_AZ1_ID" "$FULL_AZ1" "$AWS_REGION"; then
        print_pass "Public subnet AZ1 is in correct availability zone: $FULL_AZ1"
    else
        result=$(verify_subnet_az "$PUBLIC_SUBNET_AZ1_ID" "$FULL_AZ1" "$AWS_REGION")
        print_fail "Public subnet AZ1 availability zone mismatch: $result"
    fi
else
    print_fail "Public subnet AZ1 does not exist: $PUBLIC_SUBNET_AZ1_NAME"
fi

PUBLIC_SUBNET_AZ2_ID=$(verify_subnet_exists "$PUBLIC_SUBNET_AZ2_NAME" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "Public subnet AZ2 exists: $PUBLIC_SUBNET_AZ2_ID"

    # Verify AZ
    if verify_subnet_az "$PUBLIC_SUBNET_AZ2_ID" "$FULL_AZ2" "$AWS_REGION"; then
        print_pass "Public subnet AZ2 is in correct availability zone: $FULL_AZ2"
    else
        result=$(verify_subnet_az "$PUBLIC_SUBNET_AZ2_ID" "$FULL_AZ2" "$AWS_REGION")
        print_fail "Public subnet AZ2 availability zone mismatch: $result"
    fi
else
    print_fail "Public subnet AZ2 does not exist: $PUBLIC_SUBNET_AZ2_NAME"
fi

# 5. Verify route tables
print_info "Verifying route tables..."

# Get the main route table for management VPC public subnets
PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${CP}-${ENV}-management-main-route-table" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null)

if [ "$PUBLIC_RT_ID" != "None" ] && [ -n "$PUBLIC_RT_ID" ]; then
    print_pass "Public route table exists: $PUBLIC_RT_ID"

    # Verify default route to IGW
    if verify_route_exists "$PUBLIC_RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
        TARGET=$(get_route_target "$PUBLIC_RT_ID" "0.0.0.0/0" "$AWS_REGION")
        if [[ "$TARGET" == igw-* ]]; then
            print_pass "Default route (0.0.0.0/0) points to Internet Gateway: $TARGET"
        else
            print_fail "Default route exists but does not point to IGW: $TARGET"
        fi
    else
        print_fail "Default route (0.0.0.0/0) not found in public route table"
    fi

    # Verify local route
    if verify_route_exists "$PUBLIC_RT_ID" "$VPC_CIDR_MANAGEMENT" "$AWS_REGION"; then
        print_pass "Local route to VPC CIDR exists: $VPC_CIDR_MANAGEMENT"
    else
        print_fail "Local route to VPC CIDR not found: $VPC_CIDR_MANAGEMENT"
    fi

    # If TGW attachment is enabled, verify routes to spoke VPCs
    if is_tfvar_true "enable_management_tgw_attachment" "$TFVARS_FILE"; then
        print_info "Checking TGW routes (enable_management_tgw_attachment = true)..."

        # Get spoke VPC CIDRs from tfvars
        VPC_CIDR_EAST=$(get_tfvar "vpc_cidr_east" "$TFVARS_FILE")
        VPC_CIDR_WEST=$(get_tfvar "vpc_cidr_west" "$TFVARS_FILE")

        # Check if existing subnets are enabled (spoke VPCs exist)
        if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
            # Check for spoke VPC routes
            for CIDR in "$VPC_CIDR_EAST" "$VPC_CIDR_WEST"; do
                if verify_route_exists "$PUBLIC_RT_ID" "$CIDR" "$AWS_REGION"; then
                    TARGET=$(get_route_target "$PUBLIC_RT_ID" "$CIDR" "$AWS_REGION")
                    if [[ "$TARGET" == tgw-* ]]; then
                        print_pass "Route to $CIDR points to TGW: $TARGET"
                    else
                        print_fail "Route to $CIDR exists but does not point to TGW: $TARGET"
                    fi
                else
                    print_fail "Route to $CIDR not found"
                fi
            done
        else
            print_skip "Spoke VPC routes not checked (enable_build_existing_subnets = false)"
        fi
    fi
else
    print_fail "Public route table not found"
fi

# 6. Verify TGW attachment if enabled
if is_tfvar_true "enable_management_tgw_attachment" "$TFVARS_FILE"; then
    print_info "Verifying TGW attachment..."

    TGW_NAME=$(get_tfvar "attach_to_tgw_name" "$TFVARS_FILE")
    TGW_ID=$(get_tgw_id_by_name "$TGW_NAME" "$AWS_REGION")

    if [ $? -eq 0 ]; then
        print_pass "Transit Gateway exists: $TGW_ID"

        # Check for attachment
        ATTACHMENT_ID=$(verify_tgw_attachment "$VPC_ID" "$TGW_ID" "$AWS_REGION")
        if [ $? -eq 0 ]; then
            print_pass "TGW attachment exists: $ATTACHMENT_ID"
        else
            print_fail "TGW attachment not found for management VPC"
        fi
    else
        print_fail "Transit Gateway not found: $TGW_NAME"
    fi
else
    print_skip "TGW attachment check skipped (enable_management_tgw_attachment = false)"
fi

# 7. Verify EC2 instances
print_info "Verifying EC2 instances..."

# Jump Box
if is_tfvar_true "enable_jump_box" "$TFVARS_FILE"; then
    JUMP_BOX_NAME="${CP}-${ENV}-management-jump-box-instance"
    JUMP_BOX_INSTANCE_ID=$(verify_ec2_instance "$JUMP_BOX_NAME" "$AWS_REGION")

    if [ $? -eq 0 ]; then
        print_pass "Jump box instance exists: $JUMP_BOX_INSTANCE_ID"

        # Verify private IP
        LINUX_HOST_IP=$(get_tfvar "linux_host_ip" "$TFVARS_FILE")
        ACTUAL_PRIVATE_IP=$(get_instance_private_ip "$JUMP_BOX_INSTANCE_ID" "$AWS_REGION")

        # Get the subnet CIDR to calculate expected IP
        SUBNET_NAME="${CP}-${ENV}-management-public-az1-subnet"
        SUBNET_CIDR=$(aws ec2 describe-subnets \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${SUBNET_NAME}" \
            --query 'Subnets[0].CidrBlock' \
            --output text 2>/dev/null)

        if [ -n "$SUBNET_CIDR" ] && [ "$SUBNET_CIDR" != "None" ]; then
            RESULT=$(verify_instance_ip_in_subnet "$ACTUAL_PRIVATE_IP" "$SUBNET_CIDR" "$LINUX_HOST_IP")
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                print_pass "Jump box private IP matches expected: $ACTUAL_PRIVATE_IP (host #$LINUX_HOST_IP in $SUBNET_CIDR)"
            else
                print_fail "Jump box private IP mismatch: $RESULT"
            fi
        else
            print_info "Jump box private IP: $ACTUAL_PRIVATE_IP (subnet CIDR not found, skipping validation)"
        fi

        # Check public IP
        ACTUAL_PUBLIC_IP=$(get_instance_public_ip "$JUMP_BOX_INSTANCE_ID" "$AWS_REGION")
        if is_tfvar_true "enable_jump_box_public_ip" "$TFVARS_FILE"; then
            if [ "$ACTUAL_PUBLIC_IP" != "None" ] && [ -n "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "Jump box has public IP: $ACTUAL_PUBLIC_IP"
            else
                print_fail "Jump box should have public IP but doesn't"
            fi
        else
            if [ "$ACTUAL_PUBLIC_IP" == "None" ] || [ -z "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "Jump box does not have public IP (as expected)"
            else
                print_fail "Jump box should not have public IP but has: $ACTUAL_PUBLIC_IP"
            fi
        fi
    else
        print_fail "Jump box instance not found: $JUMP_BOX_NAME"
    fi
else
    print_skip "Jump box check skipped (enable_jump_box = false)"
fi

# FortiManager
if is_tfvar_true "enable_fortimanager" "$TFVARS_FILE"; then
    FMG_NAME="${CP}-${ENV}-management-Fortimanager"
    FMG_INSTANCE_ID=$(verify_ec2_instance "$FMG_NAME" "$AWS_REGION")

    if [ $? -eq 0 ]; then
        print_pass "FortiManager instance exists: $FMG_INSTANCE_ID"

        # Verify private IP
        FMG_HOST_IP=$(get_tfvar "fortimanager_host_ip" "$TFVARS_FILE")
        ACTUAL_PRIVATE_IP=$(get_instance_private_ip "$FMG_INSTANCE_ID" "$AWS_REGION")

        # Get the subnet CIDR to calculate expected IP
        SUBNET_NAME="${CP}-${ENV}-management-public-az1-subnet"
        SUBNET_CIDR=$(aws ec2 describe-subnets \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${SUBNET_NAME}" \
            --query 'Subnets[0].CidrBlock' \
            --output text 2>/dev/null)

        if [ -n "$SUBNET_CIDR" ] && [ "$SUBNET_CIDR" != "None" ]; then
            RESULT=$(verify_instance_ip_in_subnet "$ACTUAL_PRIVATE_IP" "$SUBNET_CIDR" "$FMG_HOST_IP")
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                print_pass "FortiManager private IP matches expected: $ACTUAL_PRIVATE_IP (host #$FMG_HOST_IP in $SUBNET_CIDR)"
            else
                print_fail "FortiManager private IP mismatch: $RESULT"
            fi
        else
            print_info "FortiManager private IP: $ACTUAL_PRIVATE_IP (subnet CIDR not found, skipping validation)"
        fi

        # Check public IP
        ACTUAL_PUBLIC_IP=$(get_instance_public_ip "$FMG_INSTANCE_ID" "$AWS_REGION")
        if is_tfvar_true "enable_fortimanager_public_ip" "$TFVARS_FILE"; then
            if [ "$ACTUAL_PUBLIC_IP" != "None" ] && [ -n "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "FortiManager has public IP: $ACTUAL_PUBLIC_IP"
            else
                print_fail "FortiManager should have public IP but doesn't"
            fi
        else
            if [ "$ACTUAL_PUBLIC_IP" == "None" ] || [ -z "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "FortiManager does not have public IP (as expected)"
            else
                print_fail "FortiManager should not have public IP but has: $ACTUAL_PUBLIC_IP"
            fi
        fi
    else
        print_fail "FortiManager instance not found: $FMG_NAME"
    fi
else
    print_skip "FortiManager check skipped (enable_fortimanager = false)"
fi

# FortiAnalyzer
if is_tfvar_true "enable_fortianalyzer" "$TFVARS_FILE"; then
    FAZ_NAME="${CP}-${ENV}-management-Fortianalyzer"
    FAZ_INSTANCE_ID=$(verify_ec2_instance "$FAZ_NAME" "$AWS_REGION")

    if [ $? -eq 0 ]; then
        print_pass "FortiAnalyzer instance exists: $FAZ_INSTANCE_ID"

        # Verify private IP
        FAZ_HOST_IP=$(get_tfvar "fortianalyzer_host_ip" "$TFVARS_FILE")
        ACTUAL_PRIVATE_IP=$(get_instance_private_ip "$FAZ_INSTANCE_ID" "$AWS_REGION")

        # Get the subnet CIDR to calculate expected IP
        SUBNET_NAME="${CP}-${ENV}-management-public-az1-subnet"
        SUBNET_CIDR=$(aws ec2 describe-subnets \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${SUBNET_NAME}" \
            --query 'Subnets[0].CidrBlock' \
            --output text 2>/dev/null)

        if [ -n "$SUBNET_CIDR" ] && [ "$SUBNET_CIDR" != "None" ]; then
            RESULT=$(verify_instance_ip_in_subnet "$ACTUAL_PRIVATE_IP" "$SUBNET_CIDR" "$FAZ_HOST_IP")
            EXIT_CODE=$?
            if [ $EXIT_CODE -eq 0 ]; then
                print_pass "FortiAnalyzer private IP matches expected: $ACTUAL_PRIVATE_IP (host #$FAZ_HOST_IP in $SUBNET_CIDR)"
            else
                print_fail "FortiAnalyzer private IP mismatch: $RESULT"
            fi
        else
            print_info "FortiAnalyzer private IP: $ACTUAL_PRIVATE_IP (subnet CIDR not found, skipping validation)"
        fi

        # Check public IP
        ACTUAL_PUBLIC_IP=$(get_instance_public_ip "$FAZ_INSTANCE_ID" "$AWS_REGION")
        if is_tfvar_true "enable_fortianalyzer_public_ip" "$TFVARS_FILE"; then
            if [ "$ACTUAL_PUBLIC_IP" != "None" ] && [ -n "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "FortiAnalyzer has public IP: $ACTUAL_PUBLIC_IP"
            else
                print_fail "FortiAnalyzer should have public IP but doesn't"
            fi
        else
            if [ "$ACTUAL_PUBLIC_IP" == "None" ] || [ -z "$ACTUAL_PUBLIC_IP" ]; then
                print_pass "FortiAnalyzer does not have public IP (as expected)"
            else
                print_fail "FortiAnalyzer should not have public IP but has: $ACTUAL_PUBLIC_IP"
            fi
        fi
    else
        print_fail "FortiAnalyzer instance not found: $FAZ_NAME"
    fi
else
    print_skip "FortiAnalyzer check skipped (enable_fortianalyzer = false)"
fi

# Print summary and exit
print_summary
exit $?
