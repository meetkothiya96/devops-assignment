#!/usr/bin/env bash
#
# healthcheck.sh — Edge device health check script
#
# TASK: Implement a health check script that verifies edge device status.
#
# Requirements:
#   - Check Docker daemon is running
#   - Check video-ingest container is running and healthy
#   - Check GPU is accessible (nvidia-smi)
#   - Check disk usage is below threshold
#   - Check NTP synchronization
#   - Check VPN tunnel is up
#   - Check camera connectivity (ping camera subnet)
#   - Output JSON status report
#   - Exit code 0 if healthy, 1 if degraded, 2 if critical

set -euo pipefail

STATUS="healthy"
CHECKS=()

check_docker() {
    if systemctl is-active --quiet docker; then
        CHECKS+=('{"name":"docker","status":"ok"}')
    else
        CHECKS+=('{"name":"docker","status":"critical","message":"Docker daemon not running"}')
        STATUS="critical"
    fi
}

check_container() {
    if docker ps --filter "name=video-ingest" --filter "status=running" | grep -q video-ingest; then
        CHECKS+=('{"name":"video-ingest","status":"ok"}')
    else
        CHECKS+=('{"name":"video-ingest","status":"critical","message":"Container not running"}')
        STATUS="critical"
    fi
}

check_gpu() {
    if nvidia-smi &>/dev/null; then
        CHECKS+=('{"name":"gpu","status":"ok"}')
    else
        CHECKS+=('{"name":"gpu","status":"critical","message":"GPU not accessible"}')
        STATUS="critical"
    fi
}

check_disk() {
    USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$USAGE" -lt 80 ]; then
        CHECKS+=('{"name":"disk","status":"ok","usage_pct":'$USAGE'}')
    elif [ "$USAGE" -lt 90 ]; then
        CHECKS+=('{"name":"disk","status":"degraded","usage_pct":'$USAGE'}')
        [ "$STATUS" = "healthy" ] && STATUS="degraded"
    else
        CHECKS+=('{"name":"disk","status":"critical","usage_pct":'$USAGE'}')
        STATUS="critical"
    fi
}


check_cameras() {
    if ping -c 1 -W 1 10.50.20.1 &>/dev/null; then
        CHECKS+=('{"name":"camera_network","status":"ok"}')
    else
        CHECKS+=('{"name":"camera_network","status":"degraded","message":"Camera subnet unreachable"}')
        [ "$STATUS" = "healthy" ] && STATUS="degraded"
    fi
}

check_docker
check_container
check_gpu
check_disk
check_cameras

CHECKS_JSON=$(IFS=,; echo "${CHECKS[*]}")
echo "{\"status\":\"$STATUS\",\"checks\":[$CHECKS_JSON]}"

case "$STATUS" in
    healthy) exit 0 ;;
    degraded) exit 1 ;;
    critical) exit 2 ;;
esac
