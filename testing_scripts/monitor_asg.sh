#!/bin/bash 
#
# Monitor FortiGate Autoscale Group Instances
# Reads configuration from terraform/autoscale_template/terraform.tfvars
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="${SCRIPT_DIR}/terraform/autoscale_template/terraform.tfvars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
WATCH_MODE=false
WATCH_INTERVAL=10
SHOW_POLICY=false
SSH_COMMAND=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Monitor FortiGate instances in the autoscale group"
    echo ""
    echo "Options:"
    echo "  -w, --watch          Continuous monitoring mode (refresh every ${WATCH_INTERVAL}s)"
    echo "  -i, --interval SEC   Set watch interval in seconds (default: ${WATCH_INTERVAL})"
    echo "  -f, --tfvars FILE    Path to terraform.tfvars file"
    echo "  -p, --policy         Show firewall policy on healthy instances"
    echo "  -c, --cmd \"CMD\"      Run custom CLI command on healthy instances"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   # One-time status check"
    echo "  $0 -w                # Watch mode with 10s refresh"
    echo "  $0 -w -i 5           # Watch mode with 5s refresh"
    echo "  $0 -p                # Show firewall policy on healthy instances"
    echo "  $0 -c \"get system status\"  # Run custom command"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -i|--interval)
            WATCH_INTERVAL="$2"
            shift 2
            ;;
        -f|--tfvars)
            TFVARS_FILE="$2"
            shift 2
            ;;
        -p|--policy)
            SHOW_POLICY=true
            shift
            ;;
        -c|--cmd)
            SSH_COMMAND="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if tfvars file exists
if [[ ! -f "$TFVARS_FILE" ]]; then
    echo -e "${RED}Error: terraform.tfvars not found at: ${TFVARS_FILE}${NC}"
    echo "Please deploy the autoscale_template first or specify the file with -f"
    exit 1
fi

# Parse terraform.tfvars to extract values
parse_tfvar() {
    local var_name="$1"
    grep "^${var_name}" "$TFVARS_FILE" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' '
}

AWS_REGION=$(parse_tfvar "aws_region")
ASG_MODULE_PREFIX=$(parse_tfvar "asg_module_prefix")
LICENSE_MODEL=$(parse_tfvar "autoscale_license_model")
FGT_PASSWORD=$(parse_tfvar "fortigate_asg_password")

# Set defaults if not found
AWS_REGION="${AWS_REGION:-us-west-2}"
LICENSE_MODEL="${LICENSE_MODEL:-hybrid}"

# Check for sshpass if policy or command options are used
if [[ "$SHOW_POLICY" == true || -n "$SSH_COMMAND" ]]; then
    if ! command -v sshpass &> /dev/null; then
        echo -e "${RED}Error: sshpass is required for -p/--policy and -c/--cmd options${NC}"
        echo "Install with: brew install hudochenkov/sshpass/sshpass (macOS)"
        exit 1
    fi
    if [[ -z "$FGT_PASSWORD" ]]; then
        echo -e "${RED}Error: Could not parse fortigate_asg_password from ${TFVARS_FILE}${NC}"
        exit 1
    fi
fi

if [[ -z "$ASG_MODULE_PREFIX" ]]; then
    echo -e "${RED}Error: Could not parse asg_module_prefix from ${TFVARS_FILE}${NC}"
    exit 1
fi

# Determine which ASGs to monitor based on license model
declare -a ASG_NAMES
case "$LICENSE_MODEL" in
    hybrid)
        ASG_NAMES=("${ASG_MODULE_PREFIX}-fgt_byol_asg" "${ASG_MODULE_PREFIX}-fgt_on_demand_asg")
        ;;
    byol)
        ASG_NAMES=("${ASG_MODULE_PREFIX}-fgt_byol_asg")
        ;;
    on_demand)
        ASG_NAMES=("${ASG_MODULE_PREFIX}-fgt_on_demand_asg")
        ;;
    *)
        echo -e "${RED}Error: Unknown license model: ${LICENSE_MODEL}${NC}"
        exit 1
        ;;
esac

# Function to get instance status color (handles padded strings)
get_status_color() {
    local val="$1"
    local trimmed="${val%% *}"  # Get first word (removes padding)
    case "$trimmed" in
        running)    echo -e "${GREEN}${val}${NC}" ;;
        pending)    echo -e "${YELLOW}${val}${NC}" ;;
        stopping|stopped|shutting-down|terminated)
                    echo -e "${RED}${val}${NC}" ;;
        *)          echo "$val" ;;
    esac
}

# Function to get health status color (handles padded strings)
get_health_color() {
    local val="$1"
    local trimmed="${val%% *}"  # Get first word (removes padding)
    case "$trimmed" in
        Healthy)    echo -e "${GREEN}${val}${NC}" ;;
        Unhealthy)  echo -e "${RED}${val}${NC}" ;;
        *)          echo -e "${YELLOW}${val}${NC}" ;;
    esac
}

# Function to run SSH command on FortiGate
run_fgt_command() {
    local public_ip="$1"
    local command="$2"
    local timeout="${3:-2}"

    timeout "$timeout" sshpass -p "$FGT_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=2 \
        "admin@${public_ip}" "$command" 2>/dev/null
}

# Array to collect healthy instances with public IPs
declare -a HEALTHY_INSTANCES

# Temp file for GWLB health cache
GWLB_HEALTH_CACHE=""

# Persistent file for tracking instance first-seen timestamps
INSTANCE_TIMESTAMPS_FILE="/tmp/fgt_asg_instance_timestamps.txt"

# Function to get or set instance first-seen timestamp
get_instance_timestamp() {
    local instance_id="$1"
    local role="$2"

    # Only track Secondary instances
    if [[ "$role" != "Secondary" && "$role" != "N/A" ]]; then
        return
    fi

    if [[ -f "$INSTANCE_TIMESTAMPS_FILE" ]]; then
        local existing
        # Use sed to extract everything after "instance_id="
        existing=$(grep "^${instance_id}=" "$INSTANCE_TIMESTAMPS_FILE" 2>/dev/null | sed "s/^${instance_id}=//")
        if [[ -n "$existing" ]]; then
            echo "$existing"
            return
        fi
    fi

    # Record new timestamp for any Secondary/new instance
    local ts=$(date '+%H:%M:%S')
    echo "${instance_id}=${ts}" >> "$INSTANCE_TIMESTAMPS_FILE"
    echo "$ts"
}

# Function to clean up old instance timestamps (instances no longer in ASG)
cleanup_instance_timestamps() {
    if [[ ! -f "$INSTANCE_TIMESTAMPS_FILE" ]]; then
        return
    fi

    local temp_file=$(mktemp)
    while IFS='=' read -r inst_id ts; do
        # Check if instance still exists in any ASG
        if grep -q "^${inst_id}" "$GWLB_HEALTH_CACHE" 2>/dev/null; then
            echo "${inst_id}=${ts}" >> "$temp_file"
        fi
    done < "$INSTANCE_TIMESTAMPS_FILE"
    mv "$temp_file" "$INSTANCE_TIMESTAMPS_FILE"
}

# Function to fetch GWLB target health for all instances
fetch_gwlb_health() {
    GWLB_HEALTH_CACHE=$(mktemp)

    # Find GWLB target groups
    local target_groups
    target_groups=$(aws elbv2 describe-target-groups \
        --region "$AWS_REGION" \
        --query "TargetGroups[?contains(TargetGroupName, '${ASG_MODULE_PREFIX}')].TargetGroupArn" \
        --output text 2>/dev/null)

    if [[ -z "$target_groups" ]]; then
        return
    fi

    for tg_arn in $target_groups; do
        aws elbv2 describe-target-health \
            --region "$AWS_REGION" \
            --target-group-arn "$tg_arn" \
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
            --output text 2>/dev/null >> "$GWLB_HEALTH_CACHE"
    done
}

# Function to get GWLB health for a specific instance
get_instance_gwlb_health() {
    local instance_id="$1"
    if [[ -f "$GWLB_HEALTH_CACHE" ]]; then
        grep "^${instance_id}" "$GWLB_HEALTH_CACHE" | awk '{print $2}' | head -1
    fi
}

# Function to get GWLB health color
get_gwlb_health_color() {
    local val="$1"
    local trimmed="${val%% *}"  # Get first word (removes padding)
    case "$trimmed" in
        healthy)    echo -e "${GREEN}${val}${NC}" ;;
        unhealthy)  echo -e "${RED}${val}${NC}" ;;
        initial)    echo -e "${YELLOW}${val}${NC}" ;;
        draining)   echo -e "${YELLOW}${val}${NC}" ;;
        *)          echo "$val" ;;
    esac
}

# Function to monitor ASG
monitor_asg() {
    local asg_name="$1"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}ASG: ${YELLOW}${asg_name}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Get ASG details
    local asg_info
    asg_info=$(aws autoscaling describe-auto-scaling-groups \
        --region "$AWS_REGION" \
        --auto-scaling-group-names "$asg_name" \
        --query 'AutoScalingGroups[0]' \
        --output json 2>/dev/null)

    if [[ -z "$asg_info" || "$asg_info" == "null" ]]; then
        echo -e "${YELLOW}  ASG not found or not yet created${NC}"
        return
    fi

    # Parse ASG capacity
    local desired=$(echo "$asg_info" | jq -r '.DesiredCapacity')
    local min_size=$(echo "$asg_info" | jq -r '.MinSize')
    local max_size=$(echo "$asg_info" | jq -r '.MaxSize')
    local instance_count=$(echo "$asg_info" | jq -r '.Instances | length')

    echo -e "  Capacity: ${GREEN}${instance_count}${NC} running | Desired: ${desired} | Min: ${min_size} | Max: ${max_size}"
    echo ""

    # Get instance IDs from ASG
    local instance_ids
    instance_ids=$(echo "$asg_info" | jq -r '.Instances[].InstanceId' 2>/dev/null)

    if [[ -z "$instance_ids" ]]; then
        echo -e "  ${YELLOW}No instances in this ASG${NC}"
        return
    fi

    # Get detailed instance info
    echo -e "  ${BLUE}Instances:${NC}"
    printf "  %-20s %-12s %-16s %-16s %-10s %-10s %s\n" "Instance ID" "State" "Private IP" "Public IP" "Health" "Role" "AZ"
    printf "  %-20s %-12s %-16s %-16s %-10s %-10s %s\n" "--------------------" "------------" "----------------" "----------------" "----------" "----------" "----"

    for instance_id in $instance_ids; do
        # Get instance details from EC2
        local instance_info
        instance_info=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0]' \
            --output json 2>/dev/null)

        local state=$(echo "$instance_info" | jq -r '.State.Name')
        local private_ip=$(echo "$instance_info" | jq -r '.PrivateIpAddress // "N/A"')
        local az=$(echo "$instance_info" | jq -r '.Placement.AvailabilityZone' | sed "s/${AWS_REGION}//")
        local role=$(echo "$instance_info" | jq -r '.Tags[] | select(.Key == "Autoscale Role") | .Value // "N/A"')
        role="${role:-N/A}"

        # Get public IP from device index 2 (dedicated management ENI) if present
        # Falls back to device index 0 public IP, then N/A
        local public_ip
        public_ip=$(echo "$instance_info" | jq -r '
            .NetworkInterfaces
            | (map(select(.Attachment.DeviceIndex == 2)) | first // empty)
            | .Association.PublicIp // empty
        ')
        if [[ -z "$public_ip" ]]; then
            # Fallback to primary interface public IP
            public_ip=$(echo "$instance_info" | jq -r '.PublicIpAddress // "N/A"')
        fi

        # Get health status from GWLB target health (more accurate than ASG health)
        local health_status
        health_status=$(get_instance_gwlb_health "$instance_id")
        health_status="${health_status:-pending}"

        # Get timestamp for Secondary instances
        local timestamp=""
        timestamp=$(get_instance_timestamp "$instance_id" "$role")

        # Format output with colors (pad to fixed width before adding color)
        local state_padded=$(printf "%-12s" "$state")
        local health_padded=$(printf "%-10s" "$health_status")
        local role_padded=$(printf "%-10s" "$role")

        # Color the role (Primary=green, Secondary=yellow)
        local role_colored
        case "$role" in
            Primary)   role_colored="${GREEN}${role_padded}${NC}" ;;
            Secondary) role_colored="${YELLOW}${role_padded}${NC}" ;;
            *)         role_colored="$role_padded" ;;
        esac

        # Build timestamp display
        local ts_display=""
        if [[ -n "$timestamp" ]]; then
            ts_display="@${timestamp}"
        fi

        printf "  %-20s %b %-16s %-16s %b %b %s %s\n" \
            "$instance_id" \
            "$(get_status_color "$state_padded")" \
            "$private_ip" \
            "$public_ip" \
            "$(get_gwlb_health_color "$health_padded")" \
            "$role_colored" \
            "$az" \
            "$ts_display"

        # Collect instances with public IPs for SSH commands (include role and health)
        if [[ "$public_ip" != "N/A" && -n "$public_ip" ]]; then
            HEALTHY_INSTANCES+=("${instance_id}:${public_ip}:${role}:${health_status}")
        fi
    done

    echo ""
}

# Function to show GWLB target health
show_gwlb_health() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}GWLB Target Group Health${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Find GWLB target groups
    local target_groups
    target_groups=$(aws elbv2 describe-target-groups \
        --region "$AWS_REGION" \
        --query "TargetGroups[?contains(TargetGroupName, '${ASG_MODULE_PREFIX}')].TargetGroupArn" \
        --output text 2>/dev/null)

    if [[ -z "$target_groups" ]]; then
        echo -e "  ${YELLOW}No GWLB target groups found${NC}"
        return
    fi

    for tg_arn in $target_groups; do
        local tg_name=$(echo "$tg_arn" | sed 's/.*targetgroup\///' | cut -d'/' -f1)
        echo -e "  ${BLUE}Target Group: ${YELLOW}${tg_name}${NC}"

        local health_info
        health_info=$(aws elbv2 describe-target-health \
            --region "$AWS_REGION" \
            --target-group-arn "$tg_arn" \
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
            --output text 2>/dev/null)

        if [[ -z "$health_info" ]]; then
            echo -e "    ${YELLOW}No targets registered${NC}"
        else
            printf "    %-20s %-12s %s\n" "Instance" "State" "Reason"
            printf "    %-20s %-12s %s\n" "--------------------" "------------" "------"
            echo "$health_info" | while read -r instance state reason; do
                local state_color
                case "$state" in
                    healthy)    state_color="${GREEN}${state}${NC}" ;;
                    unhealthy)  state_color="${RED}${state}${NC}" ;;
                    initial)    state_color="${YELLOW}${state}${NC}" ;;
                    *)          state_color="$state" ;;
                esac
                printf "    %-20s %-22b %s\n" "$instance" "$state_color" "${reason:-N/A}"
            done
        fi
        echo ""
    done
}

# Function to show firewall policy or run custom command on healthy instances
show_fgt_commands() {
    if [[ ${#HEALTHY_INSTANCES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}  No healthy instances with public IPs found${NC}"
        return
    fi

    local cmd_to_run=""
    local cmd_label=""
    local secondary_only=false

    if [[ "$SHOW_POLICY" == true ]]; then
        cmd_to_run="show firewall policy 2"
        cmd_label="Firewall Policy (Rule 2) - Secondary Instances Only"
        secondary_only=true
    elif [[ -n "$SSH_COMMAND" ]]; then
        cmd_to_run="$SSH_COMMAND"
        cmd_label="Command: $SSH_COMMAND"
    else
        return
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${cmd_label}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local found_secondary=false
    for instance_info in "${HEALTHY_INSTANCES[@]}"; do
        # Parse instance_id:public_ip:role:health
        local instance_id="${instance_info%%:*}"
        local remainder="${instance_info#*:}"
        local public_ip="${remainder%%:*}"
        remainder="${remainder#*:}"
        local role="${remainder%%:*}"
        local health="${remainder##*:}"

        # Skip non-secondary instances for policy display
        if [[ "$secondary_only" == true && "$role" != "Secondary" ]]; then
            continue
        fi

        # For custom commands, only run on healthy instances
        if [[ "$secondary_only" == false && "$health" != "healthy" ]]; then
            continue
        fi

        found_secondary=true

        echo -e "\n  ${BLUE}Instance: ${YELLOW}${instance_id}${NC} (${public_ip}) [${role}] [${health}]"
        echo -e "  ${CYAN}────────────────────────────────────────────────────────────────────────────${NC}"

        local output
        local exit_code=0
        output=$(run_fgt_command "$public_ip" "$cmd_to_run" 2>&1) || exit_code=$?

        if [[ $exit_code -eq 0 && -n "$output" ]]; then
            echo "$output" | sed 's/^/  /'
        else
            echo -e "  ${RED}Failed to connect or run command (timeout or not ready)${NC}"
        fi
    done

    if [[ "$secondary_only" == true && "$found_secondary" == false ]]; then
        echo -e "\n  ${YELLOW}No secondary instances found - waiting for scale-out...${NC}"
    fi
    echo ""
}

# Main display function
display_status() {
    clear

    # Reset healthy instances array
    HEALTHY_INSTANCES=()

    # Fetch GWLB target health for all instances (more accurate than ASG health)
    fetch_gwlb_health

    # Clean up timestamps for instances no longer in ASG
    cleanup_instance_timestamps

    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          FortiGate Autoscale Group Monitor                                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Region: ${YELLOW}${AWS_REGION}${NC}  |  License Model: ${YELLOW}${LICENSE_MODEL}${NC}  |  Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Monitor each ASG
    for asg_name in "${ASG_NAMES[@]}"; do
        monitor_asg "$asg_name"
    done

    # Show GWLB target health
    show_gwlb_health

    # Show firewall policy or custom command on healthy instances
    if [[ "$SHOW_POLICY" == true || -n "$SSH_COMMAND" ]]; then
        show_fgt_commands
    fi

    # Cleanup temp file
    if [[ -f "$GWLB_HEALTH_CACHE" ]]; then
        rm -f "$GWLB_HEALTH_CACHE"
    fi

    if [[ "$WATCH_MODE" == true ]]; then
        echo -e "${CYAN}Refreshing every ${WATCH_INTERVAL}s... Press Ctrl+C to exit${NC}"
    fi
}

# Main execution
if [[ "$WATCH_MODE" == true ]]; then
    while true; do
        display_status
        sleep "$WATCH_INTERVAL"
    done
else
    display_status
fi
