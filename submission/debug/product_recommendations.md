# Product & Engineering Recommendations

Based on your investigation of the debug scenario, provide recommendations for improving the platform.

## Monitoring Improvements

**1. MTU Monitoring**
- Alert if MTU on WAN interfaces (eno1) deviates from expected value (1500)
- Dashboard showing MTU values across all edge devices
- Automated daily validation of network configuration

**2. Upload Throughput Metrics**
- Track actual upload throughput (Mbps) vs expected baseline
- Alert if throughput drops below 10 Mbps for >5 minutes
- Separate metrics for small packets (health checks) vs large packets (uploads)

**3. VPN Tunnel Health**
- Monitor VPN tunnel flap rate (alert on >1 flap per hour)
- Track packet loss percentage on VPN tunnel
- Alert on ICMP fragmentation errors from gateway

**4. Packet Size Distribution**
- Monitor distribution of packet sizes being sent
- Alert on anomalous packet size patterns (e.g., sudden increase in >1500 byte packets)

**5. Upload Queue Depth**
- Track number of chunks in upload queue
- Alert at 10 chunks (warning) and 20 chunks (critical)
- Predict disk exhaustion time based on queue growth rate

## Automated Detection

**1. Pre-Change Validation**
```bash
# Run after any network configuration change
validate_network_change() {
  # Test VPN connectivity
  ping -c 5 <vpn-gateway> || rollback
  
  # Test large file upload
  dd if=/dev/zero bs=1M count=100 | aws s3 cp - s3://test-bucket/test || rollback
  
  # Verify MTU on WAN interface
  [[ $(cat /sys/class/net/eno1/mtu) -eq 1500 ]] || rollback
}
```

**2. Self-Healing MTU Check**
- Cron job every 5 minutes validates MTU on eno1
- If MTU != 1500, automatically revert and alert
- Log all MTU changes with timestamp and source

**3. Upload Failure Detection**
- If upload success rate <50% for 3 consecutive attempts, trigger investigation
- Automatically run diagnostic script (MTU check, VPN status, packet loss test)
- If MTU issue detected, auto-remediate and alert

**4. VPN Tunnel Stability Monitor**
- If tunnel flaps >2 times in 10 minutes, trigger automated diagnostics
- Check for fragmentation errors in kernel logs
- Test path MTU discovery
- Alert NOC with diagnostic results

## Platform Changes

**1. Configuration Management**
- Store network configuration in version control (Git)
- Use declarative configuration (Ansible/Terraform) instead of imperative scripts
- Implement configuration drift detection (compare running config vs desired state)
- Automated rollback on validation failure

**2. Change Control**
- Require peer review for all network configuration changes
- Automated pre-change validation in staging environment
- Canary deployment: apply change to 1 edge device, validate for 1 hour, then roll out
- Mandatory rollback plan documented in change ticket

**3. Health Check Improvements**
- Add "deep" health check that uploads a 10MB test file to S3
- Run deep health check every 5 minutes (vs shallow health check every 30s)
- Fail health check if deep check fails, even if shallow check passes

**4. Observability**
- Distributed tracing for upload requests (track latency at each hop)
- Correlate VPN tunnel events with upload failures
- Real-time dashboard showing upload success rate per site

## Edge Device Improvements

**1. Configuration Validation**
- Pre-deployment validation: test configuration in VM before applying to production
- Post-deployment validation: automated test suite runs after any config change
- Configuration schema validation (reject invalid MTU values, wrong interface names)

**2. Immutable Infrastructure**
- Use golden images with baked-in configuration
- Site-specific config applied via cloud-init (validated before boot)
- Reduce manual configuration changes (use automation)

**3. Automated Rollback**
- Store last-known-good configuration on disk
- If health checks fail after config change, auto-rollback within 5 minutes
- Implement A/B configuration slots (boot from slot A, test, commit or rollback to slot B)

**4. Change Auditing**
- Log all configuration changes with timestamp, user, and source (manual vs automated)
- Send change notifications to centralized logging (CloudWatch/Splunk)
- Alert on unexpected configuration changes (e.g., MTU change not from approved automation)

**5. Network Testing Tools**
- Pre-installed diagnostic tools: mtr, iperf3, tcpdump
- Automated diagnostic script triggered on upload failures
- Remote execution capability via AWS Systems Manager for troubleshooting
