# Incident Response: Scenario 1

Review the data in `data/incident/scenario_1/` and answer the following.

## What is happening?

The video-processor pod is in CrashLoopBackOff state with restarts. The container is being killed repeatedly due to out-of-memory (OOM) conditions.

## Root Cause

Memory limit too low for workload requirements. The pod has a 512Mi memory limit, but the Java application is configured with:
- JVM heap: 384MB
- 8 processing threads
- Batch size of 50 fragments per thread

Evidence:
- Logs show heap usage climbing to 85% (326MB/384MB) before OOM
- Container memory limit (512Mi) doesn't account for off-heap memory 
- With 8 threads processing 50-fragment batches simultaneously, memory pressure exceeds the limit

## Immediate Remediation

```bash
# Scale down to reduce load temporarily
kubectl scale deployment video-processor -n video-analytics --replicas=1

# Patch the deployment to increase memory limit
kubectl patch deployment video-processor -n video-analytics --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "2Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "1Gi"}
]'

# Update JVM heap settings
kubectl set env deployment/video-processor -n video-analytics JAVA_OPTS="-Xmx1536m -Xms512m"

# Scale back up
kubectl scale deployment video-processor -n video-analytics --replicas=3
```

## Long-term Fix

Update deployment manifest:
- Memory request: 1Gi, limit: 2Gi
- JVM heap: -Xmx1536m (75% of limit for off-heap overhead)
- Reduce PROCESSING_THREADS to 4 or BATCH_SIZE to 25 to lower memory footprint
- Add memory-based HPA metric to scale before OOM occurs

## Prevention

- **Alerting**: CloudWatch/Prometheus alert when container memory usage > 80%
- **Load testing**: Test with realistic workload before deploying to production
- **Vertical Pod Autoscaler**: Consider VPA for automatic right-sizing recommendations
