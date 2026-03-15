#!/bin/bash
#
# OpenClaw Quick Status Script
# Shows CloudFormation stacks, EC2 instances, and Gateway status at a glance
#
# Usage: ./quick-status.sh [region]
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REGION="${1:-$(aws configure get region 2>/dev/null || echo "us-west-2")}"
STACKS=("openclaw-bedrock" "openclaw-test1")

echo ""
echo -e "${BOLD}🦞 OpenClaw Quick Status${NC}  (region: ${CYAN}${REGION}${NC})"
echo "════════════════════════════════════════"

# --- CloudFormation Stacks ---
echo ""
echo -e "${BOLD}📦 CloudFormation Stacks${NC}"
echo "────────────────────────"

for STACK in "${STACKS[@]}"; do
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK" --region "$REGION" \
        --query 'Stacks[0].StackStatus' --output text 2>/dev/null)

    if [ -z "$STATUS" ] || [ "$STATUS" = "None" ]; then
        echo -e "  ⚫ ${BOLD}${STACK}${NC} — ${RED}NOT FOUND${NC}"
    elif [[ "$STATUS" == *COMPLETE* && "$STATUS" != *DELETE* && "$STATUS" != *ROLLBACK* ]]; then
        echo -e "  🟢 ${BOLD}${STACK}${NC} — ${GREEN}${STATUS}${NC}"
    elif [[ "$STATUS" == *IN_PROGRESS* ]]; then
        echo -e "  🟡 ${BOLD}${STACK}${NC} — ${YELLOW}${STATUS}${NC}"
    else
        echo -e "  🔴 ${BOLD}${STACK}${NC} — ${RED}${STATUS}${NC}"
    fi
done

# --- EC2 Instances ---
echo ""
echo -e "${BOLD}🖥️  EC2 Instances${NC}"
echo "────────────────────────"

INSTANCES=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:aws:cloudformation:stack-name,Values=$(IFS=,; echo "${STACKS[*]}")" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Tags[?Key==`aws:cloudformation:stack-name`].Value|[0]]' \
    --output text 2>/dev/null)

if [ -z "$INSTANCES" ]; then
    echo -e "  ⚫ No instances found for tracked stacks"
else
    while IFS=$'\t' read -r ID STATE TYPE STACK; do
        case "$STATE" in
            running)  COLOR=$GREEN; ICON="🟢" ;;
            stopped)  COLOR=$YELLOW; ICON="🟡" ;;
            *)        COLOR=$RED; ICON="🔴" ;;
        esac
        echo -e "  ${ICON} ${BOLD}${ID}${NC} (${TYPE}) — ${COLOR}${STATE}${NC}  [${STACK}]"
    done <<< "$INSTANCES"
fi

# --- OpenClaw Gateway ---
echo ""
echo -e "${BOLD}🌐 OpenClaw Gateway${NC}"
echo "────────────────────────"

if systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
    PID=$(systemctl show openclaw-gateway -p MainPID --value 2>/dev/null)
    UPTIME=$(ps -p "$PID" -o etime= 2>/dev/null | tr -d ' ')
    echo -e "  🟢 Gateway — ${GREEN}running${NC}  (PID: ${PID}, uptime: ${UPTIME:-unknown})"
elif systemctl list-unit-files openclaw-gateway.service &>/dev/null 2>&1; then
    echo -e "  🔴 Gateway — ${RED}stopped${NC}"
else
    echo -e "  ⚫ Gateway — ${YELLOW}not installed on this host${NC}"
fi

# Port check
if ss -tlnp 2>/dev/null | grep -q ':18789'; then
    echo -e "  🟢 Port 18789 — ${GREEN}listening${NC}"
else
    echo -e "  🔴 Port 18789 — ${RED}not listening${NC}"
fi

echo ""
echo "════════════════════════════════════════"
echo -e "  ⏰ $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""
