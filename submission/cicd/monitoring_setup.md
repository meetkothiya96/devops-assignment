# Monitoring and Observability Setup

## Metrics

**Application-level metrics:**
- `video_upload_success_rate` (gauge, %) - Percentage of successful S3 uploads
- `video_upload_latency_seconds` (histogram) - Time to upload video chunks
- `video_processing_duration_seconds` (histogram) - Time to process video fragments
- `http_request_duration_seconds` (histogram) - API request latency
- `http_requests_total` (counter) - Total HTTP requests by status code
- 

**Infrastructure metrics:**
- `node_cpu_utilization` (gauge, %) - CPU usage per node
- `node_memory_utilization` (gauge, %) - Memory usage per node
- `node_disk_utilization` (gauge, %) - Disk usage per node
- `pod_restart_count` (counter) - Pod restart count
- `container_oom_kills_total` (counter) - OOM kill events

**Business metrics:**
- `video_chunks_processed_total` (counter) - Total chunks processed
- `cameras_online` (gauge) - Number of cameras streaming per site
- `sites_online` (gauge) - Number of sites with active edge devices

**Edge device metrics:**
- `edge_disk_usage_percent` (gauge, %) - Local disk usage
- `edge_gpu_utilization` (gauge, %) - GPU usage
- `edge_camera_stream_errors_total` (counter) - Camera connection errors

## SLOs (Service Level Objectives)

**Availability:**
- Cloud services (API, processing): 99.9% uptime (43 min downtime/month)
- Edge devices: 99.5% uptime (3.6 hours downtime/month)
- VPN tunnels: 99.9% uptime

**Latency:**
- API p50: <100ms, p99: <500ms
- Video upload p50: <30s per chunk, p99: <120s
- Inference API p50: <200ms, p99: <1s

**Data freshness:**
- Video available in cloud within 5 minutes of capture (p99)
- Inference results available within 10 minutes of video capture (p99)

**Throughput:**
- Upload success rate: >99.5%
- Processing success rate: >99.9%

**Edge device uptime:**
- Edge device operational: >99.5%
- Camera connectivity: >99% per site

## Alerting

**Critical (Page immediately):**
- Upload success rate <90% for >10 minutes
- API error rate >5% for >5 minutes
- Edge device offline for >15 minutes
- VPN tunnel down for >5 minutes
- Disk usage >90% on edge device

**High (Page during business hours, ticket after hours):**
- Upload success rate <95% for >15 minutes
- Pod restart count >5 in 10 minutes
- GPU utilization >90% for >30 minutes
- Camera offline for >30 minutes

**Medium (Ticket only):**
- Upload success rate <98% for >30 minutes
- Disk usage >80% on edge device
- Memory utilization >80% for >30 minutes
- Certificate expiring in <30 days

**Alert fatigue prevention:**
- Group related alerts (e.g., all cameras at one site)
- Suppress duplicate alerts within 1 hour
- Auto-resolve alerts when condition clears
- Weekly alert review to tune thresholds

## Escalation

**L1: Automated Response (0-5 minutes)**
- Automated remediation scripts (e.g., restart pod, clear disk space)
- Self-healing: auto-rollback on failed deployment
- Runbook automation via AWS Systems Manager

**L2: On-Call Engineer (5-30 minutes)**
- Primary on-call receives page
- Access to runbooks and dashboards
- Authority to rollback deployments
- Escalate to L3 if not resolved in 30 minutes

**L3: Senior Engineer / Specialist (30+ minutes)**
- Subject matter expert (networking, GPU, Kafka)
- Deep troubleshooting and root cause analysis
- Authority to make architectural changes
- Escalate to engineering leadership if customer impacting

**Customer Communication:**
- Notify customer if site offline >1 hour
- Provide status updates every 2 hours during major incidents
- Post-incident report within 48 hours

## Dashboards

**1. Executive Dashboard**
- Total sites online/offline
- Overall upload success rate (last 24h)
- Total video processed (TB/day)

**2. Cloud Operations Dashboard**
- EKS cluster health (node count, pod status)
- API request rate and latency (p50, p95, p99)
- S3 upload throughput and error rate
- RDS connection count and query latency

**4. Application Performance Dashboard**
- Inference API latency and throughput
- Error rate by service
- Pod resource utilization (CPU, memory)
- Container restart events

**5. Cost Dashboard**
- Daily AWS spend by service
- S3 storage growth trend
- EC2 instance utilization (spot vs on-demand)
