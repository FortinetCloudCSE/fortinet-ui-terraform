#!/bin/bash

# REBUILD_AUTOSCALE_GROUP.sh - Complete teardown and rebuild of infrastructure
# This script destroys all resources and rebuilds them from scratch
#
# SAFETY: This script ensures autoscale_template is FULLY destroyed before
# touching existing_vpc_resources, preventing state sync issues.
#
# Usage:
#   ./REBUILD_AUTOSCALE_GROUP.sh                 # Full teardown and rebuild
#   ./REBUILD_AUTOSCALE_GROUP.sh --teardown-only # Only destroy resources
#   ./REBUILD_AUTOSCALE_GROUP.sh --build-only    # Only build resources
#
# Workflow for modifying terraform.tfvars between runs:
#   ./REBUILD_AUTOSCALE_GROUP.sh --teardown-only
#   # Edit terraform.tfvars as needed
#   ./REBUILD_AUTOSCALE_GROUP.sh --build-only

# Parse command line arguments
DO_TEARDOWN=true
DO_BUILD=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --teardown-only)
            DO_TEARDOWN=true
            DO_BUILD=false
            shift
            ;;
        --build-only)
            DO_TEARDOWN=false
            DO_BUILD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --teardown-only  Only destroy resources (no rebuild)"
            echo "  --build-only     Only build resources (skip teardown)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "With no options, performs full teardown and rebuild."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGS_DIR="${SCRIPT_DIR}/logs"
AUTOSCALE_DIR="${SCRIPT_DIR}/terraform/autoscale_template"
EXISTING_VPC_DIR="${SCRIPT_DIR}/terraform/existing_vpc_resources"

# Timestamps
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

print_header() {
    echo ""
    echo -e "${BLUE}========================================================================"
    echo -e "$1"
    echo -e "========================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to get resource count from terraform state
get_resource_count() {
    local dir="$1"
    cd "$dir"
    if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
        terraform state list 2>/dev/null | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

# Function to check if directory has terraform initialized
is_terraform_initialized() {
    local dir="$1"
    [ -d "${dir}/.terraform" ]
}

# Function to safely destroy with verification
safe_destroy() {
    local dir="$1"
    local name="$2"
    local max_retries=3
    local retry=0

    cd "$dir"

    # Check current resource count
    local resource_count=$(get_resource_count "$dir")

    if [ "$resource_count" -eq 0 ]; then
        print_info "$name has no resources in state, skipping destroy"
        return 0
    fi

    print_info "$name has $resource_count resources to destroy"

    while [ $retry -lt $max_retries ]; do
        print_step "Running terraform destroy (attempt $((retry + 1))/$max_retries)..."

        if terraform destroy -auto-approve; then
            # Verify destruction
            resource_count=$(get_resource_count "$dir")
            if [ "$resource_count" -eq 0 ]; then
                print_success "$name - All resources destroyed successfully"
                return 0
            else
                print_warning "$name still has $resource_count resources after destroy"
                retry=$((retry + 1))
            fi
        else
            print_error "terraform destroy failed for $name"
            retry=$((retry + 1))
        fi

        if [ $retry -lt $max_retries ]; then
            print_info "Retrying in 10 seconds..."
            sleep 10
        fi
    done

    # Failed after all retries
    print_error "$name destroy failed after $max_retries attempts"
    resource_count=$(get_resource_count "$dir")
    if [ "$resource_count" -gt 0 ]; then
        print_error "Remaining resources in state:"
        terraform state list
    fi
    return 1
}

# Function to safely apply with verification
safe_apply() {
    local dir="$1"
    local name="$2"

    cd "$dir"

    # Initialize if needed
    if ! is_terraform_initialized "$dir"; then
        print_step "Running terraform init..."
        if ! terraform init; then
            print_error "terraform init failed for $name"
            return 1
        fi
    fi

    print_step "Running terraform apply..."
    if terraform apply -auto-approve; then
        local resource_count=$(get_resource_count "$dir")
        if [ "$resource_count" -gt 0 ]; then
            print_success "$name - $resource_count resources created"
            return 0
        else
            print_error "$name - No resources in state after apply"
            return 1
        fi
    else
        print_error "terraform apply failed for $name"
        return 1
    fi
}

# Function to prompt user for confirmation
confirm_proceed() {
    local message="$1"
    echo ""
    print_warning "$message"
    read -p "Do you want to proceed? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        print_info "Aborting."
        exit 1
    fi
}

#=============================================================================
# MAIN SCRIPT
#=============================================================================

# Determine mode string for display
if [ "$DO_TEARDOWN" = true ] && [ "$DO_BUILD" = true ]; then
    MODE_STRING="FULL REBUILD"
elif [ "$DO_TEARDOWN" = true ]; then
    MODE_STRING="TEARDOWN ONLY"
else
    MODE_STRING="BUILD ONLY"
fi

print_header "REBUILD AUTOSCALE GROUP SCRIPT - ${MODE_STRING}"
echo "Start Time: $START_TIME"
echo "Repository: $SCRIPT_DIR"
echo "Mode:       $MODE_STRING"
echo ""

#-----------------------------------------------------------------------------
# PRE-FLIGHT CHECKS
#-----------------------------------------------------------------------------
print_header "PRE-FLIGHT CHECKS"

# Check that terraform.tfvars exists in both directories
if [ ! -f "${EXISTING_VPC_DIR}/terraform.tfvars" ]; then
    print_error "Missing terraform.tfvars in existing_vpc_resources"
    print_info "Please ensure terraform.tfvars is configured before running this script"
    exit 1
fi
print_success "existing_vpc_resources/terraform.tfvars exists"

if [ ! -f "${AUTOSCALE_DIR}/terraform.tfvars" ]; then
    print_error "Missing terraform.tfvars in autoscale_template"
    print_info "Please ensure terraform.tfvars is configured before running this script"
    exit 1
fi
print_success "autoscale_template/terraform.tfvars exists"

# Show current state
AUTOSCALE_COUNT=$(get_resource_count "$AUTOSCALE_DIR")
EXISTING_COUNT=$(get_resource_count "$EXISTING_VPC_DIR")

echo ""
print_info "Current State:"
echo "  autoscale_template:     $AUTOSCALE_COUNT resources"
echo "  existing_vpc_resources: $EXISTING_COUNT resources"
echo ""

#-----------------------------------------------------------------------------
# TEARDOWN PHASE
#-----------------------------------------------------------------------------
if [ "$DO_TEARDOWN" = true ]; then

#-----------------------------------------------------------------------------
# STEP 1: Clear logs directory
#-----------------------------------------------------------------------------
print_header "STEP 1: CLEARING LOGS DIRECTORY"

if [ -d "$LOGS_DIR" ]; then
    print_step "Removing contents of $LOGS_DIR"
    rm -rf "${LOGS_DIR:?}"/*
    touch "$LOGS_DIR/.gitkeep"
    print_success "Logs directory cleared"
else
    mkdir -p "$LOGS_DIR"
    touch "$LOGS_DIR/.gitkeep"
    print_success "Logs directory created"
fi

#-----------------------------------------------------------------------------
# STEP 2: Destroy autoscale_template (MUST complete before continuing)
#-----------------------------------------------------------------------------
print_header "STEP 2: DESTROYING AUTOSCALE_TEMPLATE"
print_warning "This must complete successfully before destroying existing_vpc_resources"
echo ""

cd "$AUTOSCALE_DIR"
print_step "Working directory: $AUTOSCALE_DIR"

if ! safe_destroy "$AUTOSCALE_DIR" "autoscale_template"; then
    print_error "=========================================="
    print_error "CRITICAL: autoscale_template destroy failed!"
    print_error "=========================================="
    print_error ""
    print_error "The autoscale_template could not be fully destroyed."
    print_error "DO NOT manually destroy existing_vpc_resources or you will"
    print_error "break the state and make recovery very difficult."
    print_error ""
    print_error "Recommended actions:"
    print_error "  1. Check AWS Console for any stuck resources"
    print_error "  2. Try running: cd $AUTOSCALE_DIR && terraform destroy"
    print_error "  3. If resources are already gone, run: terraform state rm <resource>"
    print_error ""
    exit 1
fi

# Double-check autoscale_template is empty before proceeding
AUTOSCALE_COUNT=$(get_resource_count "$AUTOSCALE_DIR")
if [ "$AUTOSCALE_COUNT" -gt 0 ]; then
    print_error "autoscale_template still has $AUTOSCALE_COUNT resources!"
    print_error "Cannot proceed to destroy existing_vpc_resources"
    exit 1
fi

print_success "autoscale_template fully destroyed - safe to proceed"

#-----------------------------------------------------------------------------
# STEP 3: Destroy existing_vpc_resources
#-----------------------------------------------------------------------------
print_header "STEP 3: DESTROYING EXISTING_VPC_RESOURCES"

cd "$EXISTING_VPC_DIR"
print_step "Working directory: $EXISTING_VPC_DIR"

if ! safe_destroy "$EXISTING_VPC_DIR" "existing_vpc_resources"; then
    print_error "existing_vpc_resources destroy failed!"
    print_error ""
    print_error "Check AWS Console for stuck resources."
    print_error "You may need to manually delete resources and update terraform state."
    exit 1
fi

print_success "All infrastructure destroyed"

fi # End of TEARDOWN PHASE

#-----------------------------------------------------------------------------
# BUILD PHASE
#-----------------------------------------------------------------------------
if [ "$DO_BUILD" = true ]; then

#-----------------------------------------------------------------------------
# STEP 4: Apply existing_vpc_resources
#-----------------------------------------------------------------------------
print_header "STEP 4: APPLYING EXISTING_VPC_RESOURCES"

cd "$EXISTING_VPC_DIR"
print_step "Working directory: $EXISTING_VPC_DIR"

if ! safe_apply "$EXISTING_VPC_DIR" "existing_vpc_resources"; then
    print_error "existing_vpc_resources apply failed!"
    print_error ""
    print_error "Check the error messages above."
    print_error "You may need to fix issues and run: terraform apply"
    exit 1
fi

#-----------------------------------------------------------------------------
# STEP 5: Clean up stale CloudWatch log groups
#-----------------------------------------------------------------------------
print_header "STEP 5: CLEANING UP STALE CLOUDWATCH LOG GROUPS"

cd "$AUTOSCALE_DIR"

# Get region and module prefix from terraform.tfvars
AWS_REGION=$(grep '^aws_region' terraform.tfvars | sed 's/.*=.*"\(.*\)".*/\1/' | tr -d ' ')
MODULE_PREFIX=$(grep '^asg_module_prefix' terraform.tfvars | sed 's/.*=.*"\(.*\)".*/\1/' | tr -d ' ')

print_info "Region: $AWS_REGION"
print_info "Module prefix: $MODULE_PREFIX"

# Delete lambda log groups that match the pattern
for LOG_GROUP in "/aws/lambda/${MODULE_PREFIX}-fgt_byol_asg_fgt-asg-lambda" "/aws/lambda/${MODULE_PREFIX}-fgt_byol_asg_fgt-asg-lambda-internal"; do
    print_step "Deleting log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION" 2>/dev/null && \
        print_success "Deleted: $LOG_GROUP" || \
        print_info "Log group not found or already deleted: $LOG_GROUP"
done

#-----------------------------------------------------------------------------
# STEP 6: Apply autoscale_template
#-----------------------------------------------------------------------------
print_header "STEP 6: APPLYING AUTOSCALE_TEMPLATE"

cd "$AUTOSCALE_DIR"
print_step "Working directory: $AUTOSCALE_DIR"

if ! safe_apply "$AUTOSCALE_DIR" "autoscale_template"; then
    print_error "autoscale_template apply failed!"
    print_error ""
    print_error "existing_vpc_resources was successfully created."
    print_error "Check the error messages and run: terraform apply"
    exit 1
fi

#-----------------------------------------------------------------------------
# STEP 7: Regenerate verification cache and wait for AWS propagation
#-----------------------------------------------------------------------------
print_header "STEP 7: REGENERATING VERIFICATION CACHE"

cd "$EXISTING_VPC_DIR"
print_step "Regenerating terraform verification data..."
if ./verify_scripts/generate_verification_data.sh > /dev/null 2>&1; then
    print_success "Verification cache regenerated"
else
    print_warning "Could not regenerate verification cache (will use AWS CLI fallback)"
fi

print_info "Waiting 5 minutes for AWS resources to fully propagate..."
print_info "This ensures accurate verification results."
for i in {5..1}; do
    echo -ne "\r  Time remaining: ${i} minute(s)...  "
    sleep 60
done
echo ""
print_success "Wait complete"

#-----------------------------------------------------------------------------
# STEP 8: Run verification and generate network diagram
#-----------------------------------------------------------------------------
print_header "STEP 8: RUNNING VERIFICATION AND GENERATING NETWORK DIAGRAM"

cd "$EXISTING_VPC_DIR"
print_step "Working directory: $EXISTING_VPC_DIR"

print_step "Running verify_all.sh..."
if ./verify_scripts/verify_all.sh --verify all; then
    print_success "Verification completed"
else
    print_warning "Verification completed with some warnings"
fi

fi # End of BUILD PHASE

#-----------------------------------------------------------------------------
# COMPLETE
#-----------------------------------------------------------------------------
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

print_header "${MODE_STRING} COMPLETE"
echo "Start Time: $START_TIME"
echo "End Time:   $END_TIME"
echo ""

if [ "$DO_BUILD" = true ]; then
    echo "Logs and diagrams available in: $LOGS_DIR"
    echo ""
fi

# Show summary of resources
print_info "Resource Summary:"
echo ""
echo "existing_vpc_resources:"
cd "$EXISTING_VPC_DIR"
terraform state list 2>/dev/null | wc -l | xargs -I {} echo "  {} resources"

echo ""
echo "autoscale_template:"
cd "$AUTOSCALE_DIR"
terraform state list 2>/dev/null | wc -l | xargs -I {} echo "  {} resources"

echo ""

# Mode-specific completion messages
if [ "$DO_TEARDOWN" = true ] && [ "$DO_BUILD" = true ]; then
    print_success "Autoscale group rebuild completed successfully!"
elif [ "$DO_TEARDOWN" = true ]; then
    print_success "Teardown completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Edit terraform.tfvars files as needed"
    echo "  2. Run: $0 --build-only"
else
    print_success "Build completed successfully!"
fi
