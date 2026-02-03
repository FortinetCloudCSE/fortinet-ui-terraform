#!/bin/bash

# Verify Distributed VPC Resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Get the terraform directory (parent of verify_scripts)
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

print_section "DISTRIBUTED VPC VERIFICATION"

# Read tfvars
read_tfvars "$TFVARS_FILE"

# Check if distributed VPCs are enabled
if ! is_tfvar_true "enable_distributed_egress_vpcs" "$TFVARS_FILE"; then
    print_skip "Distributed VPCs are not enabled (enable_distributed_egress_vpcs = false)"
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

# Get distributed VPC configuration
VPC_COUNT=$(get_tfvar "distributed_egress_vpc_count" "$TFVARS_FILE")
VPC_1_CIDR=$(get_tfvar "distributed_egress_vpc_1_cidr" "$TFVARS_FILE")
VPC_2_CIDR=$(get_tfvar "distributed_egress_vpc_2_cidr" "$TFVARS_FILE")
VPC_3_CIDR=$(get_tfvar "distributed_egress_vpc_3_cidr" "$TFVARS_FILE")

# Build array of CIDRs based on count
declare -a VPC_CIDRS
VPC_CIDRS[1]="$VPC_1_CIDR"
VPC_CIDRS[2]="$VPC_2_CIDR"
VPC_CIDRS[3]="$VPC_3_CIDR"

print_info "Number of Distributed VPCs: $VPC_COUNT"

# Check if Linux instances are enabled
LINUX_INSTANCES_ENABLED=$(is_tfvar_true "enable_distributed_linux_instances" "$TFVARS_FILE" && echo "true" || echo "false")
LINUX_INSTANCE_TYPE=$(get_tfvar "distributed_linux_instance_type" "$TFVARS_FILE")
LINUX_HOST_IP=$(get_tfvar "distributed_linux_host_ip" "$TFVARS_FILE")

print_info "Linux Instances Enabled: $LINUX_INSTANCES_ENABLED"

# Loop through each distributed VPC
for VPC_NUM in $(seq 1 $VPC_COUNT); do
    print_section "DISTRIBUTED VPC $VPC_NUM"

    VPC_CIDR="${VPC_CIDRS[$VPC_NUM]}"
    VPC_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-vpc"

    print_info "Expected VPC CIDR: $VPC_CIDR"

    # 1. Verify VPC exists
    print_info "Checking if Distributed VPC $VPC_NUM exists..."
    VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${VPC_NAME}" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)

    if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
        print_pass "Distributed VPC $VPC_NUM exists: $VPC_ID"
    else
        print_fail "Distributed VPC $VPC_NUM does not exist: $VPC_NAME"
        continue
    fi

    # 2. Verify VPC CIDR
    print_info "Verifying VPC CIDR..."
    if verify_vpc_cidr "$VPC_ID" "$VPC_CIDR" "$AWS_REGION"; then
        print_pass "VPC CIDR matches: $VPC_CIDR"
    else
        result=$(verify_vpc_cidr "$VPC_ID" "$VPC_CIDR" "$AWS_REGION")
        print_fail "VPC CIDR mismatch: $result"
    fi

    # 3. Verify Internet Gateway
    print_info "Verifying Internet Gateway..."
    IGW_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-igw"
    IGW_ID=$(verify_igw "$VPC_ID" "$AWS_REGION")
    if [ $? -eq 0 ]; then
        print_pass "Internet Gateway exists and attached: $IGW_ID"
    else
        print_fail "Internet Gateway not found or not attached to VPC"
    fi

    # 4. Verify subnets exist
    print_info "Verifying subnets..."

    # Subnet types to check
    declare -a SUBNET_TYPES=("public" "private" "gwlbe")

    for SUBNET_TYPE in "${SUBNET_TYPES[@]}"; do
        for AZ_NUM in 1 2; do
            if [ $AZ_NUM -eq 1 ]; then
                FULL_AZ="$FULL_AZ1"
            else
                FULL_AZ="$FULL_AZ2"
            fi

            SUBNET_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-${SUBNET_TYPE}-az${AZ_NUM}-subnet"
            SUBNET_ID=$(verify_subnet_exists "$SUBNET_NAME" "$AWS_REGION")
            if [ $? -eq 0 ]; then
                print_pass "${SUBNET_TYPE^} subnet AZ${AZ_NUM} exists: $SUBNET_ID"
                if verify_subnet_az "$SUBNET_ID" "$FULL_AZ" "$AWS_REGION"; then
                    print_pass "${SUBNET_TYPE^} subnet AZ${AZ_NUM} is in correct AZ: $FULL_AZ"
                else
                    print_fail "${SUBNET_TYPE^} subnet AZ${AZ_NUM} AZ mismatch"
                fi
            else
                print_fail "${SUBNET_TYPE^} subnet AZ${AZ_NUM} does not exist: $SUBNET_NAME"
            fi
        done
    done

    # 5. Verify route tables
    print_info "Verifying route tables..."

    # Public route tables - should have default route to IGW
    for AZ_NUM in 1 2; do
        RT_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-public-az${AZ_NUM}-rtb"
        RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${RT_NAME}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        if [ "$RT_ID" != "None" ] && [ -n "$RT_ID" ]; then
            print_pass "Public route table AZ${AZ_NUM} exists: $RT_ID"

            # Verify default route to IGW
            if verify_route_exists "$RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
                TARGET=$(get_route_target "$RT_ID" "0.0.0.0/0" "$AWS_REGION")
                if [[ "$TARGET" == igw-* ]]; then
                    print_pass "Public AZ${AZ_NUM} default route (0.0.0.0/0) points to IGW: $TARGET"
                else
                    print_fail "Public AZ${AZ_NUM} default route exists but does not point to IGW: $TARGET"
                fi
            else
                print_fail "Public AZ${AZ_NUM} default route (0.0.0.0/0) not found"
            fi
        else
            print_fail "Public route table AZ${AZ_NUM} not found: $RT_NAME"
        fi
    done

    # Private route tables
    for AZ_NUM in 1 2; do
        RT_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-private-az${AZ_NUM}-rtb"
        RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${RT_NAME}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        if [ "$RT_ID" != "None" ] && [ -n "$RT_ID" ]; then
            print_pass "Private route table AZ${AZ_NUM} exists: $RT_ID"
        else
            print_fail "Private route table AZ${AZ_NUM} not found: $RT_NAME"
        fi
    done

    # GWLBE route tables - should have default route to IGW
    for AZ_NUM in 1 2; do
        RT_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-gwlbe-az${AZ_NUM}-rtb"
        RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${RT_NAME}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        if [ "$RT_ID" != "None" ] && [ -n "$RT_ID" ]; then
            print_pass "GWLBE route table AZ${AZ_NUM} exists: $RT_ID"

            # Verify default route to IGW
            if verify_route_exists "$RT_ID" "0.0.0.0/0" "$AWS_REGION"; then
                TARGET=$(get_route_target "$RT_ID" "0.0.0.0/0" "$AWS_REGION")
                if [[ "$TARGET" == igw-* ]]; then
                    print_pass "GWLBE AZ${AZ_NUM} default route (0.0.0.0/0) points to IGW: $TARGET"
                else
                    print_fail "GWLBE AZ${AZ_NUM} default route exists but does not point to IGW: $TARGET"
                fi
            else
                print_fail "GWLBE AZ${AZ_NUM} default route (0.0.0.0/0) not found"
            fi
        else
            print_fail "GWLBE route table AZ${AZ_NUM} not found: $RT_NAME"
        fi
    done

    # 6. Verify EC2 instances if enabled
    if [ "$LINUX_INSTANCES_ENABLED" = "true" ]; then
        print_info "Verifying EC2 instances..."

        for AZ_NUM in 1 2; do
            INSTANCE_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-instance-az${AZ_NUM}"
            INSTANCE_ID=$(verify_ec2_instance "$INSTANCE_NAME" "$AWS_REGION")

            if [ $? -eq 0 ]; then
                print_pass "EC2 instance AZ${AZ_NUM} exists: $INSTANCE_ID"

                # Verify instance type
                ACTUAL_TYPE=$(aws ec2 describe-instances \
                    --region "$AWS_REGION" \
                    --instance-ids "$INSTANCE_ID" \
                    --query 'Reservations[0].Instances[0].InstanceType' \
                    --output text 2>/dev/null)

                if [ "$ACTUAL_TYPE" = "$LINUX_INSTANCE_TYPE" ]; then
                    print_pass "Instance AZ${AZ_NUM} type matches: $ACTUAL_TYPE"
                else
                    print_fail "Instance AZ${AZ_NUM} type mismatch: Expected $LINUX_INSTANCE_TYPE, Got $ACTUAL_TYPE"
                fi

                # Verify private IP
                ACTUAL_PRIVATE_IP=$(get_instance_private_ip "$INSTANCE_ID" "$AWS_REGION")

                # Get the subnet CIDR to calculate expected IP
                SUBNET_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-private-az${AZ_NUM}-subnet"
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

                # Verify public IP exists (distributed VPCs require public IP for access)
                ACTUAL_PUBLIC_IP=$(get_instance_public_ip "$INSTANCE_ID" "$AWS_REGION")
                if [ "$ACTUAL_PUBLIC_IP" != "None" ] && [ -n "$ACTUAL_PUBLIC_IP" ]; then
                    print_pass "Instance AZ${AZ_NUM} has public IP: $ACTUAL_PUBLIC_IP"
                else
                    print_fail "Instance AZ${AZ_NUM} should have public IP but does not (required for access - no TGW connectivity)"
                fi
            else
                print_fail "EC2 instance AZ${AZ_NUM} not found: $INSTANCE_NAME"
            fi
        done

        # Verify security groups are attached to instances
        print_info "Verifying security groups..."
        SG_NAME="${CP}-${ENV}-distributed-${VPC_NUM}-instance-sg"
        SG_ID=$(aws ec2 describe-security-groups \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=${SG_NAME}" \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null)

        if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
            print_pass "Security group exists: $SG_ID ($SG_NAME)"
        else
            print_fail "Security group not found: $SG_NAME"
        fi
    else
        print_skip "EC2 instances check skipped (enable_distributed_linux_instances = false)"
    fi

    # 7. Verify VPC has correct tags
    print_info "Verifying VPC tags..."
    PURPOSE_TAG=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --vpc-ids "$VPC_ID" \
        --query "Vpcs[0].Tags[?Key=='purpose'].Value" \
        --output text 2>/dev/null)

    if [ "$PURPOSE_TAG" = "distributed_egress" ]; then
        print_pass "VPC has correct purpose tag: distributed_egress"
    else
        print_fail "VPC purpose tag mismatch: Expected 'distributed_egress', Got '$PURPOSE_TAG'"
    fi
done

# Print summary and exit
print_summary
exit $?
