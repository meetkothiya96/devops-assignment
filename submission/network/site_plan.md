# Site Network Plan

Review `data/site_spec.json` for the customer site specification.

## VLAN Design

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 1 | management | 10.50.1.0/24 | IT management, SSH access, edge device management interface |
| 10 | corporate | 10.50.10.0/24 | Office workstations (existing) |
| 20 | cameras | 10.50.20.0/24 | Isolated camera network, DHCP for cameras |

## IP Addressing Scheme

**Static Assignments:**
- Edge device eno1 (management): 10.50.1.100/24
- Edge device eno2 (camera VLAN): 10.50.20.1/24 (gateway for cameras)
- DNS servers: 10.50.1.10, 10.50.1.11 (existing)
- NTP server: 10.50.1.10 (existing)

**DHCP Ranges:**
- Camera VLAN: 10.50.20.100 - 10.50.20.200 (101 addresses for up to 16 cameras + growth)

## Camera Network Isolation

**Isolation Strategy:**
- Camera VLAN (20) is Layer 2 isolated on dedicated switch/ports
- Edge device acts as gateway for camera VLAN but does NOT route between VLANs
- Firewall rules on edge device block FORWARD traffic from camera VLAN to management/corporate VLANs
- Cameras can only communicate with edge device (10.50.20.1) on RTSP ports
- No direct internet access for cameras
- Edge device bridges camera traffic to cloud via VPN only

**Security Controls:**
- Default DROP policy on FORWARD chain
- Explicit deny rules for camera-to-management and camera-to-corporate traffic
- Only RTSP (554/tcp, 554/udp) allowed from cameras to edge device
- No SSH or management protocols accessible from camera VLAN

## Edge Device Network Configuration

**Interface Configuration:**
- **eno1** (1 Gbps):
  - IP: 10.50.1.100/24
  - Gateway: 10.50.1.1 (site router)
  - Purpose: Management access (SSH), WAN uplink to VPN, cloud uploads
  - VLAN: 1 (management)
  
- **eno2** (1 Gbps):
  - IP: 10.50.20.1/24
  - No gateway (isolated network)
  - Purpose: Camera VLAN gateway, RTSP ingestion
  - VLAN: 20 (cameras)

**Routing:**
- Default route via eno1 (10.50.1.1) for cloud traffic
- No routing between eno2 and eno1 (enforced by firewall)
- VPN tunnel established via eno1 to AWS VPC

## Traffic Flow

1. **Camera → Edge (Video Ingestion):**
   - Cameras (10.50.20.100-200) stream RTSP to edge device (10.50.20.1:554)
   - Traffic stays on VLAN 20, never leaves edge device

2. **Edge → Cloud (Upload):**
   - Edge device processes video on eno2 interface
   - Uploads to S3 via eno1 → site router → IPSec VPN → AWS VPC
   - HTTPS (443) to S3 endpoints
   - Bandwidth limited to 50 Mbps

3. **Management → Edge (SSH):**
   - Admin workstations on management VLAN (10.50.1.0/24) SSH to 10.50.1.100
   - Firewall allows SSH only from management VLAN

4. **Edge → Monitoring:**
   - Prometheus metrics pushed to cloud via VPN (eno1)
   - Local Grafana accessible on management interface
