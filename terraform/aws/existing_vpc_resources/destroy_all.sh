#!/bin/bash

# Full Destroy Script
# Destroys autoscale_template and existing_vpc_resources in reverse order
# Appends output to the newest deployment log file

set -o pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSCALE_DIR="${SCRIPT_DIR}/../autoscale_template"

# Find the newest deployment log file
NEWEST_LOG=$(ls -t "${SCRIPT_DIR}"/deployment_*.log 2>/dev/null | head -1)

if [ -z "$NEWEST_LOG" ]; then
    # No existing log found, create a new one
    LOG_FILE="${SCRIPT_DIR}/destroy_$(date +%Y%m%d_%H%M%S).log"
    echo "No existing deployment log found, creating new log: $LOG_FILE"
else
    LOG_FILE="$NEWEST_LOG"
    echo "Appending to existing log: $LOG_FILE"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
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

# Start logging (append mode)
{
    print_section "FULL DESTROY PIPELINE"
    print_status "Log file: $LOG_FILE"
    print_status "Starting destroy at $(date)"
    print_warning "This will destroy all infrastructure!"
    echo ""

    # ============================================
    # PHASE 1: DESTROY AUTOSCALE TEMPLATE
    # ============================================

    print_section "PHASE 1: DESTROYING AUTOSCALE TEMPLATE"

    # Check if autoscale directory exists
    if [ ! -d "$AUTOSCALE_DIR" ]; then
        print_warning "Autoscale directory not found: $AUTOSCALE_DIR (skipping)"
    else
        cd "$AUTOSCALE_DIR" || exit 1
        print_status "Working directory: $(pwd)"

        # Check if terraform state exists
        if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
            print_warning "No terraform state found in autoscale_template (skipping)"
        else
            # Terraform destroy
            print_status "Running terraform destroy..."
            if terraform destroy -auto-approve; then
                print_success "Autoscale template destroyed"
            else
                print_error "Terraform destroy failed"
                print_warning "Continuing with existing_vpc_resources destroy anyway..."
            fi
        fi
    fi

    # ============================================
    # PHASE 2: DESTROY EXISTING VPC RESOURCES
    # ============================================

    print_section "PHASE 2: DESTROYING EXISTING VPC RESOURCES"

    cd "$SCRIPT_DIR" || exit 1
    print_status "Working directory: $(pwd)"

    # Check if terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        print_warning "No terraform state found in existing_vpc_resources"
        print_error "Nothing to destroy"
        exit 1
    fi

    # Terraform destroy
    print_status "Running terraform destroy..."
    if terraform destroy -auto-approve; then
        print_success "Existing VPC resources destroyed"
    else
        print_error "Terraform destroy failed"
        exit 1
    fi

    # Clean up generated verification data
    print_status "Cleaning up generated verification data..."
    if [ -f "verify_scripts/terraform_verification_data.sh" ]; then
        rm -f verify_scripts/terraform_verification_data.sh
        print_success "Verification data cleaned up"
    fi

    # ============================================
    # DESTROY COMPLETE
    # ============================================

    print_section "DESTROY COMPLETE"
    print_success "All infrastructure has been destroyed!"
    print_status "Ended at $(date)"
    print_status "Log file: $LOG_FILE"

} 2>&1 | tee -a "$LOG_FILE"

exit ${PIPESTATUS[0]}
