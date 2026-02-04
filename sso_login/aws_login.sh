#!/bin/bash

# AWS SSO Login Script with UI Backend Integration
#
# Usage:
#   aws_login.sh [profile] [backend_url]
#
# Examples:
#   aws_login.sh                              # Use default profile, local backend
#   aws_login.sh my_profile                      # Specific profile, local backend
#   aws_login.sh my_profile http://remote:8000   # Specific profile, remote backend
#
# The script will:
#   1. Perform AWS SSO login
#   2. Export credentials to local environment (for CLI use)
#   3. POST credentials to UI backend (if reachable)

# Default profile and backend URL
DEFAULT_PROFILE="my_profile"
DEFAULT_BACKEND_URL="http://127.0.0.1:8000"

# Use arguments or fallback to defaults
PROFILE_NAME="${1:-$DEFAULT_PROFILE}"
BACKEND_URL="${2:-$DEFAULT_BACKEND_URL}"

# ANSI colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

echo -e "${YELLOW}🔐 Logging in to AWS SSO with profile: $PROFILE_NAME${NC}"

# Perform AWS SSO login
if aws sso login --profile "$PROFILE_NAME"; then
    echo -e "${GREEN}✅ SSO login successful.${NC}"

    # Export credentials to local environment (for AWS CLI use)
    if CREDENTIALS=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env); then
        eval "$CREDENTIALS"
        echo -e "${GREEN}✅ Credentials exported to local environment for profile: $PROFILE_NAME${NC}"

        # Also get credentials for posting to backend
        ACCESS_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_ACCESS_KEY_ID | cut -d= -f2)
        SECRET_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SECRET_ACCESS_KEY | cut -d= -f2)
        SESSION_TOKEN=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SESSION_TOKEN | cut -d= -f2)

        # Try to POST credentials to UI backend
        echo -e "${CYAN}📤 Sending credentials to UI backend at $BACKEND_URL...${NC}"

        # Build JSON payload
        JSON_PAYLOAD=$(cat <<EOF
{
    "access_key": "$ACCESS_KEY",
    "secret_key": "$SECRET_KEY",
    "session_token": "$SESSION_TOKEN"
}
EOF
)

        # POST to backend (with timeout to handle unreachable backend gracefully)
        RESPONSE=$(curl -s -m 5 -X POST "${BACKEND_URL}/api/aws/credentials/set" \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" 2>&1)
        CURL_EXIT=$?

        if [ $CURL_EXIT -eq 0 ] && echo "$RESPONSE" | grep -q '"valid".*true'; then
            ACCOUNT=$(echo "$RESPONSE" | grep -o '"account"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            echo -e "${GREEN}✅ Credentials sent to UI backend (Account: $ACCOUNT)${NC}"
        elif [ $CURL_EXIT -eq 28 ] || [ $CURL_EXIT -eq 7 ]; then
            echo -e "${YELLOW}⚠️  UI backend not reachable at $BACKEND_URL (credentials set locally only)${NC}"
        else
            echo -e "${YELLOW}⚠️  Failed to set credentials in UI backend: $RESPONSE${NC}"
        fi

        echo ""
        echo -e "${GREEN}✅ Ready to use AWS CLI and UI${NC}"

    else
        echo -e "${RED}⚠️ Failed to export credentials for profile: $PROFILE_NAME${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ AWS SSO login failed for profile: $PROFILE_NAME${NC}"
    exit 1
fi
