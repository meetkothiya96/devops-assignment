#!/usr/bin/env bash
#
# remediation.sh — Incident remediation script
#
# TASK: Write a script that remediates the issue identified in your root cause analysis.
#
# Requirements:
#   - Fix the immediate issue
#   - Verify the fix worked
#   - Be safe to run (idempotent, with checks before making changes)
#   - Include error handling

set -euo pipefail

INTERFACE="${INTERFACE:-eno1}"
TARGET_MTU=1500
LOG_FILE="/var/log/mtu-remediation.log"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

log "Starting MTU remediation for interface $INTERFACE"

# Check current MTU
CURRENT_MTU=$(ip link show "$INTERFACE" | grep -oP 'mtu \K\d+' || echo "0")

if [ "$CURRENT_MTU" -eq 0 ]; then
    log "ERROR: Interface $INTERFACE not found"
    exit 1
fi

log "Current MTU on $INTERFACE: $CURRENT_MTU"

if [ "$CURRENT_MTU" -eq "$TARGET_MTU" ]; then
    log "MTU already set to $TARGET_MTU, no action needed"
    exit 0
fi

# Set MTU
log "Setting MTU to $TARGET_MTU on $INTERFACE"
ip link set dev "$INTERFACE" mtu "$TARGET_MTU"

# Verify change
NEW_MTU=$(ip link show "$INTERFACE" | grep -oP 'mtu \K\d+')
if [ "$NEW_MTU" -ne "$TARGET_MTU" ]; then
    log "ERROR: Failed to set MTU, current value: $NEW_MTU"
    exit 1
fi

log "MTU successfully set to $TARGET_MTU"

# Restart VPN to clear any stale state
if systemctl is-active --quiet strongswan; then
    log "Restarting VPN service"
    systemctl restart strongswan
    sleep 5
fi

# Verify VPN tunnel is up
if ip link show tun0 &>/dev/null; then
    log "VPN tunnel is up"
else
    log "WARNING: VPN tunnel not detected, may need manual intervention"
fi

log "Remediation complete"
