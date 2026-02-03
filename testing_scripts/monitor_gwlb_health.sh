#!/bin/bash

# Monitor GWLB Target Group Health
# Standalone script to watch FortiGate instances in GWLB target group

set -e

# Auto-detect region or use provided
REGION="${1:-$(aws configure get region 2>/dev/null || echo 'us-west-2')}"

echo "Using region: $REGION"
echo ""

# Find GWLB target group ARN
TGP_ARN=$(aws elbv2 describe-target-groups --region "$REGION" \
    --query "TargetGroups[?contains(TargetGroupName,'gwlb')].TargetGroupArn" \
    --output text | head -1)

if [ -z "$TGP_ARN" ]; then
    echo "ERROR: No GWLB target group found in region $REGION"
    exit 1
fi

echo "Target Group ARN: $TGP_ARN"
echo ""

while true; do
    clear
    echo "=== GWLB Target Health ==="
    date
    echo ""
    echo "Target Group: $(echo $TGP_ARN | awk -F'/' '{print $2}')"
    echo ""
    printf "%-22s  %-10s  %s\n" "INSTANCE ID" "STATE" "REASON"
    printf "%-22s  %-10s  %s\n" "-----------" "-----" "------"

    # Get target health and display
    aws elbv2 describe-target-health --region "$REGION" \
        --target-group-arn "$TGP_ARN" --output json 2>/dev/null | \
        jq -r '.TargetHealthDescriptions[] | "\(.Target.Id)|\(.TargetHealth.State)|\(.TargetHealth.Reason // "-")"' | \
        while IFS='|' read -r ID STATE REASON; do
            printf "%-22s  %-10s  %s\n" "$ID" "$STATE" "$REASON"
        done

    echo ""
    echo "States: initial -> healthy -> draining -> (removed)"
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 3
done
