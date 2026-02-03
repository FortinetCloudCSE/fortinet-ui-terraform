#!/bin/bash

# Comprehensive Testing Script
# Tests multiple configuration scenarios:
# 1. Default configuration (nat_gw mode with management VPC)
# 2. EIP mode with management VPC
# 3. NAT GW mode without management VPC

set -e
set -o pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="${SCRIPT_DIR}/terraform.tfvars"
TFVARS_BACKUP="${SCRIPT_DIR}/terraform.tfvars.backup"
TEST_LOG="${SCRIPT_DIR}/test_all_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_test_header() {
    echo ""
    echo "██████████████████████████████████████████"
    echo "  TEST SCENARIO: $1"
    echo "██████████████████████████████████████████"
    echo ""
}

# Function to print status messages
print_status() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}[$(date +%H:%M:%S)] ℹ${NC} $1"
}

# Function to backup terraform.tfvars
backup_tfvars() {
    print_status "Backing up terraform.tfvars..."
    cp "$TFVARS_FILE" "$TFVARS_BACKUP"
    print_success "Backup created: $TFVARS_BACKUP"
}

# Function to restore terraform.tfvars
restore_tfvars() {
    print_status "Restoring original terraform.tfvars..."
    cp "$TFVARS_BACKUP" "$TFVARS_FILE"
    print_success "Original configuration restored"
}

# Function to change a variable in terraform.tfvars
change_tfvar() {
    local var_name="$1"
    local new_value="$2"

    print_status "Setting $var_name = $new_value"

    # Use sed to replace the variable value (handles both quoted and unquoted values)
    if [[ "$new_value" == "true" || "$new_value" == "false" ]]; then
        # Boolean values (no quotes)
        sed -i.tmp "s/^${var_name}[[:space:]]*=.*/${var_name} = ${new_value}/" "$TFVARS_FILE"
    else
        # String values (with quotes)
        sed -i.tmp "s/^${var_name}[[:space:]]*=.*/${var_name} = \"${new_value}\"/" "$TFVARS_FILE"
    fi

    rm -f "${TFVARS_FILE}.tmp"
    print_success "Changed $var_name to $new_value"
}

# Function to display current configuration
show_config() {
    print_info "Current configuration:"
    grep "^access_internet_mode" "$TFVARS_FILE" || echo "  access_internet_mode not found"
    grep "^enable_build_management_vpc" "$TFVARS_FILE" || echo "  enable_build_management_vpc not found"
}

# Function to run deploy and destroy cycle
run_test_cycle() {
    local test_name="$1"

    print_test_header "$test_name"
    show_config

    # Deploy
    print_section "DEPLOYING: $test_name"
    if ./deploy_all.sh; then
        print_success "Deploy completed successfully"
    else
        print_error "Deploy failed for: $test_name"
        restore_tfvars
        exit 1
    fi

    # Destroy
    print_section "DESTROYING: $test_name"
    if ./destroy_all.sh; then
        print_success "Destroy completed successfully"
    else
        print_error "Destroy failed for: $test_name"
        restore_tfvars
        exit 1
    fi

    print_success "Test cycle completed: $test_name"
}

# Main test execution
{
    print_section "COMPREHENSIVE INFRASTRUCTURE TESTING"
    print_status "Test log: $TEST_LOG"
    print_status "Starting tests at $(date)"
    echo ""

    # Backup original configuration
    backup_tfvars

    # ============================================
    # TEST 1: Default Configuration
    # ============================================
    run_test_cycle "Test 1: NAT GW Mode with Management VPC (Default)"

    # ============================================
    # TEST 2: EIP Mode
    # ============================================
    print_section "Changing configuration for Test 2..."
    change_tfvar "access_internet_mode" "eip"

    run_test_cycle "Test 2: EIP Mode with Management VPC"

    # Restore nat_gw mode
    print_section "Restoring NAT GW mode..."
    change_tfvar "access_internet_mode" "nat_gw"

    # ============================================
    # TEST 3: Without Management VPC
    # ============================================
    print_section "Changing configuration for Test 3..."
    change_tfvar "enable_build_management_vpc" "false"

    run_test_cycle "Test 3: NAT GW Mode without Management VPC"

    # Restore management VPC
    print_section "Restoring Management VPC setting..."
    change_tfvar "enable_build_management_vpc" "true"

    # ============================================
    # TESTING COMPLETE
    # ============================================

    print_section "ALL TESTS COMPLETE"
    print_success "All test scenarios passed!"
    print_status "Configuration restored to original state"
    print_status "Ended at $(date)"
    print_status "Test log: $TEST_LOG"

    # Show summary
    echo ""
    print_section "TEST SUMMARY"
    echo "✓ Test 1: NAT GW Mode with Management VPC - PASSED"
    echo "✓ Test 2: EIP Mode with Management VPC - PASSED"
    echo "✓ Test 3: NAT GW Mode without Management VPC - PASSED"
    echo ""
    print_info "Original configuration has been restored"

    # Clean up backup
    if [ -f "$TFVARS_BACKUP" ]; then
        rm -f "$TFVARS_BACKUP"
        print_status "Backup file removed"
    fi

} 2>&1 | tee "$TEST_LOG"

exit ${PIPESTATUS[0]}
