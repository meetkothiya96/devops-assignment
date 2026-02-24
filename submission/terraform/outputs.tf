output "vpc_id" {
  description = "ID of the VPC"
  value       = "" # TODO: Reference the VPC resource
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = "" # TODO: Reference the EKS cluster resource
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

# TODO: Add outputs for:
# - Private subnet IDs
# - Public subnet IDs
# - NAT Gateway IPs
# - S3 bucket names
# - Any other values downstream consumers need


output "private_subnet_ids" {
  description = "List of private subnet IDs for EKS nodes and internal services"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

# --- Public Subnet IDs ---
output "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and NAT Gateway"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

# --- NAT Gateway Public IPs ---
output "nat_gateway_public_ips" {
  description = "Elastic IPs associated with NAT Gateways"
  value       = [aws_eip.nat.public_ip]
}