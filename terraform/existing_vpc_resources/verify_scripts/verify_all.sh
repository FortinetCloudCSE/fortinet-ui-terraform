#!/bin/bash

# Master Verification Script for AWS Infrastructure
# This script can verify individual components or all components at once

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_functions.sh"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Verify AWS infrastructure components created by Terraform

OPTIONS:
    --verify all               Run all verification scripts
    --verify management        Verify Management VPC only
    --verify inspection        Verify Inspection VPC only
    --verify east              Verify East VPC only
    --verify west              Verify West VPC only
    --verify spoke             Verify both East and West VPCs
    --verify distributed       Verify Distributed VPCs only
    --verify connectivity      Test ping connectivity to all public IPs
    -h, --help                 Show this help message

EXAMPLES:
    $(basename "$0") --verify all
        Run all verification scripts

    $(basename "$0") --verify management
        Verify only the Management VPC

    $(basename "$0") --verify spoke
        Verify both East and West spoke VPCs

    $(basename "$0") --verify distributed
        Verify Distributed VPCs (not attached to TGW)

    $(basename "$0") --verify connectivity
        Test ping connectivity to all resources with public IPs

EOF
    exit 0
}

# Initialize variables
VERIFY_ALL=false
VERIFY_MANAGEMENT=false
VERIFY_INSPECTION=false
VERIFY_EAST=false
VERIFY_WEST=false
VERIFY_DISTRIBUTED=false
VERIFY_CONNECTIVITY=false

# Parse command line arguments
if [ $# -eq 0 ]; then
    usage
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --verify)
            case "$2" in
                all)
                    VERIFY_ALL=true
                    ;;
                management)
                    VERIFY_MANAGEMENT=true
                    ;;
                inspection)
                    VERIFY_INSPECTION=true
                    ;;
                east)
                    VERIFY_EAST=true
                    ;;
                west)
                    VERIFY_WEST=true
                    ;;
                spoke)
                    VERIFY_EAST=true
                    VERIFY_WEST=true
                    ;;
                distributed)
                    VERIFY_DISTRIBUTED=true
                    ;;
                connectivity)
                    VERIFY_CONNECTIVITY=true
                    ;;
                *)
                    echo "Error: Unknown verification target: $2"
                    usage
                    ;;
            esac
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            ;;
    esac
done

# Set all flags if verify all is specified
if [ "$VERIFY_ALL" = true ]; then
    VERIFY_MANAGEMENT=true
    VERIFY_INSPECTION=true
    VERIFY_EAST=true
    VERIFY_WEST=true
    VERIFY_DISTRIBUTED=true
    VERIFY_CONNECTIVITY=true
fi

# Track overall results
OVERALL_EXIT_CODE=0
SCRIPTS_RUN=0
SCRIPTS_PASSED=0
SCRIPTS_FAILED=0

# Function to run a verification script
run_verification() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"

    if [ ! -f "$script_path" ]; then
        print_fail "Verification script not found: $script_name"
        return 1
    fi

    if [ ! -x "$script_path" ]; then
        chmod +x "$script_path"
    fi

    echo ""
    echo "========================================================================"
    echo "Running: $script_name"
    echo "========================================================================"
    echo ""

    ((SCRIPTS_RUN++))

    bash "$script_path"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        ((SCRIPTS_PASSED++))
        echo ""
        print_pass "$script_name completed successfully"
    else
        ((SCRIPTS_FAILED++))
        OVERALL_EXIT_CODE=1
        echo ""
        print_fail "$script_name failed with exit code: $exit_code"
    fi

    return $exit_code
}

# Print header
echo ""
echo "========================================================================"
echo "AWS INFRASTRUCTURE VERIFICATION"
echo "========================================================================"
echo ""
print_info "Starting verification process..."
print_info "Script directory: $SCRIPT_DIR"
echo ""

# Run verification scripts based on flags
if [ "$VERIFY_MANAGEMENT" = true ]; then
    run_verification "verify_management_vpc.sh"
fi

if [ "$VERIFY_INSPECTION" = true ]; then
    run_verification "verify_inspection_vpc.sh"
fi

if [ "$VERIFY_EAST" = true ]; then
    run_verification "verify_east_vpc.sh"
fi

if [ "$VERIFY_WEST" = true ]; then
    run_verification "verify_west_vpc.sh"
fi

if [ "$VERIFY_DISTRIBUTED" = true ]; then
    run_verification "verify_distributed_vpcs.sh"
fi

if [ "$VERIFY_CONNECTIVITY" = true ]; then
    run_verification "verify_connectivity.sh"
fi

# Print overall summary
echo ""
echo "========================================================================"
echo "OVERALL VERIFICATION SUMMARY"
echo "========================================================================"
echo ""
echo "Scripts Run:    $SCRIPTS_RUN"
echo -e "Scripts Passed: ${GREEN}${SCRIPTS_PASSED}${NC}"
echo -e "Scripts Failed: ${RED}${SCRIPTS_FAILED}${NC}"
echo ""

if [ $OVERALL_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}ALL VERIFICATIONS PASSED${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}SOME VERIFICATIONS FAILED${NC}"
    echo -e "${RED}========================================${NC}"
fi
echo ""

# Display comprehensive resource summary
echo "========================================================================"
echo "INFRASTRUCTURE RESOURCE SUMMARY"
echo "========================================================================"
echo ""

# Call verify_summary.sh to display infrastructure summary
"${SCRIPT_DIR}/verify_summary.sh"

echo ""
echo "========================================================================"

# Generate network diagram
echo ""
echo "========================================================================"
echo "GENERATING NETWORK DIAGRAM"
echo "========================================================================"
echo ""

if [ -x "${SCRIPT_DIR}/generate_network_diagram.sh" ]; then
    "${SCRIPT_DIR}/generate_network_diagram.sh"
else
    print_info "Network diagram generator not found or not executable"
fi

echo ""
echo "========================================================================"

exit $OVERALL_EXIT_CODE
