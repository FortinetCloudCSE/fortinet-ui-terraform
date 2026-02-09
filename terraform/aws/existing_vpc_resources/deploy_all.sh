#!/bin/bash

# Full Deployment Script
# Deploys existing_vpc_resources and autoscale_template with verification
# Logs all output to both screen and log file

set -o pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSCALE_DIR="${SCRIPT_DIR}/../autoscale_template"
LOG_FILE="${SCRIPT_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"

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

# Start logging
{
    print_section "FULL DEPLOYMENT PIPELINE"
    print_status "Log file: $LOG_FILE"
    print_status "Starting deployment at $(date)"

    # ============================================
    # PHASE 1: EXISTING VPC RESOURCES
    # ============================================

    print_section "PHASE 1: DEPLOYING EXISTING VPC RESOURCES"
    cd "$SCRIPT_DIR" || exit 1
    print_status "Working directory: $(pwd)"

    # Terraform init
    print_status "Running terraform init..."
    if terraform init; then
        print_success "Terraform init completed"
    else
        print_error "Terraform init failed"
        exit 1
    fi

    # Terraform plan
    print_status "Running terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan completed"
    else
        print_error "Terraform plan failed"
        exit 1
    fi

    # Terraform apply
    print_status "Running terraform apply..."
    if terraform apply -auto-approve tfplan; then
        print_success "Terraform apply completed"
    else
        print_error "Terraform apply failed"
        exit 1
    fi

    # Clean up plan file
    rm -f tfplan

    # ============================================
    # PHASE 2: VERIFICATION
    # ============================================

    print_section "PHASE 2: GENERATING VERIFICATION DATA"

    # Generate verification data
    print_status "Running generate_verification_data.sh..."
    if cd verify_scripts && ./generate_verification_data.sh; then
        print_success "Verification data generated"
    else
        print_warning "Failed to generate verification data (continuing anyway)"
    fi

    # Run verification
    print_status "Running verification tests..."
    if ./verify_all.sh --verify all; then
        print_success "All verification tests passed"
    else
        print_warning "Some verification tests failed (check output above)"
        print_warning "Continuing with autoscale deployment anyway..."
    fi

    # ============================================
    # PHASE 3: AUTOSCALE TEMPLATE
    # ============================================

    print_section "PHASE 3: DEPLOYING AUTOSCALE TEMPLATE"

    # Check if autoscale directory exists
    if [ ! -d "$AUTOSCALE_DIR" ]; then
        print_error "Autoscale directory not found: $AUTOSCALE_DIR"
        exit 1
    fi

    cd "$AUTOSCALE_DIR" || exit 1
    print_status "Working directory: $(pwd)"

    # Terraform init
    print_status "Running terraform init..."
    if terraform init; then
        print_success "Terraform init completed"
    else
        print_error "Terraform init failed"
        exit 1
    fi

    # Terraform plan
    print_status "Running terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan completed"
    else
        print_error "Terraform plan failed"
        exit 1
    fi

    # Terraform apply
    print_status "Running terraform apply..."
    if terraform apply -auto-approve tfplan; then
        print_success "Terraform apply completed"
    else
        print_error "Terraform apply failed"
        exit 1
    fi

    # Clean up plan file
    rm -f tfplan

    # ============================================
    # DEPLOYMENT COMPLETE
    # ============================================

    print_section "DEPLOYMENT COMPLETE"
    print_success "All phases completed successfully!"
    print_status "Ended at $(date)"
    print_status "Log file: $LOG_FILE"

    # Display connection info if available
    cd "$SCRIPT_DIR" || exit 1
    if terraform output connection_info >/dev/null 2>&1; then
        echo ""
        print_section "CONNECTION INFORMATION"
        terraform output connection_info
    fi

} 2>&1 | tee "$LOG_FILE"

exit ${PIPESTATUS[0]}
