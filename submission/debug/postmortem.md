# Post-Incident Report

## Incident Summary

| Field | Value |
|-------|-------|
| Date | 2025-11-12 |
| Duration | 45 minutes (08:15 - 09:00 UTC) |
| Severity | High |
| Services Affected | Video upload service at SITE-2847 (Denver Distribution Center) |
| Customer Impact | 45 minutes of video upload failures, 22 chunks backlogged, no data loss |

## What Happened

A scheduled network maintenance change incorrectly applied jumbo frames (MTU 9000) to the WAN interface (eno1) instead of the camera VLAN interface (eno2). This caused packet fragmentation issues on the IPSec VPN tunnel, as the site gateway only supports MTU 1500. Large S3 uploads failed due to dropped fragmented packets, while small health check packets continued to succeed, masking the issue. The VPN tunnel flapped repeatedly (4 times) due to packet loss triggering DPD timeouts. Upload throughput dropped from 50 Mbps to 1.8 Mbps, causing disk usage to climb to 85% with 22 chunks backlogged.

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 08:00 | All systems normal, 100% upload success rate |
| 08:15 | Network change applied: eno1 MTU changed from 1500 to 9000 (change ticket NET-4521) |
| 08:18 | ICMP "fragmentation needed" errors begin, S3 upload timeouts start |
| 08:20 | Upload error count spikes to 18 per 5-min window |
| 08:21 | First VPN tunnel flap (DPD timeout), re-established after 10s |
| 08:22 | Application detects throughput degradation (1.8 Mbps vs 50 Mbps expected) |
| 08:25 | Second VPN tunnel flap |
| 08:30 | Disk usage 85%, 22 chunks backlogged, NOC alert triggered |
| 08:35 | Third VPN tunnel flap |
| 08:45 | NOC engineer begins investigation |
| 08:50 | Fourth VPN tunnel flap |
| 09:00 | MTU reverted to 1500, uploads resume immediately, tunnel stabilizes |

## Root Cause

**Configuration error: MTU mismatch causing packet fragmentation and VPN instability.**

Change ticket NET-4521 intended to enable jumbo frames on eno2 (camera VLAN) to improve camera-to-edge throughput. However, the netplan configuration was incorrectly applied to eno1 (WAN interface) instead. The site gateway (10.50.1.1) has a maximum MTU of 1500 and does not support jumbo frames.

When the edge device sent packets larger than 1500 bytes through the VPN tunnel, the gateway responded with ICMP "fragmentation needed" messages. Since the Don't Fragment (DF) bit was set on ESP packets, they were dropped rather than fragmented. This caused:
- Large S3 uploads (847MB chunks) to timeout
- Small health check packets (<1500 bytes) to succeed
- VPN tunnel instability due to packet loss triggering DPD timeouts

## Resolution

At 09:00 UTC, the NOC engineer identified the MTU misconfiguration and reverted eno1 to MTU 1500. Uploads resumed immediately, and the VPN tunnel stabilized. All backlogged chunks were successfully uploaded within 15 minutes.

## Impact

- **Duration**: 45 minutes of degraded service
- **Data loss**: None (all chunks eventually uploaded)
- **Customer impact**: 45-minute delay in video availability for analysis
- **Disk usage**: Peaked at 85% (15% below critical threshold)
- **VPN stability**: 4 tunnel flaps, each causing 10s of additional latency

## Action Items

| Action | Owner | Priority | Due Date |
|--------|-------|----------|----------|
| Implement pre-change validation script that tests VPN connectivity after network changes | Network Team | P0 | 2025-11-19 |
| Add MTU monitoring alert (warn if MTU != 1500 on eno1) | SRE Team | P0 | 2025-11-19 |
| Add upload throughput monitoring (alert if <10 Mbps for >5 min) | SRE Team | P0 | 2025-11-19 |
| Update change control process to require peer review for network changes | Change Management | P1 | 2025-11-26 |
| Implement automated rollback for network changes that cause VPN instability | Edge Team | P1 | 2025-12-03 |
| Add integration test that validates large file uploads after network changes | QA Team | P2 | 2025-12-10 |
| Document MTU requirements in edge device runbook | Documentation | P2 | 2025-11-26 |

## Lessons Learned

### What went well

- Application logs correctly identified the issue ("Possible MTU/fragmentation issue")
- Monitoring detected the problem within 15 minutes (NOC alert at 08:30)
- No data loss occurred due to local buffering
- Remediation was quick once root cause was identified (immediate recovery)

### What could be improved

- **Change validation**: No pre-change testing of VPN connectivity after MTU change
- **Change control**: Configuration was applied to wrong interface (eno1 vs eno2)
- **Monitoring gaps**: Health checks passed while uploads failed (small vs large packets)
- **Detection time**: 15 minutes elapsed before NOC alert (should be <5 min)
- **Automated remediation**: System did not detect and auto-revert the misconfiguration
