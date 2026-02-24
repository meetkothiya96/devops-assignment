# Incident Response: Scenario 2

Review the data in `data/incident/scenario_2/` and answer the following.

## What is happening?

- The inference-api service has no endpoints despite 3 healthy pods running. 
- Requests from web-frontend to the service timeout. 
- The service shows Endpoints: None even though pods are in Running state.

## Root Cause

**Two issues causing service unavailability:**

1. **Label mismatch**: Service selector requires `app=inference-api` AND `tier=backend`, but pods only have `app=inference-api` label. The missing `tier: backend` label prevents the service from selecting any pods.

2. **NetworkPolicy blocking traffic**: The NetworkPolicy only allows ingress from pods with `app=api-gateway` label, but the web-frontend pods have `app=web-frontend` label, causing connection timeouts.


## Immediate Remediation

- Patch Service and networkpolicy directly from Kubernetes Shell, using following.

```bash

# Fix 1: Update service selector to match actual pod labels
kubectl patch svc inference-api -n video-analytics --type='json' -p='[
  {"op": "remove", "path": "/spec/selector/tier"}
]'

# Verify endpoints are now populated
kubectl get endpoints inference-api -n video-analytics

# Fix 2: Update NetworkPolicy to allow web-frontend traffic
kubectl patch networkpolicy inference-api-netpol -n video-analytics --type='json' -p='[
  {"op": "add", "path": "/spec/ingress/0/from/-", "value": {"podSelector": {"matchLabels": {"app": "web-frontend"}}}}
]'

# Test connectivity
kubectl exec -it web-frontend-6a5b4c3d2-jkl78 -n video-analytics -- curl http://inference-api:8080/health

```

## Long-term Fix

**Option 1 (Recommended)**: Fix the deployment to add the missing label:

          spec:
            template:
              metadata:
                labels:
                  app: inference-api
                  tier: backend


**Option 2**: Simplify service selector to only use `app: inference-api`

## Prevention

- **Pre-deployment validation**: Use `kubectl diff` or dry-run to catch selector mismatches
- **Integration tests**: Automated tests that verify service connectivity between components
- **Monitoring**: Alert on services with zero endpoints
