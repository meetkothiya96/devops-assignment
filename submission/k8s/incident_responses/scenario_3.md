# Incident Response: Scenario 3

Review the data in `data/incident/scenario_3/` and answer the following.

## What is happening?

Deployment rollout is stuck with 1 new pod in ImagePullBackOff and 3 old pods still running. 

The new pod cannot pull the image from ECR, showing "authorization token has expired" error. 

The rolling update is blocked and cannot proceed.

## Root Cause

**Missing IAM role annotation on ServiceAccount.** 

The ServiceAccount chunk-processor lacks the required annotation `eks.amazonaws.com/role-arn` to assume an IAM role with ECR pull permissions. Without this, the pod cannot authenticate to ECR to pull the image.

## Immediate Remediation

```bash
# Rollback to previous working version
kubectl rollout undo deployment/chunk-processor -n video-analytics

# Add IAM role annotation to ServiceAccount
kubectl annotate sa chunk-processor -n video-analytics \
  eks.amazonaws.com/role-arn=arn:aws:iam::123456789012:role/chunk-processor-ecr-role

# Verify the IAM role exists and has ECR permissions
aws iam get-role --role-name chunk-processor-ecr-role

# Ensure trust policy allows the ServiceAccount
aws iam get-role --role-name chunk-processor-ecr-role --query 'Role.AssumeRolePolicyDocument'

# Retry the deployment
kubectl rollout restart deployment/chunk-processor -n video-analytics
kubectl rollout status deployment/chunk-processor -n video-analytics
```

## Long-term Fix

1. Update ServiceAccount manifest to include IAM role annotation:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: chunk-processor
  namespace: video-analytics
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/chunk-processor-ecr-role
```

2. Ensure IAM role has proper trust policy for IRSA:
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub": "system:serviceaccount:video-analytics:chunk-processor"
    }
  }
}
```

3. Attach ECR read policy to the IAM role

## Prevention

- **Pre-deployment checks**: Validate ServiceAccount annotations and IAM role existence before deploying
- **Monitoring**: Alert on ImagePullBackOff events lasting > 2 minutes
- **Progressive delivery**: Use canary deployments to catch image pull issues on 1 pod before full rollout
- **Documentation**: Maintain checklist for new service deployments requiring ECR access
- **Automated testing**: Test image pull in staging environment before production deployment
