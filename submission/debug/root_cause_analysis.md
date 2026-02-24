# Root Cause Analysis

Review all files in `data/debug_scenario/` to investigate the incident.

## Summary

A network configuration change incorrectly applied jumbo frames (MTU 9000) to the WAN interface (eno1) instead of the camera VLAN interface (eno2). This caused packet fragmentation issues on the VPN tunnel, as the site gateway only supports MTU 1500. Large S3 uploads failed due to fragmentation, while small health check packets succeeded. The VPN tunnel flapped repeatedly due to DPD timeouts caused by packet loss from fragmentation. Reverting MTU to 1500 immediately resolved the issue.

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 08:00 | All systems normal, 100% upload success rate |
| 08:15 | Network change applied: eno1 MTU changed from 1500 to 9000 (intended for eno2) |
| 08:18 | ICMP "fragmentation needed" messages from gateway 10.50.1.1 |
| 08:18 | S3 upload timeouts begin, large chunks failing |
| 08:20 | Upload error count spikes to 18 per 5-min window |
| 08:21 | First VPN tunnel flap (DPD timeout), re-established after 10s |
| 08:22 | Network throughput drops to 1.8 Mbps (expected 50 Mbps) |
| 08:25 | Second VPN tunnel flap |
| 08:30 | Disk usage reaches 85%, 22 chunks in backlog, NOC alert triggered |
| 08:35 | Third VPN tunnel flap |
| 08:50 | Fourth VPN tunnel flap |
| 09:00 | MTU reverted to 1500, uploads resume immediately, tunnel stabilizes |

## Root Cause

**MTU mismatch causing packet fragmentation and VPN instability.**

The root cause was a configuration error where jumbo frames (MTU 9000) were applied to the WAN interface (eno1) instead of the camera VLAN interface (eno2). The site gateway (10.50.1.1) has a maximum MTU of 1500 and does not support jumbo frames.

When the edge device attempted to send large packets (up to 9000 bytes) through the VPN tunnel, the gateway responded with ICMP "fragmentation needed and DF set" messages. Since the Don't Fragment (DF) bit was set on ESP packets, they were dropped rather than fragmented, causing:
1. Large S3 uploads to timeout (847MB chunks split into large packets)
2. Small health check packets to succeed (under 1500 bytes)
3. VPN tunnel instability due to packet loss triggering DPD timeouts

## Contributing Factors

1. **Change control failure**: The change ticket (NET-4521) specified eno2 (camera VLAN) but was applied to eno1 (WAN interface)
2. **Lack of pre-change validation**: No test of VPN connectivity after MTU change
3. **Delayed detection**: Health checks passed because they used small packets; no monitoring of actual upload throughput
4. **No automated rollback**: System did not detect the misconfiguration and revert automatically

## Evidence

**Kernel logs showing MTU change:**
```
Nov 12 08:15:03 edge-denver-01 kernel: device eno1: MTU changed from 1500 to 9000 via netplan apply
```

**ICMP fragmentation errors:**
```
Nov 12 08:18:33 edge-denver-01 kernel: ICMP: 10.50.1.1: fragmentation needed and DF set, mtu=1500
```

**VPN logs showing fragmentation issues:**
```
2025-11-12 08:15:05 WARNING: IKE SA keepalive: packet size 9000 exceeds path MTU 1500
2025-11-12 08:18:30 WARNING: ESP packets being fragmented at gateway, excessive reassembly failures
2025-11-12 08:21:15 WARNING: DF bit set on ESP packets, ICMP "fragmentation needed" returned by 10.50.1.1
```

**Application logs showing selective failure:**
```
2025-11-12T08:22:16Z WARN [uploader] VideoUploader - Network throughput: 1.8 Mbps (expected 50 Mbps)
2025-11-12T08:22:16Z WARN [uploader] VideoUploader - Possible MTU/fragmentation issue: large packets timing out, small health checks succeed
```

**VPN tunnel flapping:**
```
2025-11-12 08:20:58 ERROR: DPD timeout — peer 52.14.88.201 not responding
2025-11-12 08:21:00 NOTICE: Tunnel DOWN — initiating rekey
```
