# main.tf — EKS Cluster and Node Groups
#
# TASK: Complete this file to create a production-grade EKS cluster.
# Requirements:
#   - EKS cluster with proper IAM roles
#   - At least two node groups: one for general workloads, one for GPU inference
#   - Proper subnet placement (private subnets for nodes)
#   - Reference security groups from networking.tf

# --- EKS Cluster IAM Role ---
# TODO: Create an IAM role for the EKS cluster with the AmazonEKSClusterPolicy

# --- EKS Cluster ---
# TODO: Create the EKS cluster resource
#   - Place in private subnets
#   - Enable cluster logging (api, audit, authenticator)
#   - Reference the cluster IAM role

# --- EKS Cluster ---
# --- EKS Cluster IAM Role ---
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.eks_nodes.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = false
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = var.cluster_name
  }
}

# --- Node Group IAM Role ---
# TODO: Create an IAM role for EKS node groups with:
#   - AmazonEKSWorkerNodePolicy
#   - AmazonEKS_CNI_Policy
#   - AmazonEC2ContainerRegistryReadOnly

# --- Node Group IAM Role ---

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- General Node Group ---
# TODO: Create a managed node group for general workloads
#   - Instance type(s) appropriate for general workloads
#   - Scaling configuration (min, max, desired)
#   - Place in private subnets

# --- General Node Group ---

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-general"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  instance_types = var.general_node_group.instance_types

  scaling_config {
    desired_size = var.general_node_group.desired_size
    min_size     = var.general_node_group.min_size
    max_size     = var.general_node_group.max_size
  }

  capacity_type = "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly
  ]

  tags = {
    Name = "${var.cluster_name}-general"
  }
}

# --- GPU Node Group ---
# TODO: Create a managed node group for GPU inference
#   - GPU instance type (e.g., g4dn.xlarge)
#   - Appropriate scaling
#   - Taints for GPU workload isolation
#   - Place in private subnets

# --- GPU Node Group ---

resource "aws_eks_node_group" "gpu" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-gpu"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  instance_types = var.gpu_node_group.instance_types

  scaling_config {
    desired_size = var.gpu_node_group.desired_size
    min_size     = var.gpu_node_group.min_size
    max_size     = var.gpu_node_group.max_size
  }

  capacity_type = "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  # GPU workload isolation
  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "gpu"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly
  ]

  tags = {
    Name = "${var.cluster_name}-gpu"
  }
}