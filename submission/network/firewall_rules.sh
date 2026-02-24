#!/usr/bin/env bash
#
# firewall_rules.sh — Edge device firewall configuration
#
# TASK: Implement iptables rules for the edge device.
# Reference data/site_spec.json for network details.
#
# Requirements:
#   - Default DROP policy on INPUT and FORWARD chains
#   - Allow RTSP (554/tcp, 554/udp) from camera VLAN only
#   - Allow HTTPS (443/tcp) outbound for S3 uploads and API calls
#   - Allow SSH (22/tcp) from management VLAN only
#   - Camera VLAN must not be able to reach management or corporate VLANs
#   - Allow established/related connections
#   - Allow loopback traffic
#   - Allow ICMP for diagnostics
#
# Hints:
#   - Camera VLAN: (define based on your site_plan.md)
#   - Management VLAN: 10.50.1.0/24
#   - Edge device interfaces: eno1 (mgmt/WAN), eno2 (camera VLAN)

set -euo pipefail

CAMERA_VLAN="10.50.20.0/24"
MGMT_VLAN="10.50.1.0/24"
CORPORATE_VLAN="10.50.10.0/24"
CAMERA_IF="eno2"
MGMT_IF="eno1"

# --- Flush existing rules ---
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# --- Default policies ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# --- Loopback ---
iptables -A INPUT -i lo -j ACCEPT

# --- Established/Related ---
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- SSH from management VLAN only ---
iptables -A INPUT -i "$MGMT_IF" -s "$MGMT_VLAN" -p tcp --dport 22 -j ACCEPT

# --- RTSP from camera VLAN only ---
iptables -A INPUT -i "$CAMERA_IF" -s "$CAMERA_VLAN" -p tcp --dport 554 -j ACCEPT
iptables -A INPUT -i "$CAMERA_IF" -s "$CAMERA_VLAN" -p udp --dport 554 -j ACCEPT

# --- HTTPS outbound ---
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# --- Camera VLAN isolation (block camera-to-management/corporate) ---
iptables -A FORWARD -i "$CAMERA_IF" -s "$CAMERA_VLAN" -d "$MGMT_VLAN" -j DROP
iptables -A FORWARD -i "$CAMERA_IF" -s "$CAMERA_VLAN" -d "$CORPORATE_VLAN" -j DROP
iptables -A FORWARD -i "$CAMERA_IF" -s "$CAMERA_VLAN" -j DROP

# --- ICMP ---
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# --- Logging for dropped packets (optional but recommended) ---
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables-INPUT-DROP: " --log-level 7
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "iptables-FORWARD-DROP: " --log-level 7

echo "Firewall rules applied successfully"
