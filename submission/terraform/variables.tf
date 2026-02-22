variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "site_id" {
  description = "Customer site identifier"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "video-analytics"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "management_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
}
# TODO: Add variables for:
# - Node group instance types and sizing
# - S3 bucket names
# - Any other configurable parameters your infrastructure needs


# Node group instance types and sizing
variable "general_node_group" {
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
  })
}

variable "gpu_node_group" {
  type = object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
  })
}

variable "video_chunks_bucket_name" {
  description = "Existing S3 bucket for raw video chunks"
  type        = string
}

variable "enable_general_spot" {
  description = "Enable Spot instances for general workloads"
  type        = bool
  default     = true
}

variable "general_spot_node_group" {
  description = "Configuration for general Spot node group"
  type = object({
    min_size     = number
    desired_size = number
    max_size     = number
  })
  default = {
    min_size     = 0
    desired_size = 1
    max_size     = 6
  }
}