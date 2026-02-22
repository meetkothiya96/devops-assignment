# cost_optimization.tf — Cost Optimization Resources
#
# TASK: Review data/aws_cost_report.json and implement cost-saving measures.
#
# Requirements:
#   1. Analyze the cost report and identify the top savings opportunities
#   2. Implement Terraform resources that address the findings, such as:
#      - S3 lifecycle policies for tiered storage
#      - Spot/mixed instance configurations for node groups
#      - Right-sizing recommendations implemented as resource changes
#   3. Add a comment block at the top explaining your cost analysis:
#      - Current monthly cost and top cost drivers
#      - Proposed changes and estimated savings
#      - Any trade-offs or risks

# --- Your cost analysis ---
# TODO: Write your analysis here as comments

# --- S3 Lifecycle Policies ---
# TODO: Implement lifecycle rules for the video chunks bucket
#   Hint: 95% of access is within the first 30 days

data "aws_s3_bucket" "video_chunks" {
  bucket = var.video_chunks_bucket_name
}

resource "aws_s3_bucket_lifecycle_configuration" "video_chunks" {
  bucket = data.aws_s3_bucket.video_chunks.id

  rule {
    id     = "tiered-storage"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# --- Spot/Mixed Instance Configuration ---
# TODO: Configure mixed instance policies for appropriate node groups
#   Hint: Not all workloads are suitable for spot instances

# --- Spot Node Group for Cost Optimization ---
# This node group supplements on-demand capacity.
# Only stateless workloads should run here.

resource "aws_eks_node_group" "general_spot" {
  count = var.enable_general_spot ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-general-spot"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  capacity_type  = "SPOT"
  instance_types = var.general_node_group.instance_types

  scaling_config {
    min_size     = var.general_spot_node_group.min_size
    desired_size = var.general_spot_node_group.desired_size
    max_size     = var.general_spot_node_group.max_size
  }

  labels = {
    workload  = "general"
    lifecycle = "spot"
  }

  # Soft isolation so critical pods avoid Spot
  taint {
    key    = "spot"
    value  = "true"
    effect = "PREFER_NO_SCHEDULE"
  }

  tags = {
    CostOptimized = "true"
  }
}

# --- Other Cost Optimizations ---
# TODO: Implement any other cost-saving measures you identified
