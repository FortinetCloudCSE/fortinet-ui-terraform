#!/bin/bash

# Verify Inspection VPC Resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Get the terraform directory (parent of verify_scripts)
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

print_section "INSPECTION VPC VERIFICATION"

# Read tfvars
read_tfvars "$TFVARS_FILE"

# Get basic configuration
AWS_REGION=$(get_tfvar "aws_region" "$TFVARS_FILE")
AZ1=$(get_tfvar "availability_zone_1" "$TFVARS_FILE")
AZ2=$(get_tfvar "availability_zone_2" "$TFVARS_FILE")
CP=$(get_tfvar "cp" "$TFVARS_FILE")
ENV=$(get_tfvar "env" "$TFVARS_FILE")
ACCESS_MODE=$(get_tfvar "access_internet_mode" "$TFVARS_FILE")

# Full AZ names
FULL_AZ1="${AWS_REGION}${AZ1}"
FULL_AZ2="${AWS_REGION}${AZ2}"

print_info "Region: $AWS_REGION"
print_info "Availability Zones: $FULL_AZ1, $FULL_AZ2"
print_info "Prefix: ${CP}-${ENV}"
print_info "Access Internet Mode: $ACCESS_MODE"

VPC_CIDR_INSPECTION=$(get_tfvar "vpc_cidr_inspection" "$TFVARS_FILE")
VPC_NAME="${CP}-${ENV}-inspection-vpc"

print_info "Expected Inspection VPC CIDR: $VPC_CIDR_INSPECTION"

# 1. Verify VPC exists
print_info "Checking if Inspection VPC exists..."
VPC_ID=$(verify_vpc_exists "$VPC_NAME" "$AWS_REGION")
if [ $? -eq 0 ]; then
    print_pass "Inspection VPC exists: $VPC_ID"
else
    print_fail "Inspection VPC does not exist: $VPC_NAME"
    print_summary
    exit 1
fi

# 2. Verify VPC CIDR
print_info "Verifying VPC CIDR..."
if verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_INSPECTION" "$AWS_REGION"; then
    print_pass "VPC CIDR matches: $VPC_CIDR_INSPECTION"
else
    result=$(verify_vpc_cidr "$VPC_ID" "$VPC_CIDR_INSPECTION" "$AWS_REGION")
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
for AZ_NUM in 1 2; do
    if [ $AZ_NUM -eq 1 ]; then
        FULL_AZ="$FULL_AZ1"
    else
        FULL_AZ="$FULL_AZ2"
    fi

    PUBLIC_SUBNET_NAME="${CP}-${ENV}-inspection-public-az${AZ_NUM}-subnet"
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

# Private subnets
for AZ_NUM in 1 2; do
    if [ $AZ_NUM -eq 1 ]; then
        FULL_AZ="$FULL_AZ1"
    else
        FULL_AZ="$FULL_AZ2"
    fi

    PRIVATE_SUBNET_NAME="${CP}-${ENV}-inspection-private-az${AZ_NUM}-subnet"
    SUBNET_ID=$(verify_subnet_exists "$PRIVATE_SUBNET_NAME" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "Private subnet AZ${AZ_NUM} exists: $SUBNET_ID"
        if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
            print_pass "Private subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
        else
            print_fail "Private subnet AZ${AZ_NUM} AZ mismatch"
        fi
    else
        print_fail "Private subnet AZ${AZ_NUM} does not exist: $PRIVATE_SUBNET_NAME"
    fi
done

# Note: Inspection VPC does not have dedicated TGW subnets
# This was intentionally omitted to avoid IP conflicts with spoke instances
# TGW attachment uses other subnets (typically private subnets)
print_info "Inspection VPC does not use dedicated TGW subnets (by design to avoid IP conflicts)"

# GWLB subnets
for AZ_NUM in 1 2; do
    if [ $AZ_NUM -eq 1 ]; then
        FULL_AZ="$FULL_AZ1"
    else
        FULL_AZ="$FULL_AZ2"
    fi

    GWLB_SUBNET_NAME="${CP}-${ENV}-inspection-gwlbe-az${AZ_NUM}-subnet"
    SUBNET_ID=$(verify_subnet_exists "$GWLB_SUBNET_NAME" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "GWLB subnet AZ${AZ_NUM} exists: $SUBNET_ID"
        if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
            print_pass "GWLB subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
        else
            print_fail "GWLB subnet AZ${AZ_NUM} AZ mismatch"
        fi
    else
        print_fail "GWLB subnet AZ${AZ_NUM} does not exist: $GWLB_SUBNET_NAME"
    fi
done

# NAT Gateway subnets (if access mode is nat_gw)
if [ "$ACCESS_MODE" == "nat_gw" ]; then
    for AZ_NUM in 1 2; do
        if [ $AZ_NUM -eq 1 ]; then
            FULL_AZ="$FULL_AZ1"
        else
            FULL_AZ="$FULL_AZ2"
        fi

        NATGW_SUBNET_NAME="${CP}-${ENV}-inspection-natgw-az${AZ_NUM}-subnet"
        SUBNET_ID=$(verify_subnet_exists "$NATGW_SUBNET_NAME" "$AWS_REGION")
        if [ $? -eq 0 ]; then
            print_pass "NAT Gateway subnet AZ${AZ_NUM} exists: $SUBNET_ID"
            if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
                print_pass "NAT Gateway subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
            else
                print_fail "NAT Gateway subnet AZ${AZ_NUM} AZ mismatch"
            fi
        else
            print_fail "NAT Gateway subnet AZ${AZ_NUM} does not exist: $NATGW_SUBNET_NAME"
        fi
    done
else
    print_skip "NAT Gateway subnets check skipped (access_internet_mode != nat_gw)"
fi

# Management subnets (if enabled and management VPC is not enabled)
if is_tfvar_true "create_management_subnet_in_inspection_vpc" "$TFVARS_FILE"; then
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
        print_skip "Management subnets in inspection VPC skipped (enable_build_management_vpc = true)"
    else
        for AZ_NUM in 1 2; do
            if [ $AZ_NUM -eq 1 ]; then
                FULL_AZ="$FULL_AZ1"
            else
                FULL_AZ="$FULL_AZ2"
            fi

            MGMT_SUBNET_NAME="${CP}-${ENV}-inspection-management-az${AZ_NUM}-subnet"
            SUBNET_ID=$(verify_subnet_exists "$MGMT_SUBNET_NAME" "$AWS_REGION")
            if [ $? -eq 0 ]; then
                print_pass "Management subnet AZ${AZ_NUM} exists: $SUBNET_ID"
                if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
                    print_pass "Management subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
                else
                    print_fail "Management subnet AZ${AZ_NUM} AZ mismatch"
                fi
            else
                print_fail "Management subnet AZ${AZ_NUM} does not exist: $MGMT_SUBNET_NAME"
            fi
        done
    fi
else
    print_skip "Management subnets check skipped (create_management_subnet_in_inspection_vpc = false)"
fi

# 5. Verify route tables
print_info "Verifying route tables..."

# Public route tables (per AZ)
for AZ_NUM in 1 2; do
    PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
        --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${CP}-${ENV}-inspection-public-rt-az${AZ_NUM}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null)

    if [ "$PUBLIC_RT_ID" != "None" ] && [ -n "$PUBLIC_RT_ID" ]; then
        print_pass "Public route table AZ${AZ_NUM} exists: $PUBLIC_RT_ID"

        # NOTE: Default routes (0.0.0.0/0) are NOT checked here because they will be
        # created by the autoscale template when NAT gateways are deployed
        # Checking for them would cause false failures before autoscale deployment

        # Verify local route
        if verify_route_exists "$PUBLIC_RT_ID" "$VPC_CIDR_INSPECTION" "$AWS_REGION"; then
            print_pass "Public AZ${AZ_NUM}: Local route to VPC CIDR exists: $VPC_CIDR_INSPECTION"
        else
            print_fail "Public AZ${AZ_NUM}: Local route to VPC CIDR not found: $VPC_CIDR_INSPECTION"
        fi
    else
        print_fail "Public route table AZ${AZ_NUM} not found"
    fi
done

# Private route tables (per AZ)
for AZ_NUM in 1 2; do
    PRIVATE_RT_ID=$(aws ec2 describe-route-tables \
        --region "$AWS_REGION" \
        --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${CP}-${ENV}-inspection-private-rt-az${AZ_NUM}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null)

    if [ "$PRIVATE_RT_ID" != "None" ] && [ -n "$PRIVATE_RT_ID" ]; then
        print_pass "Private route table AZ${AZ_NUM} exists: $PRIVATE_RT_ID"

        # Verify local route
        if verify_route_exists "$PRIVATE_RT_ID" "$VPC_CIDR_INSPECTION" "$AWS_REGION"; then
            print_pass "Private AZ${AZ_NUM}: Local route to VPC CIDR exists"
        else
            print_fail "Private AZ${AZ_NUM}: Local route to VPC CIDR not found"
        fi

        # Check for default route - accepts NAT Gateway (pre-autoscale) or GWLB endpoint (post-autoscale)
        if [ "$ACCESS_MODE" == "nat_gw" ]; then
            if verify_route_exists "$PRIVATE_RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
                TARGET=$(get_route_target "$PRIVATE_RT_ID" "0.0.0.0/0" "$AWS_REGION")
                if [[ "$TARGET" == nat-* ]]; then
                    print_pass "Private AZ${AZ_NUM}: Default route points to NAT Gateway: $TARGET"
                elif [[ "$TARGET" == vpce-* ]]; then
                    print_pass "Private AZ${AZ_NUM}: Default route points to GWLB endpoint (post-autoscale): $TARGET"
                else
                    print_fail "Private AZ${AZ_NUM}: Default route exists but target unknown: $TARGET"
                fi
            else
                print_info "Private AZ${AZ_NUM}: Default route not found (may not be created yet)"
            fi
        else
            # In EIP mode, default route may point to GWLB endpoint after autoscale deployment
            if verify_route_exists "$PRIVATE_RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
                TARGET=$(get_route_target "$PRIVATE_RT_ID" "0.0.0.0/0" "$AWS_REGION")
                if [[ "$TARGET" == vpce-* ]]; then
                    print_pass "Private AZ${AZ_NUM}: Default route points to GWLB endpoint (post-autoscale): $TARGET"
                else
                    print_fail "Private AZ${AZ_NUM}: Default route exists with unexpected target: $TARGET"
                fi
            else
                print_pass "Private AZ${AZ_NUM}: No default route (correct for eip mode pre-autoscale)"
            fi
        fi
    else
        print_fail "Private route table AZ${AZ_NUM} not found"
    fi
done

# GWLB route table check - may or may not exist depending on deployment state
print_info "Checking GWLB route table status..."
GWLB_RT_ID=$(aws ec2 describe-route-tables \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=*gwlb*" \
    --query 'RouteTables[0].RouteTableId' \
    --output text 2>/dev/null)

if [ "$GWLB_RT_ID" == "None" ] || [ -z "$GWLB_RT_ID" ]; then
    print_info "GWLB route table does not exist yet (pre-autoscale state)"
else
    print_pass "GWLB route table exists (post-autoscale state): $GWLB_RT_ID"
fi

# 6. Verify TGW attachment if enabled
if is_tfvar_true "enable_tgw_attachment" "$TFVARS_FILE"; then
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
            print_fail "TGW attachment not found for inspection VPC"
        fi
    else
        print_fail "Transit Gateway not found: $TGW_NAME"
    fi
else
    print_skip "TGW attachment check skipped (enable_tgw_attachment = false)"
fi

# 7. Verify NAT Gateways if applicable
if [ "$ACCESS_MODE" == "nat_gw" ]; then
    print_info "Verifying NAT Gateways (access_internet_mode = nat_gw)..."

    for AZ_NUM in 1 2; do
        NAT_GW=$(aws ec2 describe-nat-gateways \
            --region "$AWS_REGION" \
            --filter "Name=tag:Name,Values=${CP}-${ENV}-inspection-natgw-az${AZ_NUM}" "Name=state,Values=available" \
            --query 'NatGateways[0].NatGatewayId' \
            --output text 2>/dev/null)

        if [ "$NAT_GW" != "None" ] && [ -n "$NAT_GW" ]; then
            print_pass "NAT Gateway AZ${AZ_NUM} exists: $NAT_GW"
        else
            print_info "NAT Gateway AZ${AZ_NUM} not found (may not be created yet per terraform config)"
        fi
    done
else
    print_skip "NAT Gateway check skipped (access_internet_mode = eip)"
fi

# Print summary and exit
print_summary
exit $?
