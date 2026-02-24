# Golden Image Strategy

## Overview

Our golden image approach separates immutable base system configuration from site-specific settings. The base image contains all common software, drivers, and security hardening, while site-specific configuration (network settings, VPN credentials, site ID) is applied at deployment time via Ansible.

## Base Image

**Included in base image:**
- Ubuntu 22.04 LTS (minimal install)
- Docker CE with nvidia-container-toolkit
- NVIDIA T4 drivers (version 535)
- System hardening (SSH config, firewall rules, fail2ban)
- Monitoring agents (Prometheus node exporter, Grafana agent)
- Log rotation and NTP client (chrony)

**Excluded from base image (site-specific):**
- Network configuration (IP addresses, VLANs, gateway)
- Site ID and customer metadata
- Camera inventory and RTSP URLs
- AWS credentials (provided via IAM instance profile or secrets)

## Image Creation Process

1. **Provision base VM/bare metal** with Ubuntu 22.04 LTS
2. **Run setup.sh** to install all base components
3. **Security hardening:**
   - Disable unnecessary services
   - Configure auditd for compliance logging
   - Set up automatic security updates (unattended-upgrades)
4. **Pre-pull Docker images** from ECR to reduce first-boot time
5. **Clean up:**
   - Remove SSH host keys (regenerated on first boot)
   - Clear logs and temporary files
   - Zero out free space for compression
6. **Create image:**
   - For VMs: Export as OVA/VMDK
   - For bare metal: Create disk image with Clonezilla or dd
7. **Version and tag** image (for example `edge-golden-v1.2.3-20260223`)
8. **Store in S3** with versioning enabled

## Configuration Management

**Deployment-time configuration via cloud-init:**
```yaml
#cloud-config
write_files:
  - path: /etc/edge-config.env
    content: |
      SITE_ID=SITE-2847
      CUSTOMER=acme-distribution
      VPN_ENDPOINT=vpn-0a1b2c3d4e5f.amazonaws.com
runcmd:
  - /opt/edge/apply-site-config.sh
```

**Ongoing configuration management:**
- Ansible playbooks for post-deployment configuration
- AWS Systems Manager for remote command execution
- Configuration stored in AWS Secrets Manager/Parameter Store
- Periodic sync via cron job pulling from S3

## Patching and Updates

**OS patches:**
- Automatic security updates via unattended-upgrades (daily)
- Monthly maintenance window for kernel updates (requires reboot)
- Staged rollout: test on 1 site, then 10%, then 100%

**Application updates:**
- Docker images updated via CI/CD pipeline
- Watchtower or custom script pulls new images nightly
- Blue/green deployment: new container starts, health check passes, old container stops
- Rollback: revert to previous image tag if health checks fail

**Golden image updates:**
- Quarterly rebuild with latest OS patches and driver versions
- New sites get latest image; existing sites updated during maintenance windows
- Ansible playbook to upgrade in-place without full re-image

## Rollback

**Container rollback:**
```bash
docker stop video-ingest
docker run --rm --name video-ingest <previous-image-tag>
```

**Full system rollback:**
- Keep previous golden image version on local disk (/recovery partition)
- Boot from recovery partition, restore previous image
- Automated via systemd service that detects boot failures (systemd.unit=rescue.target)

**Validation before commit:**
- New image boots into "staging" mode
- Health checks run for 1 hour
- If all pass, commit new image; otherwise auto-rollback to previous version
