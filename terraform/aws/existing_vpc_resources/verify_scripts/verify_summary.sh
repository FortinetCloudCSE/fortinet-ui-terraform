#!/bin/bash

# Infrastructure Summary Script for AWS Resources
# This script displays a summary of all AWS infrastructure without running verifications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Get terraform directory and tfvars file
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

if [ -f "$TFVARS_FILE" ]; then
    AWS_REGION=$(get_tfvar "aws_region" "$TFVARS_FILE")
    CP=$(get_tfvar "cp" "$TFVARS_FILE")
    ENV=$(get_tfvar "env" "$TFVARS_FILE")
    PREFIX="${CP}-${ENV}"

    print_info "Region: $AWS_REGION"
    print_info "Resource Prefix: $PREFIX"
    echo ""

    # Management VPC
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
        echo "=========================================="
        echo "MANAGEMENT VPC"
        echo "=========================================="
        VPC_ID=$(aws ec2 describe-vpcs \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-vpc" \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null)
        if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
            echo "VPC ID: $VPC_ID"

            # Subnets
            echo ""
            echo "Subnets:"
            aws ec2 describe-subnets \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[].[Tags[?Key==`Name`].Value | [0], SubnetId, CidrBlock, AvailabilityZone]' \
                --output text 2>/dev/null | sort | while read -r NAME SUBNET_ID CIDR AZ; do
                echo "  - $NAME: $SUBNET_ID ($CIDR) [$AZ]"
            done

            # Route Tables
            echo ""
            echo "Route Tables:"
            aws ec2 describe-route-tables \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'RouteTables[].[Tags[?Key==`Name`].Value | [0], RouteTableId]' \
                --output text 2>/dev/null | sort | while read -r NAME RT_ID; do
                echo "  - $NAME: $RT_ID"
            done

            # Instances
            echo ""
            echo "Instances:"
            aws ec2 describe-instances \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
                --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value | [0], InstanceId, PrivateIpAddress, PublicIpAddress]' \
                --output text 2>/dev/null | while read -r NAME INSTANCE_ID PRIVATE_IP PUBLIC_IP; do
                if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP)"
                else
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP, Public: $PUBLIC_IP)"
                fi
            done
        else
            echo "Management VPC not found"
        fi
        echo ""
    fi

    # Inspection VPC
    echo "=========================================="
    echo "INSPECTION VPC"
    echo "=========================================="
    VPC_ID=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${PREFIX}-inspection-vpc" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null)
    if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
        echo "VPC ID: $VPC_ID"

        # Subnets
        echo ""
        echo "Subnets:"
        aws ec2 describe-subnets \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'Subnets[].[Tags[?Key==`Name`].Value | [0], SubnetId, CidrBlock, AvailabilityZone]' \
            --output text 2>/dev/null | sort | while read -r NAME SUBNET_ID CIDR AZ; do
            echo "  - $NAME: $SUBNET_ID ($CIDR) [$AZ]"
        done

        # Route Tables
        echo ""
        echo "Route Tables:"
        aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --query 'RouteTables[].[Tags[?Key==`Name`].Value | [0], RouteTableId]' \
            --output text 2>/dev/null | sort | while read -r NAME RT_ID; do
            echo "  - $NAME: $RT_ID"
        done
    else
        echo "Inspection VPC not found"
    fi
    echo ""

    # East VPC
    if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
        echo "=========================================="
        echo "EAST SPOKE VPC"
        echo "=========================================="
        VPC_ID=$(aws ec2 describe-vpcs \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-east-vpc" \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null)
        if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
            echo "VPC ID: $VPC_ID"

            # Subnets
            echo ""
            echo "Subnets:"
            aws ec2 describe-subnets \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[].[Tags[?Key==`Name`].Value | [0], SubnetId, CidrBlock, AvailabilityZone]' \
                --output text 2>/dev/null | sort | while read -r NAME SUBNET_ID CIDR AZ; do
                echo "  - $NAME: $SUBNET_ID ($CIDR) [$AZ]"
            done

            # Route Tables
            echo ""
            echo "Route Tables:"
            aws ec2 describe-route-tables \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'RouteTables[].[Tags[?Key==`Name`].Value | [0], RouteTableId]' \
                --output text 2>/dev/null | sort | while read -r NAME RT_ID; do
                echo "  - $NAME: $RT_ID"
            done

            # Instances
            echo ""
            echo "Instances:"
            aws ec2 describe-instances \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
                --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value | [0], InstanceId, PrivateIpAddress, PublicIpAddress]' \
                --output text 2>/dev/null | while read -r NAME INSTANCE_ID PRIVATE_IP PUBLIC_IP; do
                if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP)"
                else
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP, Public: $PUBLIC_IP)"
                fi
            done
        else
            echo "East VPC not found"
        fi
        echo ""

        # West VPC
        echo "=========================================="
        echo "WEST SPOKE VPC"
        echo "=========================================="
        VPC_ID=$(aws ec2 describe-vpcs \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-west-vpc" \
            --query 'Vpcs[0].VpcId' \
            --output text 2>/dev/null)
        if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
            echo "VPC ID: $VPC_ID"

            # Subnets
            echo ""
            echo "Subnets:"
            aws ec2 describe-subnets \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'Subnets[].[Tags[?Key==`Name`].Value | [0], SubnetId, CidrBlock, AvailabilityZone]' \
                --output text 2>/dev/null | sort | while read -r NAME SUBNET_ID CIDR AZ; do
                echo "  - $NAME: $SUBNET_ID ($CIDR) [$AZ]"
            done

            # Route Tables
            echo ""
            echo "Route Tables:"
            aws ec2 describe-route-tables \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" \
                --query 'RouteTables[].[Tags[?Key==`Name`].Value | [0], RouteTableId]' \
                --output text 2>/dev/null | sort | while read -r NAME RT_ID; do
                echo "  - $NAME: $RT_ID"
            done

            # Instances
            echo ""
            echo "Instances:"
            aws ec2 describe-instances \
                --region "$AWS_REGION" \
                --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
                --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value | [0], InstanceId, PrivateIpAddress, PublicIpAddress]' \
                --output text 2>/dev/null | while read -r NAME INSTANCE_ID PRIVATE_IP PUBLIC_IP; do
                if [ "$PUBLIC_IP" == "None" ] || [ -z "$PUBLIC_IP" ]; then
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP)"
                else
                    echo "  - $NAME: $INSTANCE_ID (Private: $PRIVATE_IP, Public: $PUBLIC_IP)"
                fi
            done
        else
            echo "West VPC not found"
        fi
        echo ""
    fi

    # Transit Gateway
    echo "=========================================="
    echo "TRANSIT GATEWAY"
    echo "=========================================="
    TGW_ID=$(aws ec2 describe-transit-gateways \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=${PREFIX}-tgw" \
        --query 'TransitGateways[0].TransitGatewayId' \
        --output text 2>/dev/null)
    if [ "$TGW_ID" != "None" ] && [ -n "$TGW_ID" ]; then
        echo "TGW ID: $TGW_ID (${PREFIX}-tgw)"

        # TGW Attachments
        echo ""
        echo "TGW Attachments:"
        aws ec2 describe-transit-gateway-attachments \
            --region "$AWS_REGION" \
            --filters "Name=transit-gateway-id,Values=$TGW_ID" "Name=state,Values=available" \
            --query 'TransitGatewayAttachments[].[Tags[?Key==`Name`].Value | [0], TransitGatewayAttachmentId, ResourceId]' \
            --output text 2>/dev/null | while read -r NAME ATTACH_ID VPC_ID; do
            echo "  - $NAME: $ATTACH_ID (VPC: $VPC_ID)"
        done
    else
        echo "Transit Gateway not found"
    fi
    echo ""

    # Summary of all default routes
    echo "=========================================="
    echo "ALL DEFAULT ROUTES (0.0.0.0/0)"
    echo "=========================================="
    printf "%-50s %-25s %-25s\n" "ROUTE TABLE" "ROUTE TABLE ID" "TARGET"
    printf "%-50s %-25s %-25s\n" "-----------" "---------------" "------"

    # West VPC public route table
    if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
        WEST_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-west-vpc-main-route-table" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        WEST_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-west-vpc-main-route-table" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$WEST_RT_TARGET" ] && WEST_RT_TARGET="No default route"

        printf "%-50s %-25s %-25s\n" "West VPC Public" "$WEST_RT_ID" "$WEST_RT_TARGET"
    fi

    # West TGW attachment route table
    if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
        WEST_TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-west-tgw-rtb" \
            --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
            --output text 2>/dev/null)

        if [ -n "$WEST_TGW_RT_ID" ] && [ "$WEST_TGW_RT_ID" != "None" ]; then
            WEST_TGW_TARGET=$(aws ec2 search-transit-gateway-routes \
                --region "$AWS_REGION" \
                --transit-gateway-route-table-id "$WEST_TGW_RT_ID" \
                --filters "Name=type,Values=static" \
                --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
                --output text 2>/dev/null)
            [ -z "$WEST_TGW_TARGET" ] && WEST_TGW_TARGET="No default route"
            printf "%-50s %-25s %-25s\n" "West TGW Attachment" "$WEST_TGW_RT_ID" "$WEST_TGW_TARGET"
        fi
    fi

    # East VPC public route table
    if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
        EAST_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-east-vpc-main-route-table" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        EAST_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-east-vpc-main-route-table" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$EAST_RT_TARGET" ] && EAST_RT_TARGET="No default route"

        printf "%-50s %-25s %-25s\n" "East VPC Public" "$EAST_RT_ID" "$EAST_RT_TARGET"
    fi

    # East TGW attachment route table
    if is_tfvar_true "enable_build_existing_subnets" "$TFVARS_FILE"; then
        EAST_TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-east-tgw-rtb" \
            --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
            --output text 2>/dev/null)

        if [ -n "$EAST_TGW_RT_ID" ] && [ "$EAST_TGW_RT_ID" != "None" ]; then
            EAST_TGW_TARGET=$(aws ec2 search-transit-gateway-routes \
                --region "$AWS_REGION" \
                --transit-gateway-route-table-id "$EAST_TGW_RT_ID" \
                --filters "Name=type,Values=static" \
                --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
                --output text 2>/dev/null)
            [ -z "$EAST_TGW_TARGET" ] && EAST_TGW_TARGET="No default route"
            printf "%-50s %-25s %-25s\n" "East TGW Attachment" "$EAST_TGW_RT_ID" "$EAST_TGW_TARGET"
        fi
    fi

    # Management VPC private route table
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
        MGMT_PRIV_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-private-rtb" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        MGMT_PRIV_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-private-rtb" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$MGMT_PRIV_RT_TARGET" ] && MGMT_PRIV_RT_TARGET="No default route"
        [ "$MGMT_PRIV_RT_ID" = "None" ] && MGMT_PRIV_RT_ID=""

        if [ -n "$MGMT_PRIV_RT_ID" ]; then
            printf "%-50s %-25s %-25s\n" "Management VPC Private" "$MGMT_PRIV_RT_ID" "$MGMT_PRIV_RT_TARGET"
        fi
    fi

    # Management VPC public route table
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE"; then
        MGMT_PUB_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-main-route-table" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        MGMT_PUB_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-main-route-table" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$MGMT_PUB_RT_TARGET" ] && MGMT_PUB_RT_TARGET="No default route"
        [ "$MGMT_PUB_RT_ID" = "None" ] && MGMT_PUB_RT_ID=""

        if [ -n "$MGMT_PUB_RT_ID" ]; then
            printf "%-50s %-25s %-25s\n" "Management VPC Public" "$MGMT_PUB_RT_ID" "$MGMT_PUB_RT_TARGET"
        fi
    fi

    # Management TGW attachment route table
    if is_tfvar_true "enable_build_management_vpc" "$TFVARS_FILE" && \
       is_tfvar_true "enable_management_tgw_attachment" "$TFVARS_FILE"; then
        MGMT_TGW_RT_ID=$(aws ec2 describe-transit-gateway-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-management-tgw-rtb" \
            --query 'TransitGatewayRouteTables[0].TransitGatewayRouteTableId' \
            --output text 2>/dev/null)

        if [ -n "$MGMT_TGW_RT_ID" ] && [ "$MGMT_TGW_RT_ID" != "None" ]; then
            MGMT_TGW_TARGET=$(aws ec2 search-transit-gateway-routes \
                --region "$AWS_REGION" \
                --transit-gateway-route-table-id "$MGMT_TGW_RT_ID" \
                --filters "Name=type,Values=static" \
                --query "Routes[?DestinationCidrBlock=='0.0.0.0/0'].TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
                --output text 2>/dev/null)
            [ -z "$MGMT_TGW_TARGET" ] && MGMT_TGW_TARGET="No default route"
            printf "%-50s %-25s %-25s\n" "Management TGW Attachment" "$MGMT_TGW_RT_ID" "$MGMT_TGW_TARGET"
        fi
    fi

    # Inspection VPC private route tables (AZ1 and AZ2)
    for AZ_NUM in 1 2; do
        INSP_PRIV_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-private-az${AZ_NUM}-rtb" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        INSP_PRIV_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-private-az${AZ_NUM}-rtb" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$INSP_PRIV_RT_TARGET" ] && INSP_PRIV_RT_TARGET="No default route"

        if [ -n "$INSP_PRIV_RT_ID" ] && [ "$INSP_PRIV_RT_ID" != "None" ]; then
            printf "%-50s %-25s %-25s\n" "Inspection VPC Private AZ${AZ_NUM}" "$INSP_PRIV_RT_ID" "$INSP_PRIV_RT_TARGET"
        fi
    done

    # Inspection VPC public route tables (AZ1 and AZ2)
    for AZ_NUM in 1 2; do
        INSP_PUB_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-public-rt-az${AZ_NUM}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        INSP_PUB_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-public-rt-az${AZ_NUM}" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        [ -z "$INSP_PUB_RT_TARGET" ] && INSP_PUB_RT_TARGET="No default route"

        if [ -n "$INSP_PUB_RT_ID" ] && [ "$INSP_PUB_RT_ID" != "None" ]; then
            printf "%-50s %-25s %-25s\n" "Inspection VPC Public AZ${AZ_NUM}" "$INSP_PUB_RT_ID" "$INSP_PUB_RT_TARGET"
        fi
    done

    # Inspection VPC NAT Gateway route tables (if they exist)
    for AZ_NUM in 1 2; do
        INSP_NAT_RT_ID=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-natgw-rt-az${AZ_NUM}" \
            --query 'RouteTables[0].RouteTableId' \
            --output text 2>/dev/null)

        INSP_NAT_RT_TARGET=$(aws ec2 describe-route-tables \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=${PREFIX}-inspection-natgw-rt-az${AZ_NUM}" \
            --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0`] | [0].[GatewayId, TransitGatewayId, NatGatewayId, NetworkInterfaceId]' \
            --output text 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i!="None" && $i!="") print $i}' | head -1)

        if [ -n "$INSP_NAT_RT_ID" ] && [ "$INSP_NAT_RT_ID" != "None" ]; then
            [ -z "$INSP_NAT_RT_TARGET" ] && INSP_NAT_RT_TARGET="No default route"
            printf "%-50s %-25s %-25s\n" "Inspection VPC NAT GW AZ${AZ_NUM}" "$INSP_NAT_RT_ID" "$INSP_NAT_RT_TARGET"
        fi
    done

    echo ""

    # Summary of all public IPs
    echo "=========================================="
    echo "ALL PUBLIC IP ADDRESSES"
    echo "=========================================="
    INSTANCES=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[?PublicIpAddress!=null && starts_with(Tags[?Key=='Name'].Value | [0], '${PREFIX}')].[Tags[?Key=='Name'].Value | [0], InstanceId, PrivateIpAddress, PublicIpAddress]" \
        --output text 2>/dev/null)

    if [ -n "$INSTANCES" ]; then
        printf "%-50s %-20s %-15s %-15s\n" "INSTANCE NAME" "INSTANCE ID" "PRIVATE IP" "PUBLIC IP"
        printf "%-50s %-20s %-15s %-15s\n" "-------------" "-----------" "----------" "---------"

        while IFS=$'\t' read -r NAME INSTANCE_ID PRIVATE_IP PUBLIC_IP; do
            printf "%-50s %-20s %-15s %-15s\n" "$NAME" "$INSTANCE_ID" "$PRIVATE_IP" "$PUBLIC_IP"
        done <<< "$INSTANCES"

        echo ""
        INSTANCE_COUNT=$(echo "$INSTANCES" | wc -l | tr -d ' ')
        print_info "Total instances with public IPs: $INSTANCE_COUNT"
    else
        print_info "No instances with public IPs found"
    fi
else
    print_fail "terraform.tfvars not found: $TFVARS_FILE"
fi

echo ""
