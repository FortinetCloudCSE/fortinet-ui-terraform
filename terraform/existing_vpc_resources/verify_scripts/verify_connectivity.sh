#!/bin/bash

# Connectivity Verification Script
# Pings all resources with public IPs to verify network connectivity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Initialize counters
TOTAL_HOSTS=0
REACHABLE_HOSTS=0
UNREACHABLE_HOSTS=0

# Array to track results
declare -a PING_RESULTS

# Function to ping a host
ping_host() {
    local name="$1"
    local ip="$2"

    if [ -z "$ip" ] || [ "$ip" = "null" ]; then
        return 0  # Skip null IPs (resource not enabled)
    fi

    ((TOTAL_HOSTS++))

    echo -n "  Testing $name ($ip)... "

    # Ping with timeout of 2 seconds, 3 attempts
    if ping -c 3 -W 2 "$ip" &>/dev/null; then
        print_pass "REACHABLE"
        ((REACHABLE_HOSTS++))
        PING_RESULTS+=("✓ $name ($ip)")
        return 0
    else
        print_fail "UNREACHABLE"
        ((UNREACHABLE_HOSTS++))
        PING_RESULTS+=("✗ $name ($ip)")
        return 1
    fi
}

# Print header
echo ""
echo "========================================================================"
echo "CONNECTIVITY VERIFICATION - PUBLIC IP PING TEST"
echo "========================================================================"
echo ""

# Source Terraform verification data if available
if [ -f "${SCRIPT_DIR}/terraform_verification_data.sh" ]; then
    print_info "Loading Terraform verification data..."
    source "${SCRIPT_DIR}/terraform_verification_data.sh"
    echo ""
else
    print_warn "Terraform verification data not found. Run ./generate_verification_data.sh first"
    print_warn "Attempting to get IPs directly from Terraform outputs..."
    echo ""

    # Try to get outputs directly
    cd "${SCRIPT_DIR}/.." || exit 1

    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        print_fail "Terraform state not found. Please run terraform apply first."
        exit 1
    fi
fi

# Management VPC Resources
echo "========================================================================"
echo "Management VPC Resources"
echo "========================================================================"
echo ""

# Jump Box
if [ -n "${TF_JUMP_BOX_PUBLIC_IP}" ]; then
    ping_host "Jump Box" "${TF_JUMP_BOX_PUBLIC_IP}"
else
    # Fallback to direct terraform output
    JUMP_IP=$(cd "${SCRIPT_DIR}/.." && terraform output -raw jump_box_public_ip 2>/dev/null)
    if [ -n "$JUMP_IP" ] && [ "$JUMP_IP" != "null" ]; then
        ping_host "Jump Box" "$JUMP_IP"
    else
        print_info "  Jump Box: No public IP (not enabled or private only)"
    fi
fi

# FortiManager
if [ -n "${TF_FMGR_PUBLIC_IP}" ]; then
    ping_host "FortiManager" "${TF_FMGR_PUBLIC_IP}"
else
    FMGR_IP=$(cd "${SCRIPT_DIR}/.." && terraform output -raw fortimanager_public_ip 2>/dev/null)
    if [ -n "$FMGR_IP" ] && [ "$FMGR_IP" != "null" ]; then
        ping_host "FortiManager" "$FMGR_IP"
    else
        print_info "  FortiManager: No public IP (not enabled or private only)"
    fi
fi

# FortiAnalyzer
if [ -n "${TF_FAZ_PUBLIC_IP}" ]; then
    ping_host "FortiAnalyzer" "${TF_FAZ_PUBLIC_IP}"
else
    FAZ_IP=$(cd "${SCRIPT_DIR}/.." && terraform output -raw fortianalyzer_public_ip 2>/dev/null)
    if [ -n "$FAZ_IP" ] && [ "$FAZ_IP" != "null" ]; then
        ping_host "FortiAnalyzer" "$FAZ_IP"
    else
        print_info "  FortiAnalyzer: No public IP (not enabled or private only)"
    fi
fi

echo ""

# Note: Spoke VPC Linux instances do NOT have public IPs
# They are behind the Transit Gateway and only accessible through FortiGate inspection
# Therefore, we do not test connectivity to spoke instances

echo ""

# Print summary
echo "========================================================================"
echo "CONNECTIVITY TEST SUMMARY"
echo "========================================================================"
echo ""
echo "Total Hosts Tested:  $TOTAL_HOSTS"
echo -e "Reachable:           ${GREEN}${REACHABLE_HOSTS}${NC}"
echo -e "Unreachable:         ${RED}${UNREACHABLE_HOSTS}${NC}"
echo ""

# Print detailed results
if [ ${#PING_RESULTS[@]} -gt 0 ]; then
    echo "Detailed Results:"
    for result in "${PING_RESULTS[@]}"; do
        if [[ $result == ✓* ]]; then
            echo -e "  ${GREEN}${result}${NC}"
        else
            echo -e "  ${RED}${result}${NC}"
        fi
    done
    echo ""
fi

# Determine exit code
if [ $TOTAL_HOSTS -eq 0 ]; then
    print_warn "No hosts with public IPs were found to test"
    echo ""
    print_info "This is normal if:"
    print_info "  - Resources are not enabled in terraform.tfvars"
    print_info "  - Resources are configured as private-only (no public IPs)"
    echo ""
    exit 0
elif [ $UNREACHABLE_HOSTS -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}ALL HOSTS REACHABLE${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}SOME HOSTS UNREACHABLE${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    print_info "Troubleshooting steps:"
    print_info "  1. Verify security groups allow ICMP from your IP"
    print_info "  2. Check if instances are running: aws ec2 describe-instances"
    print_info "  3. Verify network ACLs allow ICMP traffic"
    print_info "  4. Check if instances have completed initialization"
    print_info "  5. Verify AWS credentials and region are correct"
    echo ""
    exit 1
fi
