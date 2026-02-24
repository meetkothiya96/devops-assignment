#!/usr/bin/env bash
#
# setup.sh — Edge device provisioning script
#
# TASK: Implement a provisioning script for a new edge device.
# Reference data/site_spec.json for hardware and requirements.
#
# Requirements:
#   - Error handling (set -euo pipefail, trap for cleanup)
#   - Docker installation and configuration
#   - NTP configuration for time synchronization
#   - Log rotation setup
#   - Systemd service for the video ingest container
#   - GPU driver setup (NVIDIA)
#   - Basic security hardening

set -euo pipefail

SITE_ID="${SITE_ID:-SITE-UNKNOWN}"
LOG_FILE="/var/log/edge-setup-${SITE_ID}.log"
NTP_SERVER="${NTP_SERVER:-10.50.1.10}"

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$LOG_FILE"
}

trap 'log "ERROR: Setup failed at line $LINENO"' ERR

log "Starting edge device setup for site: $SITE_ID"

# ============================================
# SECTION 1: System Updates and Base Packages
# ============================================
log "Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y curl gnupg lsb-release ca-certificates apt-transport-https

# ============================================
# SECTION 2: Docker Installation
# ============================================
log "Installing Docker CE..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ============================================
# SECTION 3: NVIDIA GPU Drivers and Container Toolkit
# ============================================
log "Installing NVIDIA drivers and container toolkit..."
apt-get install -y nvidia-driver-535
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' > /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# ============================================
# SECTION 4: NTP Configuration
# ============================================
log "Configuring NTP..."
apt-get install -y chrony
cat > /etc/chrony/chrony.conf <<EOF
server $NTP_SERVER iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF
systemctl enable chrony
systemctl restart chrony

# ============================================
# SECTION 5: Log Rotation
# ============================================
log "Configuring log rotation..."
cat > /etc/logrotate.d/video-ingest <<EOF
/var/log/video-ingest/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF

# ============================================
# SECTION 6: Systemd Service
# ============================================
log "Creating systemd service..."
cat > /etc/systemd/system/video-ingest.service <<EOF
[Unit]
Description=Video Ingest Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
Environment="SITE_ID=$SITE_ID"
ExecStartPre=-/usr/bin/docker stop video-ingest
ExecStartPre=-/usr/bin/docker rm video-ingest
ExecStart=/usr/bin/docker run --rm --name video-ingest \\
  --gpus all \\
  -v /data/video-buffer:/data \\
  -e SITE_ID=\${SITE_ID} \\
  --network host \\
  123456789012.dkr.ecr.us-east-1.amazonaws.com/video-ingest:latest
ExecStop=/usr/bin/docker stop video-ingest

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /data/video-buffer
systemctl daemon-reload
systemctl enable video-ingest

# ============================================
# SECTION 7: Security Hardening
# ============================================
log "Applying security hardening..."
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.50.1.0/24 to any port 22
ufw --force enable

log "Edge device setup complete for site: $SITE_ID"
